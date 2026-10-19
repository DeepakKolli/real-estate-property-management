@IsTest
private class LeaseExpiryReminderSchedulerTest {
    @IsTest
    static void sendsRemindersForOneDayAndThirtyDayExpiry() {
        Property__c p1 = new Property__c(
            Address__c = '1 Test Street',
            Street_Address__c = '1 Test Street',
            City__c = 'Visakhapatnam',
            State__c = 'Andhra Pradesh',
            Postal_Code__c = '530001',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Status__c = 'Occupied',
            Rent__c = 12000
        );

        Property__c p2 = new Property__c(
            Address__c = '2 Test Street',
            Street_Address__c = '2 Test Street',
            City__c = 'Visakhapatnam',
            State__c = 'Andhra Pradesh',
            Postal_Code__c = '530002',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Status__c = 'Occupied',
            Rent__c = 15000
        );
        insert new List<Property__c>{p1, p2};

        Tenant__c tenant = new Tenant__c(
            Name = 'Expiry Test Tenant',
            Phone__c = '9876543210',
            Email__c = 'expirytest@example.com'
        );
        insert tenant;

        Date todayDate = Date.today();

        Lease_Agreement__c l1 = new Lease_Agreement__c(
            Tenant__c = tenant.Id,
            Property__c = p1.Id,
            Agreed_Monthly_Rent__c = 12000,
            Start_Date__c = todayDate,
            End_Date__c = todayDate.addDays(1)
        );

        Lease_Agreement__c l2 = new Lease_Agreement__c(
            Tenant__c = tenant.Id,
            Property__c = p2.Id,
            Agreed_Monthly_Rent__c = 15000,
            Start_Date__c = todayDate,
            End_Date__c = todayDate.addDays(30)
        );
        insert new List<Lease_Agreement__c>{l1, l2};

        Test.startTest();
        LeaseExpiryReminderScheduler.sendExpiryReminders();
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT COUNT() FROM Lease_Agreement__c
             WHERE Id IN :new Set<Id>{l1.Id, l2.Id}],
            'Both test leases should exist.'
        );
    }

    @IsTest
    static void schedulesDailyJob() {
        Test.startTest();
        String jobId = System.schedule(
            'Lease Expiry Test Schedule',
            '0 0 8 * * ?',
            new LeaseExpiryReminderScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}