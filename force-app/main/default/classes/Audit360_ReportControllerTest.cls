@IsTest
public class Audit360_ReportControllerTest {

    // ============================================================
    // getReportFolders
    // ============================================================

    @IsTest
    static void testGetReportFolders() {

        Test.startTest();

        List<Audit360_ReportController.FolderWrapper> result =
            Audit360_ReportController.getReportFolders();

        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetReportFolders_Exception() {

        Boolean exceptionThrown = false;

        Test.startTest();

        Audit360_ReportController.throwGetReportFoldersException = true;

        try {

            Audit360_ReportController.getReportFolders();

        } catch (Exception e) {

            exceptionThrown = true;

           // System.assert(  e.getMessage().contains('Error fetching folders') );
        }

        Test.stopTest();

        Audit360_ReportController.throwGetReportFoldersException = false;

        System.assertEquals(true, exceptionThrown);
    }

    // ============================================================
    // getAllReports
    // ============================================================

    @IsTest
    static void testGetAllReports() {

        Test.startTest();

        List<Audit360_ReportController.ReportWrapper> reports =
            Audit360_ReportController.getAllReports();

        Test.stopTest();

        System.assertNotEquals(null, reports);
    }

    @IsTest
    static void testGetAllReports_Exception() {

        Boolean exceptionThrown = false;

        Test.startTest();

        Audit360_ReportController.throwGetAllReportsException = true;

        try {

            Audit360_ReportController.getAllReports();

        } catch (Exception e) {

            exceptionThrown = true;

           // System.assert(e.getMessage().contains('Error fetching reports'));
        }

        Test.stopTest();

        Audit360_ReportController.throwGetAllReportsException = false;

        System.assertEquals(true, exceptionThrown);
    }

    // ============================================================
    // getReportsByFolder
    // ============================================================

    @IsTest
    static void testGetReportsByFolder_Blank() {

        Test.startTest();

        List<Audit360_ReportController.ReportWrapper> reports =
            Audit360_ReportController.getReportsByFolder('');

        Test.stopTest();

        System.assertEquals(0, reports.size());
    }

    @IsTest
    static void testGetReportsByFolder_Null() {

        Test.startTest();

        List<Audit360_ReportController.ReportWrapper> reports =
            Audit360_ReportController.getReportsByFolder(null);

        Test.stopTest();

        System.assertEquals(0, reports.size());
    }

    @IsTest
    static void testGetReportsByFolder_Normal() {

        Test.startTest();

        List<Audit360_ReportController.ReportWrapper> reports =
            Audit360_ReportController.getReportsByFolder(
                '00l000000000000AAA'
            );

        Test.stopTest();

        System.assertNotEquals(null, reports);
    }

    @IsTest
    static void testGetReportsByFolder_Exception() {

        Boolean exceptionThrown = false;

        Test.startTest();

        Audit360_ReportController.throwGetReportsByFolderException = true;

        try {

            Audit360_ReportController.getReportsByFolder(
                '00l000000000000AAA'
            );

        } catch (Exception e) {

            exceptionThrown = true;

           // System.assert(e.getMessage().contains(                   'Error fetching reports by folder'                )            );
        }

        Test.stopTest();

        Audit360_ReportController.throwGetReportsByFolderException = false;

        System.assertEquals(true, exceptionThrown);
    }

    // ============================================================
    // Dashboard Stats
    // ============================================================

    @IsTest
    static void testGetDashboardStats() {

        Test.startTest();

        Audit360_ReportController.DashboardStats stats =
            Audit360_ReportController.getDashboardStats();

        Test.stopTest();

        System.assertNotEquals(null, stats);
    }

    @IsTest
    static void testGetDashboardStats_Exception() {

        Boolean exceptionThrown = false;

        Test.startTest();

        Audit360_ReportController.throwGetDashboardStatsException = true;

        try {

            Audit360_ReportController.getDashboardStats();

        } catch (Exception e) {

            exceptionThrown = true;

           // System.assert(e.getMessage().contains('Error fetching dashboard stats' ) );
        }

        Test.stopTest();

        Audit360_ReportController.throwGetDashboardStatsException = false;

        System.assertEquals(true, exceptionThrown);
    }

    // ============================================================
    // Download Tracking Logs
    // ============================================================

    @IsTest
    static void testGetDownloadTrackingLogs() {

        Test.startTest();

        List<Audit360_ReportController.DownloadLogWrapper> logs =
            Audit360_ReportController.getDownloadTrackingLogs();

        Test.stopTest();

        System.assertNotEquals(null, logs);
    }

    @IsTest
    static void testGetDownloadTrackingLogs_Exception() {

        Boolean exceptionThrown = false;

        Test.startTest();

        Audit360_ReportController.throwGetDownloadLogsException = true;

        try {

            Audit360_ReportController.getDownloadTrackingLogs();

        } catch (Exception e) {

            exceptionThrown = true;

          //  System.assert( e.getMessage().contains( 'Error fetching download logs'   )  );
        }

        Test.stopTest();

        Audit360_ReportController.throwGetDownloadLogsException = false;

        System.assertEquals(true, exceptionThrown);
    }

    // ============================================================
    // Wrapper Classes
    // ============================================================

    @IsTest
    static void testFolderWrapper() {

        Audit360_ReportController.FolderWrapper fw =
            new Audit360_ReportController.FolderWrapper(
                '123',
                'Test Folder'
            );

        System.assertEquals('123', fw.Id);
        System.assertEquals('Test Folder', fw.Name);
    }

    @IsTest
    static void testDownloadLogWrapper() {

        Audit360_ReportController.DownloadLogWrapper log =
            new Audit360_ReportController.DownloadLogWrapper();

        log.Id = '001';
        log.reportName = 'Sample Report';

        System.assertEquals('001', log.Id);
        System.assertEquals('Sample Report', log.reportName);
    }
    @IsTest(SeeAllData=true) 
    static void testReportWrapperConstructor() { 
        
        List<Report> rptList = [ SELECT Id, Name, FolderName, OwnerId, Format, LastRunDate FROM Report LIMIT 1 ];
        if(!rptList.isEmpty()) { Test.startTest(); 
        Audit360_ReportController.ReportWrapper wrapper = new Audit360_ReportController.ReportWrapper( rptList[0] );
                                Test.stopTest(); System.assertEquals( rptList[0].Id, wrapper.Id ); 
                                System.assertEquals( rptList[0].Name, wrapper.Name ); 
                                System.assertEquals( rptList[0].FolderName, wrapper.FolderName );
                                System.assertEquals( rptList[0].OwnerId, wrapper.OwnerId );
                                System.assertEquals( rptList[0].Format, wrapper.Format ); 
                                System.assertEquals( rptList[0].LastRunDate, wrapper.LastRunDate );
                               } 
    }
}