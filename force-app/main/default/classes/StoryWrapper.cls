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
}