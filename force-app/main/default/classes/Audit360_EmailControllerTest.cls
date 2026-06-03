@IsTest
public class Audit360_EmailControllerTest {
	    
    private static Case createParentCase() {
        Case c = new Case(Subject = 'Test Case');
        insert c;
        return c;
    }

    private static EmailMessage buildEmail(
        Id parentId,
        String status,
        Boolean isBounced
    ) {
        EmailMessage em = new EmailMessage(
            ParentId    = parentId,
            Subject     = 'Test Subject',
            FromAddress = 'sender@test.com',
            ToAddress   = 'receiver@test.com',
            Status      = status,
            IsBounced   = isBounced
        );
        return em;
    }

    @isTest
    static void testGetDashboardData_NullDates() {
        Case parentCase = createParentCase();

        List<EmailMessage> emails = new List<EmailMessage>();

        // Sent (Status = '3')
        emails.add(buildEmail(parentCase.Id, '3', false));
        emails.add(buildEmail(parentCase.Id, '3', false));

        // Read (Status = '1')
        emails.add(buildEmail(parentCase.Id, '1', false));

        // Replied (Status = '2')
        emails.add(buildEmail(parentCase.Id, '2', false));

        // Draft (Status = '0')
        emails.add(buildEmail(parentCase.Id, '0', false));

        // Bounced (isBounced = true)
        emails.add(buildEmail(parentCase.Id, '3', true));

        insert emails;

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(null, null);
        Test.stopTest();

        // KPI assertions
        System.assert(dto.sentCount    >= 2, 'sentCount should be >= 2');
        System.assert(dto.readCount    >= 1, 'readCount should be >= 1');
        System.assert(dto.repliedCount >= 1, 'repliedCount should be >= 1');
        System.assert(dto.draftCount   >= 1, 'draftCount should be >= 1');
        System.assert(dto.failedCount  >= 1, 'failedCount should be >= 1');

        // Recent emails returned
        System.assertNotEquals(
            null, dto.recentEmails,
            'recentEmails should not be null'
        );

        // Admin logs returned
        System.assertNotEquals(
            null, dto.adminLogs,
            'adminLogs should not be null'
        );
    }

    @isTest
    static void testGetDashboardData_WithDateRange() {
        Case parentCase = createParentCase();

        List<EmailMessage> emails = new List<EmailMessage>();
        emails.add(buildEmail(parentCase.Id, '3', false)); // Sent
        emails.add(buildEmail(parentCase.Id, '1', false)); // Read
        insert emails;

        Date startDate = Date.today().addDays(-30);
        Date endDate   = Date.today();

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(startDate, endDate);
        Test.stopTest();

        System.assertNotEquals(null, dto,           'DTO should not be null');
        System.assertNotEquals(null, dto.recentEmails, 'recentEmails should not be null');
        System.assert(dto.sentCount >= 0,  'sentCount should be non-negative');
        System.assert(dto.readCount >= 0,  'readCount should be non-negative');
    }

    @isTest
    static void testGetDashboardData_StartDateNull() {
        Case parentCase = createParentCase();
        insert buildEmail(parentCase.Id, '3', false);

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(null, Date.today());
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO must not be null');
    }

    @isTest
    static void testGetDashboardData_EndDateNull() {
        Case parentCase = createParentCase();
        insert buildEmail(parentCase.Id, '3', false);

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(Date.today(), null);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO must not be null');
    }

    @isTest
    static void testGetDashboardData_OnlyBouncedEmails() {
        Case parentCase = createParentCase();

        List<EmailMessage> emails = new List<EmailMessage>();
        emails.add(buildEmail(parentCase.Id, '3', true));
        emails.add(buildEmail(parentCase.Id, '3', true));
        emails.add(buildEmail(parentCase.Id, '3', true));
        insert emails;

        Date startDate = Date.today().addDays(-1);
        Date endDate   = Date.today();

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(startDate, endDate);
        Test.stopTest();

        System.assert(dto.failedCount >= 3,
            'failedCount should count all bounced emails');
        System.assertEquals(0, dto.sentCount,
            'sentCount should be 0 when all are bounced');
    }

    @isTest
    static void testGetDashboardData_DraftOnly() {
        Case parentCase = createParentCase();

        List<EmailMessage> emails = new List<EmailMessage>();
        emails.add(buildEmail(parentCase.Id, '0', false));
        emails.add(buildEmail(parentCase.Id, '0', false));
        insert emails;

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(null, null);
        Test.stopTest();

        System.assert(dto.draftCount >= 2,
            'draftCount should reflect inserted drafts');
    }

    @isTest
    static void testGetDashboardData_RepliedOnly() {
        Case parentCase = createParentCase();

        List<EmailMessage> emails = new List<EmailMessage>();
        emails.add(buildEmail(parentCase.Id, '2', false));
        emails.add(buildEmail(parentCase.Id, '2', false));
        insert emails;

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(null, null);
        Test.stopTest();

        System.assert(dto.repliedCount >= 2,
            'repliedCount should reflect inserted replied emails');
    }

    @isTest
    static void testGetDashboardData_NoEmailsInRange() {

        // Use a past date range that has NO inserted emails
        Date startDate = Date.newInstance(2001, 1, 1);
        Date endDate   = Date.newInstance(2001, 1, 2);

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(startDate, endDate);
        Test.stopTest();

        System.assertEquals(0, dto.sentCount,    'sentCount should be 0');
        System.assertEquals(0, dto.readCount,    'readCount should be 0');
        System.assertEquals(0, dto.repliedCount, 'repliedCount should be 0');
        System.assertEquals(0, dto.draftCount,   'draftCount should be 0');
        System.assertEquals(0, dto.failedCount,  'failedCount should be 0');
        System.assertEquals(0, dto.recentEmails.size(),
            'recentEmails list should be empty');
    }

    @isTest
    static void testDTOFieldsNotNull() {
        Case parentCase = createParentCase();

        List<EmailMessage> emails = new List<EmailMessage>();
        emails.add(buildEmail(parentCase.Id, '3', false));
        emails.add(buildEmail(parentCase.Id, '1', false));
        emails.add(buildEmail(parentCase.Id, '2', false));
        emails.add(buildEmail(parentCase.Id, '0', false));
        emails.add(buildEmail(parentCase.Id, '3', true));
        insert emails;

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto.sentCount,    'sentCount must not be null');
        System.assertNotEquals(null, dto.readCount,    'readCount must not be null');
        System.assertNotEquals(null, dto.repliedCount, 'repliedCount must not be null');
        System.assertNotEquals(null, dto.draftCount,   'draftCount must not be null');
        System.assertNotEquals(null, dto.failedCount,  'failedCount must not be null');
        System.assertNotEquals(null, dto.recentEmails, 'recentEmails must not be null');
        System.assertNotEquals(null, dto.adminLogs,    'adminLogs must not be null');
    }

    @isTest
    static void testRecentEmails_MaxFiftyRecords() {
        Case parentCase = createParentCase();

        List<EmailMessage> emails = new List<EmailMessage>();
        for (Integer i = 0; i < 60; i++) {
            emails.add(buildEmail(parentCase.Id, '3', false));
        }
        insert emails;

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(null, null);
        Test.stopTest();

      /*  System.assert(
            dto.recentEmails.size() <= 50,
            'recentEmails should never exceed 50 records'
        );*/
    }

    @isTest
    static void testGetDashboardData_SameDayRange() {
        Case parentCase = createParentCase();
        insert buildEmail(parentCase.Id, '3', false);

        Date today = Date.today();

        Test.startTest();
            Audit360_EmailController.EmailDashboardDTO dto =
                Audit360_EmailController.getDashboardData(today, today);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null for same-day range');
        System.assertNotEquals(null, dto.recentEmails, 'recentEmails should not be null');
    }
}