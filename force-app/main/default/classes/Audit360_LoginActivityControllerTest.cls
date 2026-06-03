@IsTest
public class Audit360_LoginActivityControllerTest {

    // ─────────────────────────────────────────────────────────────
    // TEST SETUP DATA
    // ─────────────────────────────────────────────────────────────

    @testSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        List<User> users = new List<User>();

        for(Integer i = 0; i < 500; i++) {

            users.add(new User(
                FirstName         = 'Test',
                LastName          = 'User' + i,
                Alias             = 'tu' + i,
                Email             = 'testuser' + i + '@example.com',
                Username          = 'testuser' + i + System.currentTimeMillis() + '@example.com',
                CommunityNickname = 'nick' + i,
                TimeZoneSidKey    = 'Asia/Kolkata',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId         = p.Id
            ));
        }

        insert users;
    }

    // ─────────────────────────────────────────────────────────────
    // getLoginHistory
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetLoginHistory() {

        Test.startTest();

        Audit360_LoginActivityController.LoginHistoryResult result =
            Audit360_LoginActivityController.getLoginHistory(
                null,
                'All',
                'All',
                'All',
                'LAST30',
                null,
                null,
                'LoginTime',
                'desc',
                200,
                1
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.records);
    }

    // ─────────────────────────────────────────────────────────────
    // Dashboard Stats
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testDashboardStats() {

        Test.startTest();

        Audit360_LoginActivityController.DashboardStats stats =
            Audit360_LoginActivityController.getDashboardStats('LAST30');

        Test.stopTest();

        System.assertNotEquals(null, stats);
        System.assertNotEquals(null, stats.browserBreakdown);
        System.assertNotEquals(null, stats.dailyTrend);
    }

    // ─────────────────────────────────────────────────────────────
    // User Login History
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testUserLoginHistory() {

        User u = [
            SELECT Id
            FROM User
            WHERE Email LIKE 'testuser%@example.com'
            LIMIT 1
        ];

        Test.startTest();

        List<Audit360_LoginActivityController.LoginHistoryWrapper> result =
            Audit360_LoginActivityController.getUserLoginHistory(
                u.Id,
                200
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─────────────────────────────────────────────────────────────
    // Security Alerts
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSecurityAlerts() {

        Test.startTest();

        List<Audit360_LoginActivityController.SecurityAlert> alerts =
            Audit360_LoginActivityController.getSecurityAlerts();

        Test.stopTest();

        System.assertNotEquals(null, alerts);
    }

    // ─────────────────────────────────────────────────────────────
    // Export CSV
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testExportToCsv() {

        Test.startTest();

        String documentId =
            Audit360_LoginActivityController.exportToCsv(
                null,
                'All',
                'All',
                'All',
                'LAST30',
                null,
                null
            );

        Test.stopTest();

        System.assertNotEquals(null, documentId);

        ContentDocument cd = [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :documentId
            LIMIT 1
        ];

        System.assertNotEquals(null, cd);
    }

    // ─────────────────────────────────────────────────────────────
    // Invalid Sort Field
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testInvalidSortField() {

        Test.startTest();

        Audit360_LoginActivityController.LoginHistoryResult result =
            Audit360_LoginActivityController.getLoginHistory(
                null,
                'All',
                'All',
                'All',
                'LAST30',
                null,
                null,
                'INVALID_FIELD',
                'desc',
                10,
                1
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─────────────────────────────────────────────────────────────
    // Custom Date Filter
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testCustomDateFilter() {

        Test.startTest();

        Audit360_LoginActivityController.LoginHistoryResult result =
            Audit360_LoginActivityController.getLoginHistory(
                null,
                'All',
                'All',
                'All',
                'CUSTOM',
                '2025-01-01',
                '2025-12-31',
                'LoginTime',
                'asc',
                50,
                1
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─────────────────────────────────────────────────────────────
    // Search Filters
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSearchAndFilters() {

        Test.startTest();

        Audit360_LoginActivityController.LoginHistoryResult result =
            Audit360_LoginActivityController.getLoginHistory(
                'test',
                'Success',
                'Application',
                'Chrome',
                'LAST30',
                null,
                null,
                'LoginTime',
                'desc',
                50,
                1
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─────────────────────────────────────────────────────────────
    // Null Default Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testNullDefaults() {

        Test.startTest();

        Audit360_LoginActivityController.LoginHistoryResult result =
            Audit360_LoginActivityController.getLoginHistory(
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─────────────────────────────────────────────────────────────
    // Wrapper Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testWrapperCoverage() {

        Audit360_LoginActivityController.ChartPoint cp =
            new Audit360_LoginActivityController.ChartPoint();

        cp.label = 'Test';
        cp.value = 1;

        Audit360_LoginActivityController.UserStat us =
            new Audit360_LoginActivityController.UserStat();

        us.userId   = '005000000000001';
        us.userName = 'User';
        us.count    = 10;

        Audit360_LoginActivityController.IpStat ip =
            new Audit360_LoginActivityController.IpStat();

        ip.ipAddress = '127.0.0.1';
        ip.count     = 5;

        System.assertEquals('Test', cp.label);
        System.assertEquals(10, us.count);
        System.assertEquals(5, ip.count);
    }

    // ─────────────────────────────────────────────────────────────
    // Invalid UserId Exception Coverage
    // ─────────────────────────────────────────────────────────────

    
    // ─────────────────────────────────────────────────────────────
    // Invalid Custom Date Coverage
    // ─────────────────────────────────────────────────────────────

    

    // ─────────────────────────────────────────────────────────────
    // Asc Sort Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testAscendingSortCoverage() {

        Test.startTest();

        Audit360_LoginActivityController.LoginHistoryResult result =
            Audit360_LoginActivityController.getLoginHistory(
                null,
                'Failed',
                'Application',
                'Firefox',
                'LAST7',
                null,
                null,
                'Platform',
                'asc',
                25,
                2
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─────────────────────────────────────────────────────────────
    // Empty User History Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testEmptyUserHistory() {

        Id fakeId = UserInfo.getUserId();

        Test.startTest();

        List<Audit360_LoginActivityController.LoginHistoryWrapper> result =
            Audit360_LoginActivityController.getUserLoginHistory(
                fakeId,
                null
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ─────────────────────────────────────────────────────────────
    // Export CSV Additional Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testExportCsvWithFilters() {

        Test.startTest();

        String docId =
            Audit360_LoginActivityController.exportToCsv(
                'test',
                'Failed',
                'Application',
                'Chrome',
                'LAST7',
                null,
                null
            );

        Test.stopTest();

        System.assertNotEquals(null, docId);
    }

    // ─────────────────────────────────────────────────────────────
    // Dashboard LAST7 Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testDashboardLast7() {

        Test.startTest();

        Audit360_LoginActivityController.DashboardStats stats =
            Audit360_LoginActivityController.getDashboardStats('LAST7');

        Test.stopTest();

        System.assertNotEquals(null, stats);
        System.assert(stats.totalLogins >= 0);
    }

    // ─────────────────────────────────────────────────────────────
    // Security Alerts Additional Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSecurityAlertsAgain() {

        Test.startTest();

        List<Audit360_LoginActivityController.SecurityAlert> alerts =
            Audit360_LoginActivityController.getSecurityAlerts();

        Test.stopTest();

        for(Audit360_LoginActivityController.SecurityAlert a : alerts) {

            System.assertNotEquals(null, a.alertType);
            System.assertNotEquals(null, a.severity);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Pagination Edge Coverage
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testPaginationDefaults() {

        Test.startTest();

        Audit360_LoginActivityController.LoginHistoryResult result =
            Audit360_LoginActivityController.getLoginHistory(
                null,
                'All',
                'All',
                'All',
                'LAST30',
                null,
                null,
                'LoginTime',
                'desc',
                -1,
                -1
            );

        Test.stopTest();

        System.assertEquals(1, result.pageNumber);
        System.assertEquals(20, result.pageSize);
    }
}