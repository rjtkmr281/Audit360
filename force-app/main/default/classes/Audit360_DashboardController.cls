/**
 * ─────────────────────────────────────────────────────────────────────────────
 * Class Name      : Audit360DashboardController
 * Description     : Controller class used by the Audit360 dashboard component
 *                   to fetch KPI (Key Performance Indicator) metrics related
 *                   to Async Apex Jobs.
 *
 * Features:
 *  - Retrieves count of Async Apex jobs by status
 *  - Calculates overall success rate
 *  - Returns dashboard data in a key-value map format
 *
 * Used In:
 *  - Lightning Web Components (LWC)
 *  - Aura Components
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */
public Without Sharing class Audit360_DashboardController {

    /**
     * Fetches KPI data for the dashboard.
     *
     * Returns:
     *  - completed   : Total completed async jobs
     *  - failed      : Total failed async jobs
     *  - aborted     : Total aborted async jobs
     *  - queued      : Total queued async jobs
     *  - successRate : Percentage of completed jobs
     *
     * Cacheable:
     *  - Enabled for better UI performance
     *
     * @return Map<String, Object>
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getKPIData() {

        // Map used to store dashboard KPI values
        Map<String, Object> result = new Map<String, Object>();

        // Count all completed async apex jobs
        Integer completed = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE Status = 'Completed'
            LIMIT 50000
        ];

        // Count all failed async apex jobs
        Integer failed = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE Status = 'Failed'
            LIMIT 50000
        ];

        // Count all aborted async apex jobs
        Integer aborted = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE Status = 'Aborted'
            LIMIT 50000
        ];

        // Count all queued async apex jobs
        Integer queued = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE Status = 'Queued'
            LIMIT 50000
        ];

        // Variable to store calculated success percentage
        Decimal successRate = 0;

        // Total jobs considered for KPI calculation
        Integer total = completed + failed + aborted + queued;

        // Prevent division by zero before calculating success rate
        if (total > 0) {
            successRate = (Decimal.valueOf(completed) / total) * 100;
        }

        // Add all KPI values into response map
        result.put('completed', completed);
        result.put('failed', failed);
        result.put('aborted', aborted);
        result.put('queued', queued);

        // Round success rate to 1 decimal place
        result.put('successRate', successRate.setScale(1));

        // Return dashboard KPI data
        return result;
    }
}