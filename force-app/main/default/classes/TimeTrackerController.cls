/**
 * @description
 * Apex controller exposed to the Time Tracker Lightning Web Component.
 * Acts as the entry point (facade) for the UI, applying default values and
 * basic input validation before delegating the actual Jira integration work
 * to JiraService.
 */
public with sharing class TimeTrackerController {

    /**
     * @description
     * Cacheable Aura/LWC-enabled method that returns the aggregated time
     * tracker data (per-resource, per-date worklog hours) for the given
     * date range and optional project.
     *
     * Defaults are applied when dates are not supplied:
     *   - startDate defaults to 6 days before today (i.e. a 7-day window
     *     ending today).
     *   - endDate defaults to today.
     *
     * @param startDate  Start of the date range (inclusive). Defaults to
     *                   today minus 6 days if not provided.
     * @param endDate    End of the date range (inclusive). Defaults to
     *                   today if not provided.
     * @param projectKey Optional Jira project key to filter results to a
     *                   single project.
     * @return TimeTrackerResponse containing the aggregated worklog data
     *         for display in the UI.
     * @throws AuraHandledException if startDate is after endDate.
     */
    @AuraEnabled(cacheable=true)
    public static TimeTrackerResponse getTimeTrackerData(
        Date startDate,
        Date endDate,
        String projectKey
    ) {
        // Default to a trailing 7-day window (today and the 6 days before
        // it) when no start date is supplied.
        if (startDate == null) {
            startDate = Date.today().addDays(-6);
        }
        // Default to today when no end date is supplied.
        if (endDate == null) {
            endDate = Date.today();
        }
        // Guard against an invalid range before making the callout.
        if (startDate > endDate) {
            throw new AuraHandledException(
                'Start Date cannot be greater than End Date.'
            );
        }
        // Delegate to the service layer to perform the Jira callout and
        // build the aggregated response.
        return JiraService.getIssuesWithWorklogs(
            startDate,
            endDate,
            projectKey
        );
    }
}