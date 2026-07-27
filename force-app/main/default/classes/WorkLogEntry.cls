/**
 * @description
 * Represents a single worklog entry (one hover-tooltip line item) for a
 * given User Story on a given date. Only populated for stories that are
 * enabled for detailed worklog display (see JiraService.DETAILED_WORKLOG_STORIES).
 */
public class WorkLogEntry {

    // Raw ISO timestamp from Jira (e.g. "2026-07-23T13:50:00.000+0530").
    @AuraEnabled
    public String startedRaw;

    // Human-friendly local time for display in the tooltip, e.g. "1:50 PM".
    @AuraEnabled
    public String displayTime;

    // Jira's own human-readable duration string, e.g. "1h 20m".
    @AuraEnabled
    public String timeSpentDisplay;

    // Flattened plain-text version of the ADF comment (may be blank).
    @AuraEnabled
    public String comment;
}