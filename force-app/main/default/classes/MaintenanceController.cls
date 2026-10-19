public with sharing class MaintenanceController {
    @AuraEnabled(cacheable=true)
    public static List<Property__c> getProperties() {
        return [
            SELECT Id, Name, Address__c, City__c, Status__c
            FROM Property__c
            ORDER BY Name
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Maintenance_Request__c> getRequests() {
        return [
            SELECT Id, Name, Status__c,
                   Property__r.Name, Vendor__r.Name, CreatedDate
            FROM Maintenance_Request__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Id createRequest(Id propertyId, String description) {
        if (propertyId == null || String.isBlank(description)) {
            throw new AuraHandledException('Select a property and enter a description.');
        }

        List<Vendor__c> vendors = [
            SELECT Id, Name
            FROM Vendor__c
            ORDER BY Name
            LIMIT 500
        ];

        if (vendors.isEmpty()) {
            throw new AuraHandledException('Create at least one vendor before submitting a maintenance request.');
        }

        Map<Id, Integer> workload = new Map<Id, Integer>();
        for (Vendor__c vendor : vendors) {
            workload.put(vendor.Id, 0);
        }

        for (AggregateResult result : [
            SELECT Vendor__c vendorId, COUNT(Id) total
            FROM Maintenance_Request__c
            WHERE Vendor__c != null
              AND Status__c IN ('Open', 'In Progress')
            GROUP BY Vendor__c
        ]) {
            Id vendorId = (Id) result.get('vendorId');
            if (workload.containsKey(vendorId)) {
                workload.put(vendorId, (Integer) result.get('total'));
            }
        }

        Id selectedVendorId;
        Integer lowestWorkload;

        for (Vendor__c vendor : vendors) {
            Integer currentWorkload = workload.get(vendor.Id);
            if (selectedVendorId == null || currentWorkload < lowestWorkload) {
                selectedVendorId = vendor.Id;
                lowestWorkload = currentWorkload;
            }
        }

        Maintenance_Request__c requestRecord = new Maintenance_Request__c(
            Property__c = propertyId,
            Vendor__c = selectedVendorId,
            Status__c = 'Open',
            Request_Description__c = description.trim()
        );

        insert requestRecord;
        return requestRecord.Id;
    }

    @AuraEnabled
    public static void updateStatus(Id requestId, String newStatus) {
        Set<String> validStatuses = new Set<String>{
            'Open', 'In Progress', 'Completed', 'Cancelled'
        };

        if (requestId == null || !validStatuses.contains(newStatus)) {
            throw new AuraHandledException('Select a valid maintenance status.');
        }

        update new Maintenance_Request__c(
            Id = requestId,
            Status__c = newStatus
        );
    }
}
