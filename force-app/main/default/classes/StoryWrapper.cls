public class StoryWrapper {

    @AuraEnabled
    public String issueKey;

    @AuraEnabled
    public String issueSummary;

    @AuraEnabled
    public Decimal totalHours = 0;

    @AuraEnabled
    public Map<String, Decimal> hoursByDate =
        new Map<String, Decimal>();

    // NEW: true only for stories enabled for the hover-detail feature.
    @AuraEnabled
    public Boolean supportsWorklogDetail = false;

    // NEW: per-date list of individual worklog entries, populated only
    // when supportsWorklogDetail is true.
    @AuraEnabled
    public Map<String, List<WorklogEntry>> entriesByDate =
        new Map<String, List<WorklogEntry>>();
}