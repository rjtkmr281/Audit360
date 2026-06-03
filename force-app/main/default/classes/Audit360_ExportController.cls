public Without Sharing class Audit360_ExportController {
	

    public class ExportRequest {
        @AuraEnabled public String  section    { get; set; }
        @AuraEnabled public String  searchTerm { get; set; }
        @AuraEnabled public Integer maxRows    { get; set; }
    }

    @AuraEnabled
    public static String generateCSV(ExportRequest request) {

        List<Map<String, Object>> rows = Audit360_QueryController.querySetupAuditForExport(
            request.section,
            request.searchTerm,
            request.maxRows
        );

        return buildCsv(rows);
    }
	@TestVisible
    private static String buildCsv(List<Map<String, Object>> rows) {
        List<String> lines = new List<String>();
        lines.add('Date,Time,Section,Action,Event (Display),User,Risk');

        for (Map<String, Object> r : rows) {
            DateTime dt = (DateTime) r.get('CreatedDate');
            String datePart = dt != null ? dt.format('yyyy-MM-dd')  : '';
            String timePart = dt != null ? dt.format('HH:mm')       : '';
            String userName = (String) r.get('createdByName');
            if (String.isBlank(userName)) {
                userName = (String) r.get('CreatedById');
            }

            lines.add(
                csvField(datePart)                    + ',' +
                csvField(timePart)                    + ',' +
                csvField((String) r.get('Section'))   + ',' +
                csvField((String) r.get('Action'))    + ',' +
                csvField((String) r.get('Display'))   + ',' +
                csvField(userName)                    + ',' +
                csvField(Audit360_RiskScorer.scoreFromMap(r))
            );
        }

        return String.join(lines, '\n');
    }

    private static String csvField(String val) {
        if (val == null) return '""';
        return '"' + val.replace('"', '""') + '"';
    }
}