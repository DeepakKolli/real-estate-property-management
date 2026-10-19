
@IsTest
private class RealEstateControllersTest {

    private static Property__c makeProperty(String address, String status, Decimal rent) {
        return new Property__c(
            Address__c = address,
            Street_Address__c = address,
            City__c = 'Visakhapatnam',
            State__c = 'Andhra Pradesh',
            Postal_Code__c = '530001',
            Country__c = 'India',
            Property_Type__c = 'Residential',
            Status__c = status,
            Rent__c = rent
        );
    }

    private static Tenant__c makeTenant() {
        Tenant__c t = new Tenant__c(
            Name = 'Test Tenant',
            Phone__c = '9876543210',
            Email__c = 'tenant@example.com'
        );
        insert t;
        return t;
    }

    private static Vendor__c makeVendor(String vendorName) {
        Vendor__c v = new Vendor__c(
            Name = vendorName,
            Phone__c = '9876543210',
            Email__c = vendorName.replace(' ', '').toLowerCase() + '@example.com'
        );
        insert v;
        return v;
    }

    @IsTest
    static void propertyListingAndFilters() {
        insert new List<Property__c>{
            makeProperty('Test House 1', 'Available', 10000),
            makeProperty('Test House 2', 'Occupied', 20000)
        };

        Test.startTest();
        PropertyController.PropertyPage allProperties =
            PropertyController.getProperties(1, null, null, null, null);

        PropertyController.PropertyPage filtered =
            PropertyController.getProperties(1, 'Available', null, 5000, 15000);

        PropertyController.PropertyPage normalizedPage =
            PropertyController.getProperties(0, null, null, null, null);
        Test.stopTest();

        System.assert(allProperties.totalRecords >= 2);
        System.assertEquals(1, filtered.totalRecords);
        System.assertEquals('Available', filtered.records[0].Status__c);
        System.assert(normalizedPage.records.size() > 0);
    }

    @IsTest
    static void propertyFormRequiresImage() {
        Boolean thrown = false;

        try {
            PropertyFormController.createProperty(
                'Image Test House', 'Visakhapatnam', 'Andhra Pradesh',
                '530001', 'India', 'Residential', 'Unfurnished',
                'Available', 12000, 'Test description', new List<Id>()
            );
        } catch (Exception e) {
            thrown = true;
        }

        System.assert(thrown, 'Saving without an image should be rejected.');
    }

    @IsTest
    static void propertyFormCreatesPropertyAndLinksImage() {
        ContentVersion cv = new ContentVersion(
            Title = 'Property Image',
            PathOnClient = 'property.jpg',
            VersionData = Blob.valueOf('Test image content')
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        Test.startTest();
        Id propertyId = PropertyFormController.createProperty(
            'Image Test House', 'Visakhapatnam', 'Andhra Pradesh',
            '530001', 'India', 'Residential', 'Unfurnished',
            'Available', 12000, 'Test description',
            new List<Id>{cv.ContentDocumentId}
        );
        Test.stopTest();

        System.assertNotEquals(null, propertyId);
        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDocumentLink
             WHERE LinkedEntityId = :propertyId]
        );
    }

    @IsTest
    static void tenantCreationAndLeaseCreation() {
        Property__c p = makeProperty('Lease Test House', 'Available', 15000);
        insert p;

        Test.startTest();
        Id tenantId = TenantLeaseController.createTenant(
            'Lease Tenant', '9876543210', 'lease@example.com'
        );

        Id leaseId = TenantLeaseController.createLease(
            tenantId, p.Id, 'One year residential lease',
            15000, Date.today(), Date.today().addDays(365)
        );
        Test.stopTest();

        System.assertNotEquals(null, tenantId);
        System.assertNotEquals(null, leaseId);

        Property__c updatedProperty = [
            SELECT Status__c FROM Property__c WHERE Id = :p.Id
        ];
        System.assertEquals('Occupied', updatedProperty.Status__c);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Task WHERE WhatId = :leaseId]
        );

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Lease_Agreement__c WHERE Id = :leaseId]
        );
    }

    @IsTest
    static void tenantAndLeaseValidation() {
        Boolean tenantRejected = false;
        try {
            TenantLeaseController.createTenant('', '', '');
        } catch (Exception e) {
            tenantRejected = true;
        }
        System.assert(tenantRejected);

        Tenant__c tenant = makeTenant();
        Property__c p = makeProperty('Validation House', 'Available', 10000);
        insert p;

        Boolean leaseRejected = false;
        try {
            TenantLeaseController.createLease(
                tenant.Id, p.Id, 'Invalid dates',
                10000, Date.today(), Date.today()
            );
        } catch (Exception e) {
            leaseRejected = true;
        }
        System.assert(leaseRejected);
    }

    @IsTest
    static void leaseDuplicateAndUnavailablePropertyRejected() {
        Tenant__c tenant = makeTenant();
        Property__c p = makeProperty('Duplicate Lease House', 'Available', 10000);
        insert p;

        TenantLeaseController.createLease(
            tenant.Id, p.Id, 'First lease',
            10000, Date.today(), Date.today().addDays(30)
        );

        Boolean duplicateRejected = false;
        try {
            TenantLeaseController.createLease(
                tenant.Id, p.Id, 'Second lease',
                10000, Date.today(), Date.today().addDays(60)
            );
        } catch (Exception e) {
            duplicateRejected = true;
        }
        System.assert(duplicateRejected);

        Property__c occupied = makeProperty(
            'Already Occupied House', 'Occupied', 10000
        );
        insert occupied;

        Boolean occupiedRejected = false;
        try {
            TenantLeaseController.createLease(
                tenant.Id, occupied.Id, 'Occupied property lease',
                10000, Date.today(), Date.today().addDays(30)
            );
        } catch (Exception e) {
            occupiedRejected = true;
        }
        System.assert(occupiedRejected);
    }

    @IsTest
    static void maintenanceCreationAndStatusUpdate() {
        Property__c p = makeProperty('Maintenance House', 'Available', 10000);
        insert p;

        makeVendor('Vendor Alpha');
        makeVendor('Vendor Beta');

        Test.startTest();
        Id requestId = MaintenanceController.createRequest(
            p.Id, 'Repair a leaking kitchen tap'
        );

        MaintenanceController.updateStatus(requestId, 'In Progress');
        List<Maintenance_Request__c> requests =
            MaintenanceController.getRequests();
        List<Property__c> properties =
            MaintenanceController.getProperties();
        Test.stopTest();

        Maintenance_Request__c savedRequest = [
            SELECT Status__c, Vendor__c, Request_Description__c, Property__c
            FROM Maintenance_Request__c
            WHERE Id = :requestId
        ];

        System.assertEquals('In Progress', savedRequest.Status__c);
        System.assertNotEquals(null, savedRequest.Vendor__c);
        System.assertEquals('Repair a leaking kitchen tap',
            savedRequest.Request_Description__c);
        System.assertEquals(p.Id, savedRequest.Property__c);
        System.assert(!requests.isEmpty());
        System.assert(!properties.isEmpty());
    }

    @IsTest
    static void maintenanceValidation() {
        Boolean missingPropertyRejected = false;
        try {
            MaintenanceController.createRequest(null, 'Repair needed');
        } catch (Exception e) {
            missingPropertyRejected = true;
        }
        System.assert(missingPropertyRejected);

        Boolean invalidStatusRejected = false;
        try {
            MaintenanceController.updateStatus(null, 'Unknown');
        } catch (Exception e) {
            invalidStatusRejected = true;
        }
        System.assert(invalidStatusRejected);
    }

    @IsTest
    static void leasePdfControllerReturnsDetails() {
        Tenant__c tenant = makeTenant();
        Property__c p = makeProperty('PDF Test House', 'Occupied', 12000);
        insert p;

        Lease_Agreement__c lease = new Lease_Agreement__c(
            Tenant__c = tenant.Id,
            Property__c = p.Id,
            Agreed_Monthly_Rent__c = 12000,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(365)
        );
        insert lease;

        Test.startTest();
        Lease_Agreement__c result =
            LeasePdfController.getLeaseDetails(lease.Id);
        Test.stopTest();

        System.assertEquals(lease.Id, result.Id);
        System.assertEquals(tenant.Name, result.Tenant__r.Name);
        System.assertEquals(p.Address__c, result.Property__r.Address__c);
    }

    @IsTest
    static void leasePdfControllerRejectsNullId() {
        Boolean thrown = false;
        try {
            LeasePdfController.getLeaseDetails(null);
        } catch (Exception e) {
            thrown = true;
        }
        System.assert(thrown);
    }
}
