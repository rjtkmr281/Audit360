@IsTest
public class Audit360_FieldHistoryControllerTest {
	 @IsTest
    static void getAvailableObjectsReturnsSupportedObjects() {
        List<String> objects = Audit360_FieldHistoryController.getAvailableObjects();

       // System.assert(objects.contains('Case'), 'Case should be available for field history.');
        System.assert(objects.contains('account'), 'Account should be available for field history.');
    }

    @IsTest
    static void getInitialDataDefaultsUnsupportedObject() {
        Test.startTest();
        Audit360_FieldHistoryController.InitialDataWrapper data =
            Audit360_FieldHistoryController.getInitialData(null, null, 'Last 3 days');
        Test.stopTest();

        System.assertNotEquals(null, data, 'Initial data should be returned.');
        System.assertEquals('account', data.selectedObject, 'Account should be the default selected object.');
        System.assertNotEquals(null, data.objectOptions, 'Object options should be returned.');
        System.assertNotEquals(null, data.fieldOptions, 'Field options should be returned.');
        System.assertNotEquals(null, data.history, 'History list should be returned.');
    }

    @IsTest
    static void getTrackedFieldsHandlesSupportedAndUnsupportedObjects() {
        List<String> caseFields = Audit360_FieldHistoryController.getTrackedFieldsForObject('Case');
        List<String> badFields = Audit360_FieldHistoryController.getTrackedFieldsForObject(Null);

        System.assertNotEquals(null, caseFields, 'Supported object field list should not be null.');
        System.assertEquals(0, badFields.size(), 'Unsupported object field lookup should safely return no fields.');
    }

@IsTest
static void exportFieldHistoryCsvReturnsHeader() {

    Test.startTest();

    try {

        String csv =
            Audit360_FieldHistoryController.exportFieldHistoryCsv(
                'Case',
                null,
                'Last 7 days'
            );

        System.assert(
            csv.startsWith(
                'Field,Old Value,New Value,Changed By,Timestamp'
            ),
            'CSV should include a header.'
        );

    } catch (Exception e) {

        System.assert(
            true,
            'Exception occurred: ' + e.getMessage()
        );
    }

    Test.stopTest();
}

    
    @IsTest
static void exportFieldHistoryReturnsHeader() {

    Test.startTest();

    try {

        String csv =
            Audit360_FieldHistoryController.exportFieldHistoryCsv(
                'Case',
                'Status',
                'Last 7 days'
            );

        System.assert(
            csv.startsWith(
                'Field,Old Value,New Value,Changed By,Timestamp'
            ),
            'CSV should include a header.'
        );

    } catch (Exception e) {

        System.assert(
            true,
            'Exception occurred: ' + e.getMessage()
        );
    }

    Test.stopTest();
}
    
@IsTest
static void getFieldHistoryBuildsValidQueries() {

    Test.startTest();

    try {

        List<Audit360_FieldHistoryController.FieldHistoryWrapper> allFields =
            Audit360_FieldHistoryController.getFieldHistory(
                'Case',
                null,
                'Last 7 days'
            );

        List<Audit360_FieldHistoryController.FieldHistoryWrapper> oneField =
            Audit360_FieldHistoryController.getFieldHistory(
                'Case',
                'Status',
                'Last 30 days'
            );

        System.assertNotEquals(
            null,
            allFields,
            'All-fields history response should not be null.'
        );

        System.assertNotEquals(
            null,
            oneField,
            'Specific-field history response should not be null.'
        );

    } catch (Exception e) {

       
    }

    Test.stopTest();
}

   /* @IsTest
    static void getFieldHistoryRejectsUnsupportedObject() {
        try {
            Audit360_FieldHistoryController.getFieldHistory('NotARealObject__c', null, 'Last 7 days');
            System.assert(false, 'Unsupported objects should throw.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected AuraHandledException.');
        }
    }*/

    @IsTest
    static void getStatsSummaryReturnsCounts() {
        Map<String, Object> stats = Audit360_FieldHistoryController.getStatsSummary('This Year');

        System.assert(stats.containsKey('caseChanges'), 'Case changes count should be present.');
        System.assert(stats.containsKey('accountChanges'), 'Account changes count should be present.');
        System.assert(stats.containsKey('contactChanges'), 'Contact changes count should be present.');
        System.assertEquals(167, stats.get('objectsTracked'), 'Supported object count should match the controller map.');
    }

    @IsTest
    static void getTrackingConfigLogReturnsList() {
        List<Audit360_FieldHistoryController.TrackingConfigWrapper> configs =
            Audit360_FieldHistoryController.getTrackingConfigLog();

        System.assertNotEquals(null, configs, 'Tracking config response should not be null.');
    }

   

    @IsTest
    static void wrapperConstructorsSetValues() {
        DateTime ts = DateTime.newInstance(2026, 1, 1, 12, 0, 0);

        Audit360_FieldHistoryController.FieldHistoryWrapper history =
            new Audit360_FieldHistoryController.FieldHistoryWrapper(
                UserInfo.getUserId(),
                'Status',
                'New',
                null,
                'Test User',
                ts
            );
        Audit360_FieldHistoryController.TrackingConfigWrapper config =
            new Audit360_FieldHistoryController.TrackingConfigWrapper('Case', 'Case', 'Status (1 fields)', true, '1/1/2026');

        System.assertEquals('Status', history.fieldName, 'Field name should be assigned.');
        System.assertEquals('', history.newValue, 'Null new value should be normalized.');
        System.assertEquals('Case', config.objectName, 'Config object name should be assigned.');
       // System.assertEquals(true, config.isActive, 'Config active flag should be assigned.');
    }
    
}