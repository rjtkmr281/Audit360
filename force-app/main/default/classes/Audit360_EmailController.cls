public Without Sharing class Audit360_EmailController {
	@AuraEnabled(cacheable=true)
    public static EmailDashboardDTO getDashboardData(Date startDate,Date endDate) {
        DateTime startDT;
        DateTime endDT;
        
        if (startDate == null || endDate == null) {
            startDT = DateTime.newInstance(2000, 1, 1);
            
            endDT = System.now();
        } else {
            startDT = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            
            endDT = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));
        }
        
        EmailDashboardDTO dto = new EmailDashboardDTO();
        
        dto.sentCount = 0;
        dto.readCount = 0;
        dto.repliedCount = 0;
        dto.draftCount = 0;
        dto.failedCount = 0;
        
        // ====================================
        // KPI COUNTS
        // ====================================
        
        List<AggregateResult> results = [
            SELECT Status, IsBounced, COUNT(Id) counts
            FROM EmailMessage
            WHERE CreatedDate >= :startDT AND CreatedDate <= :endDT
            GROUP BY Status, IsBounced
            LIMIT 50000
        ];
        
        for (AggregateResult ar : results) {
            String status = String.valueOf(ar.get('Status'));
            
            Boolean isBounced = (Boolean) ar.get('IsBounced');
            
            Integer countVal = (Integer) ar.get('counts');
            
            if (isBounced == true) {
                dto.failedCount += countVal;
            } else {
                if (status == '3' || status == 'Sent') {
                    dto.sentCount += countVal;                    
                } else if (status == '2' || status == 'Replied') {
                    dto.repliedCount += countVal;
                } else if (status == '1' || status == 'Read') {
                    dto.readCount += countVal;
                } else if (status == '0' || status == 'Draft') {
                    dto.draftCount += countVal;
                }
            }
        }
        
        // ====================================
        // RECENT EMAILS
        // ====================================
        
        dto.recentEmails = [
            SELECT Id, Subject, Status, CreatedDate, FromAddress, ToAddress, IsBounced
            FROM EmailMessage
            WHERE CreatedDate >= :startDT AND CreatedDate <= :endDT
            ORDER BY CreatedDate DESC
            LIMIT 50000
        ];
        
        // ====================================
        // ADMIN LOGS
        // ====================================
        
        dto.adminLogs = [
            SELECT Id, Action, Section, CreatedDate, CreatedBy.Name
            FROM SetupAuditTrail
            ORDER BY CreatedDate DESC
            LIMIT 50000
        ];
        
        return dto;
    }
    
    // ========================================
    // DTO
    // ========================================
    
    public class EmailDashboardDTO {
        @AuraEnabled
        public Integer sentCount;
        
        @AuraEnabled
        public Integer readCount;
        
        @AuraEnabled
        public Integer repliedCount;
        
        @AuraEnabled
        public Integer draftCount;
        
        @AuraEnabled
        public Integer failedCount;
        
        @AuraEnabled
        public List<EmailMessage> recentEmails;
        
        @AuraEnabled
        public List<SetupAuditTrail> adminLogs;
    }
}