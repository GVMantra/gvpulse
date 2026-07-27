/**
 * @description
 * Data transfer object (wrapper) used to shuttle aggregated Jira worklog
 * data for the "Time Log By User Story" screen.
 *
 * This response contains one row per Jira User Story with hours logged
 * per day, along with overall date totals and grand total.
 */
public with sharing class StoryTimeTrackerResponse {

    // Ordered list of every date in the requested range, used by the UI
    // to render the date column headers.
    @AuraEnabled
    public List<DateHeader> headers = new List<DateHeader>();

    // One entry per Jira User Story.
    @AuraEnabled
    public List<StoryWrapper> stories = new List<StoryWrapper>();

    // Total hours logged across all user stories for each date.
    @AuraEnabled
    public Map<String, Decimal> dateTotals = new Map<String, Decimal>();

    // Total hours logged across all user stories and dates.
    @AuraEnabled
    public Decimal grandTotal = 0;

    /**
     * @description
     * Represents a single date column in the matrix.
     */
    public class DateHeader {

        // ISO date (YYYY-MM-DD)
        @AuraEnabled
        public String dateValue;

        // Day of month
        @AuraEnabled
        public String label;

        // Day name (Mon, Tue, etc.)
        @AuraEnabled
        public String dayName;

        // Indicates whether the date falls on a weekend.
        @AuraEnabled
        public Boolean isWeekend;

        // Month abbreviation (Jan, Feb, etc.)
        @AuraEnabled
        public String month;
    }
}