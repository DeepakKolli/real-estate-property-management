public with sharing class PropertyFormController {
    @AuraEnabled
    public static Id createProperty(
        String address,
        String city,
        String state,
        String postalCode,
        String country,
        String propertyType,
        String furnishingStatus,
        String propertyStatus,
        Decimal rent,
        String description,
        List<Id> documentIds
    ) {
        if (documentIds == null || documentIds.isEmpty()) {
            throw new AuraHandledException(
                'Upload at least one property image before saving.'
            );
        }

        Property__c propertyRecord = new Property__c(
            Address__c = address,
            Street_Address__c = address,
            City__c = city,
            State__c = state,
            Postal_Code__c = postalCode,
            Country__c = country,
            Property_Type__c = propertyType,
            Status__c = propertyStatus,
            Rent__c = rent
        );

        try {
            insert propertyRecord;
        } catch (DmlException e) {
            throw new AuraHandledException('Property insert failed: ' + e.getDmlMessage(0));
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id documentId : documentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = documentId,
                LinkedEntityId = propertyRecord.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        try {
            insert links;
        } catch (DmlException e) {
            throw new AuraHandledException('Image linking failed: ' + e.getDmlMessage(0));
        }

        return propertyRecord.Id;
    }
}