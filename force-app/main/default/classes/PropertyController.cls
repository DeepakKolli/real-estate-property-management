public with sharing class PropertyController {
    private static final Integer PAGE_SIZE = 25;

    public class PropertyPage {
        @AuraEnabled public List<Property__c> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }

        public PropertyPage(List<Property__c> records, Integer totalRecords) {
            this.records = records;
            this.totalRecords = totalRecords;
        }
    }

    @AuraEnabled(cacheable=true)
    public static PropertyPage getProperties(
        Integer pageNumber,
        String propertyStatus,
        String furnishingStatus,
        Decimal minRent,
        Decimal maxRent
    ) {
        Integer page = (pageNumber == null || pageNumber < 1)
            ? 1 : pageNumber;
        Integer rowOffset = (page - 1) * PAGE_SIZE;

        List<String> conditions = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        if (String.isNotBlank(propertyStatus)) {
            conditions.add('Status__c = :propertyStatus');
            binds.put('propertyStatus', propertyStatus);
        }
        // if (String.isNotBlank(furnishingStatus)) {
        //     conditions.add('Furnishing_Status__c = :furnishingStatus');
        //     binds.put('furnishingStatus', furnishingStatus);
        // }
        if (minRent != null) {
            conditions.add('Rent__c >= :minRent');
            binds.put('minRent', minRent);
        }
        if (maxRent != null) {
            conditions.add('Rent__c <= :maxRent');
            binds.put('maxRent', maxRent);
        }

        String whereClause = conditions.isEmpty()
            ? '' : ' WHERE ' + String.join(conditions, ' AND ');

        String countQuery =
            'SELECT COUNT() FROM Property__c' + whereClause;

        Integer total = (Integer) Database.countQueryWithBinds(
            countQuery, binds, AccessLevel.USER_MODE
        );

String recordsQuery =
    'SELECT Id, Name, Address__c, City__c, State__c, ' +
    'Country__c, Postal_Code__c, Property_Type__c, ' +
    'Status__c, Rent__c ' +
    'FROM Property__c' + whereClause +
    ' ORDER BY CreatedDate DESC LIMIT :pageSize OFFSET :rowOffset';

        binds.put('pageSize', PAGE_SIZE);
        binds.put('rowOffset', rowOffset);

        List<Property__c> records = (List<Property__c>)
            Database.queryWithBinds(
                recordsQuery, binds, AccessLevel.USER_MODE
            );

        return new PropertyPage(records, total);
    }
}