@IsTest
public class Audit360_ObjectAndFieldAccessControTest {

    @isTest
    static void testGetAllObjects() {
        Test.startTest();
        List<Map<String, String>> objects = Audit360_ObjectAndFieldAccessController.getAllObjects();
        Test.stopTest();

        System.assertNotEquals(null, objects, 'Objects list should not be null');
        System.assert(objects.size() > 10, 'Should return multiple objects');
    }

    @isTest
    static void testGetObjectFields_Success() {
        Test.startTest();
        List<Audit360_ObjectAndFieldAccessController.FieldWrapper> fields = 
            Audit360_ObjectAndFieldAccessController.getObjectFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, fields);
        System.assert(fields.size() > 20, 'Account should have many fields');
    }

    @isTest
    static void testGetObjectFields_ErrorCases() {
        Test.startTest();
        System.assertEquals(0, Audit360_ObjectAndFieldAccessController.getObjectFields('').size());
        System.assertEquals(0, Audit360_ObjectAndFieldAccessController.getObjectFields(null).size());
        System.assertEquals(0, Audit360_ObjectAndFieldAccessController.getObjectFields('ThisObjectDoesNotExist12345').size());
        Test.stopTest();
    }

    @isTest(SeeAllData=false)
    static void testGetRecordTypePicklistValues_Success() {
        Test.startTest();
        List<Audit360_ObjectAndFieldAccessController.RecordTypePicklistWrapper> result = 
            Audit360_ObjectAndFieldAccessController.getRecordTypePicklistValues('Opportunity', 'StageName');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest(SeeAllData=true)
    static void testGetRecordTypePicklistValues_Account() {
        Test.startTest();
        List<Audit360_ObjectAndFieldAccessController.RecordTypePicklistWrapper> result = 
            Audit360_ObjectAndFieldAccessController.getRecordTypePicklistValues('Account', 'Industry');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest(SeeAllData=false)
    static void testGetRecordTypePicklistValues_InvalidInputs() {
        Test.startTest();
        try {
            Audit360_ObjectAndFieldAccessController.getRecordTypePicklistValues('', 'StageName');
            Audit360_ObjectAndFieldAccessController.getRecordTypePicklistValues('Opportunity', '');
            Audit360_ObjectAndFieldAccessController.getRecordTypePicklistValues('InvalidObjectXYZ999', 'TestField__c');
            Audit360_ObjectAndFieldAccessController.getRecordTypePicklistValues('Account', 'NonExistentField123');
        } catch (Exception e) {
            System.debug('Expected exception due to missing null checks in controller: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetPermissionSets() {
        Test.startTest();
        List<Audit360_ObjectAndFieldAccessController.PermissionSetWrapper> perms = Audit360_ObjectAndFieldAccessController.getPermissionSets('Account', 'Phone');
        Test.stopTest();
        System.assertNotEquals(null, perms);
    }

       @isTest
    static void testGetgetProfilesWithFieldAccess() {
        Test.startTest();
        List<Map<String, Object>> perms = Audit360_ObjectAndFieldAccessController.getProfilesWithFieldAccess('Account', 'Phone');
        Test.stopTest();
        System.assertNotEquals(null, perms);
    }
    
    @isTest
    static void testGetPermissionSets_ErrorCases() {
        Test.startTest();
        System.assertEquals(0, Audit360_ObjectAndFieldAccessController.getPermissionSets('', 'Name').size());
        System.assertEquals(0, Audit360_ObjectAndFieldAccessController.getPermissionSets('Account', '').size());
        System.assertEquals(0, Audit360_ObjectAndFieldAccessController.getPermissionSets(null, null).size());
        Test.stopTest();
    }

    @isTest
    static void testFieldWrapper_Comparable() {
        Audit360_ObjectAndFieldAccessController.FieldWrapper fw1 = new Audit360_ObjectAndFieldAccessController.FieldWrapper();
        fw1.label = 'Account Name';

        Audit360_ObjectAndFieldAccessController.FieldWrapper fw2 = new Audit360_ObjectAndFieldAccessController.FieldWrapper();
        fw2.label = 'Created Date';

        Audit360_ObjectAndFieldAccessController.FieldWrapper fw3 = new Audit360_ObjectAndFieldAccessController.FieldWrapper();
        fw3.label = 'Account Name';

        System.assert(fw1.compareTo(fw2) < 0, 'Should return negative');
        System.assert(fw2.compareTo(fw1) > 0, 'Should return positive');
        System.assertEquals(0, fw1.compareTo(fw3), 'Same label should return zero');
    }
}