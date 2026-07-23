/**
 * @description
 * Data transfer object (wrapper) used to shuttle aggregated Jira worklog
 * data from JiraService/TimeTrackerController to the Time Tracker
 * Lightning Web Component. All fields are @AuraEnabled so they can be
 * consumed directly by LWC/Aura client-side code.
 */
public with sharing class TimeTrackerResponse {

    // Ordered list of every date in the requested range, used by the UI to render the date column headers (including weekend flagging).
    @AuraEnabled
    public List<DateHeader> headers = new List<DateHeader>();

    // One entry per resource (Jira worklog author) with their hours broken down by date, sorted alphabetically by resource name.
    @AuraEnabled
    public List<ResourceWrapper> resources = new List<ResourceWrapper>();

    // Total hours logged (across all resources) for each date in the range, keyed by date string (YYYY-MM-DD). Used for column-footer totals.
    @AuraEnabled
    public Map<String, Decimal> dateTotals = new Map<String, Decimal>();

    // Sum of all hours logged by all resources across the entire date range.
    @AuraEnabled
    public Decimal grandTotal = 0;

    /**
     * @description
     * Represents a single date column in the Time Tracker grid, including
     * display metadata (day-of-month label, weekday name, weekend flag)
     * needed to render the date header row in the UI.
     */
    public class DateHeader {
        // ISO-formatted date string (YYYY-MM-DD) for this column.
        // Named "dateValue" rather than "date" because "date" is a
        // reserved identifier in Apex.
        @AuraEnabled
        public String dateValue;   // renamed from "date" — reserved identifier

        // Day-of-month portion of the date (e.g. "5", "23"), used as the
        // short display label in the column header.
        @AuraEnabled
        public String label;

        // Abbreviated weekday name (e.g. "Mon", "Tue"), used to give
        // additional context alongside the day-of-month label.
        @AuraEnabled
        public String dayName;

        // True when this date falls on a Saturday or Sunday, allowing the
        // UI to visually distinguish weekend columns.
        @AuraEnabled
        public Boolean isWeekend;

        @AuraEnabled
        public String month;
    }

    /**
     * @description
     * Represents a single resource (Jira worklog author) row in the Time
     * Tracker grid, including their total logged hours, a per-date
     * breakdown of hours, and the set of issues they have logged time
     * against.
     */
    public class ResourceWrapper {
        // Display name of the resource (Jira worklog author).
        @AuraEnabled
        public String resourceName;

        // Sum of all hours logged by this resource across the entire date range.
        @AuraEnabled
        public Decimal totalHours = 0;

        // Hours logged by this resource for each date in the range, keyed by date string (YYYY-MM-DD). Every date header in the range is guaranteed to have an entry (defaulting to 0) once fully built.
        @AuraEnabled
        public Map<String, Decimal> hoursByDate =
            new Map<String, Decimal>();

        // Map of Jira issue key -> issue summary for every issue this resource has logged time against, used to show issue context in the UI.
        // Will be useful for PUL-16
        @AuraEnabled
        public Map<String, String> issueSummaryMap =
            new Map<String, String>();
    }
}