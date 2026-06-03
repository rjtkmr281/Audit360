/**
 * ─────────────────────────────────────────────────────────────────────────────
 * Class Name      : Audit360RiskScorer
 * Description     : Utility class responsible for calculating risk levels
 *                   for Salesforce Setup Audit Trail events.
 *
 * Features:
 *  - Evaluates audit events based on action type
 *  - Identifies high-risk administrative activities
 *  - Detects suspicious activity outside business hours
 *  - Supports deployment window validation
 *  - Returns standardized risk levels
 *
 * Risk Levels:
 *  - LOW
 *  - MEDIUM
 *  - HIGH
 *  - CRITICAL
 *
 * Used In:
 *  - Audit dashboards
 *  - Compliance monitoring
 *  - Security analytics
 *  - Alert generation
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */
public without sharing class Audit360_RiskScorer {

    /**
     * Enum representing supported risk levels.
     */
    public enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    /**
     * Calculates risk level directly from
     * SetupAuditTrail record.
     */
    public static RiskLevel score(
        SetupAuditTrail evt
    ) {

        return score(
            evt.Action,
            evt.Section,
            evt.CreatedDate,
            evt.CreatedById
        );
    }

    /**
     * Main risk scoring engine.
     *
     * Evaluates action details and returns
     * an appropriate risk level.
     */
    public static RiskLevel score(

        String action,
        String section,
        DateTime createdDate,
        String createdById
    ) {

        // Default LOW risk if action is empty
        if (String.isBlank(action)) {
            return RiskLevel.LOW;
        }

        // Convert action to lowercase for comparison
        String a = action.toLowerCase();

        /**
         * Critical Risk Conditions
         */

        // Super admin login detected
        if (a.contains('suorgadminlogin')) {
            return RiskLevel.CRITICAL;
        }

        // Email access control changes
        if (a.contains('sendemailaccesscontrol')) {
            return RiskLevel.CRITICAL;
        }

        // User deactivation detected
        if (a.contains('deactivateduser')) {
            return RiskLevel.CRITICAL;
        }

        /**
         * Permission Set Unassignment
         */
        if (a.contains('permsetunassign')) {
            return checkBulkUnassign(a);
        }

        /**
         * DKIM key rotation validation
         */
        if (a.contains('dkimrotation')) {
            return checkDkimExpiry(a);
        }

        /**
         * Email Administration changes
         */
        if (
            a.contains('emailadmin') ||
            section == 'Email Admin'
        ) {

            return RiskLevel.HIGH;
        }

        /**
         * Interaction Definition Version deactivation
         */
        if (
            a.contains('deactivatedinteractiondefversion')
        ) {

            return isOutsideDeployWindow(createdDate)
                ? RiskLevel.MEDIUM
                : RiskLevel.LOW;
        }

        /**
         * Validation Rule activation/deactivation
         */
        if (a.contains('changedvalidationactive')) {
            return RiskLevel.MEDIUM;
        }

        /**
         * Permission Set Assignment
         */
        if (a.contains('permsetassign')) {
            return RiskLevel.LOW;
        }

        /**
         * Public Group membership changes
         */
        if (a.contains('groupmembership')) {
            return RiskLevel.LOW;
        }

        /**
         * Any activity outside business hours
         */
        if (isOutsideBusinessHours(createdDate)) {
            return RiskLevel.MEDIUM;
        }

        // Default fallback risk
        return RiskLevel.LOW;
    }

    /**
     * Evaluates bulk permission set unassignment.
     */
    private static RiskLevel checkBulkUnassign(
        String action
    ) {

        // Large-scale permission removal
        if (
            action.contains('bulk') ||
            action.contains('20+')
        ) {

            return RiskLevel.CRITICAL;
        }

        return RiskLevel.HIGH;
    }

    /**
     * Evaluates DKIM rotation activity.
     */
    private static RiskLevel checkDkimExpiry(
        String action
    ) {

        return RiskLevel.HIGH;
    }

    /**
     * Checks whether activity occurred
     * outside standard business hours.
     *
     * Business Hours:
     *  - 9 AM to 5 PM GMT
     */
    private static Boolean isOutsideBusinessHours(
        DateTime dt
    ) {

        if (dt == null) {
            return false;
        }

        Integer hour = dt.hourGmt();

        return hour < 9 || hour >= 17;
    }

    /**
     * Validates whether deployment activity
     * occurred outside approved deployment window.
     *
     * Deployment Window:
     *  - 6 PM to 10 PM GMT
     *  - Weekdays only
     */
    private static Boolean isOutsideDeployWindow(
        DateTime dt
    ) {

        if (dt == null) {
            return true;
        }

        // Day of week
        Integer dow =
            Integer.valueOf(dt.format('u'));

        Integer hour = dt.hourGmt();

        // Weekend detection
        Boolean isWeekend =
            (dow == 6 || dow == 7);

        // Approved deployment time
        Boolean isDeployWindow =
            (hour >= 18 && hour < 22);

        return isWeekend || !isDeployWindow;
    }

    /**
     * Returns risk level as formatted string.
     */
    public static String scoreAsString(
        SetupAuditTrail evt
    ) {

        return toTitleCase(score(evt));
    }

    /**
     * Calculates risk level from generic map data.
     *
     * Useful for dynamic JSON/deserialized records.
     */
    public static String scoreFromMap(
        Map<String, Object> row
    ) {

        String action =
            (String) row.get('Action');

        String section =
            (String) row.get('Section');

        DateTime createdDate =
            (DateTime) row.get('CreatedDate');

        String createdById =
            (String) row.get('CreatedById');

        return toTitleCase(

            score(
                action,
                section,
                createdDate,
                createdById
            )
        );
    }

    /**
     * Converts enum value into
     * user-friendly title case format.
     *
     * Example:
     *  HIGH -> High
     */
    private static String toTitleCase(
        RiskLevel level
    ) {

        String s = level.name();

        return
            s.substring(0, 1) +
            s.substring(1).toLowerCase();
    }
}