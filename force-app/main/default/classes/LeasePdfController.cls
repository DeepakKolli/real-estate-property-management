public with sharing class LeasePdfController {
    @AuraEnabled(cacheable=true)
    public static Lease_Agreement__c getLeaseDetails(Id leaseId) {
        if (leaseId == null) {
            throw new AuraHandledException('A lease record is required.');
        }

        return [
            SELECT Id, Name, Agreed_Monthly_Rent__c, Start_Date__c,
                   End_Date__c, Tenant__r.Name, Tenant__r.Email__c,
                   Property__r.Name, Property__r.Address__c
            FROM Lease_Agreement__c
            WHERE Id = :leaseId
            LIMIT 1
        ];
    }
}
