public with sharing class TimesheetController {
    
    @AuraEnabled(cacheable=true)
    public static List<Account> getActiveClients() {
        return [
            SELECT Id, Name 
            FROM Account 
            WHERE Id IN (SELECT Client__c FROM Project__c WHERE Active__c = true) 
            ORDER BY Name
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getActiveProjects(Id clientId) {
        return [
            SELECT Id, Name 
            FROM Project__c 
            WHERE Client__c = :clientId 
            AND Active__c = true 
            ORDER BY Name
        ];
    }
    
    @AuraEnabled
    public static List<Time_Log_Entry__c> getTimeEntries(Id contactId, Date startDate, Date endDate) {
        return [
            SELECT Id, Date__c, Hours__c, Project__c, Project__r.Name 
            FROM Time_Log_Entry__c 
            WHERE Resource__c = :contactId 
            AND Date__c >= :startDate 
            AND Date__c <= :endDate
        ];
    }
    
    @AuraEnabled
    public static void saveTimeEntries(List<Time_Log_Entry__c> entriesToSave, List<Id> entriesToDelete) {
        try {
            if (entriesToDelete != null && !entriesToDelete.isEmpty()) {
                delete [SELECT Id FROM Time_Log_Entry__c WHERE Id IN :entriesToDelete];
            }
            if (entriesToSave != null && !entriesToSave.isEmpty()) {
                upsert entriesToSave;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error saving timesheet: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteProjectEntries(Id contactId, Id projectId, Date startDate, Date endDate) {
        try {
            List<Time_Log_Entry__c> entriesToDelete = [
                SELECT Id 
                FROM Time_Log_Entry__c 
                WHERE Resource__c = :contactId 
                AND Project__c = :projectId 
                AND Date__c >= :startDate 
                AND Date__c <= :endDate
            ];
            
            if (!entriesToDelete.isEmpty()) {
                delete entriesToDelete;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting project entries: ' + e.getMessage());
        }
    }
}