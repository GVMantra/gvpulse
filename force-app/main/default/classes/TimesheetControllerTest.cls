@isTest
private class TimesheetControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // 1. Create Test Contact (Resource)
        Contact testContact = new Contact(
            FirstName = 'John',
        LastName = 'Doe',
        Email = 'john.doe@example.com'
            );
        insert testContact;
        
        // 2. Create Test Client (Account)
        Account testClient = new Account(
            Name = 'Acme Corp'
            );
        insert testClient;
        
        // 3. Create Test Project
        Project__c testProject = new Project__c(
            Name = 'Cloud Migration',
        Client__c = testClient.Id,
        Active__c = true
            );
        insert testProject;
        
        // 4. Create Initial Time Log Entry
        Time_Log_Entry__c testEntry = new Time_Log_Entry__c(
            Resource__c = testContact.Id,
        Project__c = testProject.Id,
        Date__c = Date.today(),
        Hours__c = 8.0
            );
        insert testEntry;
    }
    
    @isTest
    static void testGetActiveClients() {
        Test.startTest();
        List<Account> clients = TimesheetController.getActiveClients();
        Test.stopTest();
        
        Assert.areEqual(1, clients.size(), 'Expected 1 active client.');
        Assert.areEqual('Acme Corp', clients[0].Name, 'Client name should match setup data.');
    }
    
    @isTest
    static void testGetActiveProjects() {
        Account client = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<Project__c> projects = TimesheetController.getActiveProjects(client.Id);
        Test.stopTest();
        
        Assert.areEqual(1, projects.size(), 'Expected 1 active project for client.');
        Assert.areEqual('Cloud Migration', projects[0].Name, 'Project name should match setup data.');
    }
    
    @isTest
    static void testGetTimeEntries() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        Date startDate = Date.today().toStartOfMonth();
        Date endDate = Date.today().addDays(30);
        
        Test.startTest();
        List<Time_Log_Entry__c> entries = TimesheetController.getTimeEntries(contact.Id, startDate, endDate);
        Test.stopTest();
        
        Assert.areEqual(1, entries.size(), 'Expected 1 time log entry in date range.');
        Assert.areEqual(8.0, entries[0].Hours__c, 'Logged hours should match setup data.');
    }
    
    @isTest
    static void testSaveTimeEntriesInsertAndUpdate() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Time_Log_Entry__c existingEntry = [SELECT Id, Hours__c FROM Time_Log_Entry__c LIMIT 1];
        
        // Modify existing entry (Update)
        existingEntry.Hours__c = 6.0;
        
        // Create new entry (Insert)
        Time_Log_Entry__c newEntry = new Time_Log_Entry__c(
            Resource__c = contact.Id,
        Project__c = project.Id,
        Date__c = Date.today().addDays(1),
        Hours__c = 4.0
            );
        
        List<Time_Log_Entry__c> entriesToSave = new List<Time_Log_Entry__c>{ existingEntry, newEntry };
        List<Id> entriesToDelete = new List<Id>();
        
        Test.startTest();
        TimesheetController.saveTimeEntries(entriesToSave, entriesToDelete);
        Test.stopTest();
        
        List<Time_Log_Entry__c> results = [SELECT Id, Hours__c FROM Time_Log_Entry__c WHERE Resource__c = :contact.Id];
        Assert.areEqual(2, results.size(), 'Expected 2 records after insert and update.');
    }
    
    @isTest
    static void testSaveTimeEntriesDelete() {
        Time_Log_Entry__c existingEntry = [SELECT Id FROM Time_Log_Entry__c LIMIT 1];
        
        List<Time_Log_Entry__c> entriesToSave = new List<Time_Log_Entry__c>();
        List<Id> entriesToDelete = new List<Id>{ existingEntry.Id };
        
        Test.startTest();
        TimesheetController.saveTimeEntries(entriesToSave, entriesToDelete);
        Test.stopTest();
        
        List<Time_Log_Entry__c> results = [SELECT Id FROM Time_Log_Entry__c WHERE Id = :existingEntry.Id];
        Assert.areEqual(0, results.size(), 'Entry should be deleted from the database.');
    }
    
    @isTest
    static void testDeleteProjectEntries() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Date startDate = Date.today().toStartOfMonth();
        Date endDate = Date.today().addDays(30);
        
        Test.startTest();
        TimesheetController.deleteProjectEntries(contact.Id, project.Id, startDate, endDate);
        Test.stopTest();
        
        List<Time_Log_Entry__c> results = [
            SELECT Id 
            FROM Time_Log_Entry__c 
            WHERE Resource__c = :contact.Id 
            AND Project__c = :project.Id
        ];
        Assert.areEqual(0, results.size(), 'All project entries in date range should be deleted.');
    }
    
    @isTest
    static void testSaveTimeEntriesExceptionHandling() {
        // Pass an invalid record with a missing required field to force an DML Exception
        Time_Log_Entry__c invalidRecord = new Time_Log_Entry__c(
            Date__c = Date.today()
            // Missing Resource__c and Project__c required fields
        );
        
        List<Time_Log_Entry__c> entriesToSave = new List<Time_Log_Entry__c>{ invalidRecord };
        
        Test.startTest();
        try {
            TimesheetController.saveTimeEntries(entriesToSave, null);
            Assert.fail('An AuraHandledException should have been thrown.');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null.');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteProjectEntriesExceptionHandling() {
        Test.startTest();
        try {
            // Passing null IDs triggers query exception in method body
            TimesheetController.deleteProjectEntries(null, null, null, null);
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null.');
        }
        Test.stopTest();
    }
}