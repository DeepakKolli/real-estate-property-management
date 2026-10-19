public with sharing class TenantLeaseController {
    @AuraEnabled(cacheable=true)
    public static List<Tenant__c> getTenants() {
        return [
            SELECT Id, Name, Phone__c, Email__c
            FROM Tenant__c
            ORDER BY Name
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Property__c> getAvailableProperties() {
        return [
            SELECT Id, Name, Address__c, City__c, Rent__c, Status__c
            FROM Property__c
            WHERE Status__c = 'Available'
            ORDER BY Name
            LIMIT 500
        ];
    }

    @AuraEnabled
    public static Id createTenant(String tenantName, String phone, String email) {
        if (String.isBlank(tenantName) || String.isBlank(phone) || String.isBlank(email)) {
            throw new AuraHandledException('Name, phone and email are required.');
        }

        Tenant__c tenant = new Tenant__c(
            Name = tenantName.trim(),
            Phone__c = phone.trim(),
            Email__c = email.trim()
        );
        insert tenant;
        return tenant.Id;
    }

    @AuraEnabled
    public static Id createLease(
        Id tenantId,
        Id propertyId,
        String terms,
        Decimal agreedRent,
        Date startDate,
        Date endDate
    ) {
        if (tenantId == null || propertyId == null ||
            String.isBlank(terms) || agreedRent == null ||
            startDate == null || endDate == null) {
            throw new AuraHandledException('Complete every lease field.');
        }

        if (agreedRent <= 0 || endDate <= startDate) {
            throw new AuraHandledException('Rent must be positive and the end date must follow the start date.');
        }

        Property__c propertyRecord = [
            SELECT Id, Status__c
            FROM Property__c
            WHERE Id = :propertyId
            LIMIT 1
            FOR UPDATE
        ];

        if (propertyRecord.Status__c != 'Available') {
            throw new AuraHandledException('This property is no longer available.');
        }

        List<Lease_Agreement__c> existingLeases = [
            SELECT Id
            FROM Lease_Agreement__c
            WHERE Property__c = :propertyId
            LIMIT 1
        ];

        if (!existingLeases.isEmpty()) {
            throw new AuraHandledException('A lease already exists for this property.');
        }

        Lease_Agreement__c lease = new Lease_Agreement__c(
            Tenant__c = tenantId,
            Property__c = propertyId,
            Agreed_Monthly_Rent__c = agreedRent,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
        insert lease;

        propertyRecord.Status__c = 'Occupied';
        update propertyRecord;

        insert new Task(
            Subject = 'Lease onboarding - ' + String.valueOf(lease.Id),
            WhatId = lease.Id,
            ActivityDate = startDate,
            Status = 'Not Started',
            Priority = 'Normal',
            Description = 'Lease terms: ' + terms + '\nFollow up on lease onboarding and lease document generation.'
        );

        return lease.Id;
    }
}
