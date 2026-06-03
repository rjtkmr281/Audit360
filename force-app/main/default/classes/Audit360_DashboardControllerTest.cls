@IsTest
public class Audit360_DashboardControllerTest {
	
    @isTest
    static void testGetKPIData() {

        // Test Start
        Test.startTest();

        Map<String, Object> result =
            Audit360_DashboardController.getKPIData();

        Test.stopTest();

        // Verify Map is not null
        System.assertNotEquals(
            null,
            result,
            'Result map should not be null'
        );

        // Verify Keys Exist
        System.assert(
            result.containsKey('completed'),
            'Completed key should exist'
        );

        System.assert(
            result.containsKey('failed'),
            'Failed key should exist'
        );

        System.assert(
            result.containsKey('aborted'),
            'Aborted key should exist'
        );

        System.assert(
            result.containsKey('queued'),
            'Queued key should exist'
        );

        System.assert(
            result.containsKey('successRate'),
            'SuccessRate key should exist'
        );

        // Validate Data Types
        Integer completed = (Integer) result.get('completed');
        Integer failed = (Integer) result.get('failed');
        Integer aborted = (Integer) result.get('aborted');
        Integer queued = (Integer) result.get('queued');
        Decimal successRate = (Decimal) result.get('successRate');

        System.assertNotEquals(null, completed);
        System.assertNotEquals(null, failed);
        System.assertNotEquals(null, aborted);
        System.assertNotEquals(null, queued);
        System.assertNotEquals(null, successRate);

        // Validate Success Rate Logic
        Integer total = completed + failed + aborted + queued;

        if (total > 0) {

            Decimal expectedRate =
                (Decimal.valueOf(completed) / total) * 100;

            expectedRate = expectedRate.setScale(1);

            System.assertEquals(
                expectedRate,
                successRate,
                'Success rate should match expected calculation'
            );
        }
        else {

            System.assertEquals(
                0,
                successRate,
                'Success rate should be 0 when total is 0'
            );
        }
    }
}