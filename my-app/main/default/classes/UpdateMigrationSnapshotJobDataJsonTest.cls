@IsTest
private class UpdateMigrationSnapshotJobDataJsonTest {
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createTestData();
        }
    }
    
    @IsTest
    private static void testExecuteSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup test data
            copado__JobExecution__c jobExecution = [SELECT Id, copado__DataJson__c FROM copado__JobExecution__c LIMIT 1];
            ContentVersion contentVersion = [SELECT Id FROM ContentVersion LIMIT 1];
            
            // Create metadata refresh result JSON
            UpdateMigrationSnapshotJobDataJson.RefreshMetadataJson refreshResult = 
                new UpdateMigrationSnapshotJobDataJson.RefreshMetadataJson();
            refreshResult.contentVersionId = contentVersion.Id;
            String metadataRefreshResultJson = JSON.serialize(refreshResult);
            
            // Create request
            UpdateMigrationSnapshotJobDataJson.Request request = new UpdateMigrationSnapshotJobDataJson.Request();
            request.jobExecutionId = jobExecution.Id;
            request.metadataRefreshResult = metadataRefreshResultJson;
            
            // Exercise
            Test.startTest();
            
            try {
                UpdateMigrationSnapshotJobDataJson.execute(new List<UpdateMigrationSnapshotJobDataJson.Request>{request});
                
                System.assert(true, 'Method executed successfully');
                
                // Verify the update
                copado__JobExecution__c updatedJobExecution = [
                    SELECT Id, copado__DataJson__c 
                    FROM copado__JobExecution__c 
                    WHERE Id = :jobExecution.Id
                ];

                UpdateMigrationSnapshotJobDataJson.SnapshotMigrationJson updatedDataJson = 
                    (UpdateMigrationSnapshotJobDataJson.SnapshotMigrationJson) JSON.deserialize(
                        updatedJobExecution.copado__DataJson__c, 
                        UpdateMigrationSnapshotJobDataJson.SnapshotMigrationJson.class
                    );
                
                System.assertNotEquals(null, updatedDataJson.metadataRefreshResult, 
                    'Metadata refresh result should be populated');
                System.assertEquals(contentVersion.Id, updatedDataJson.metadataRefreshResult.contentVersionId, 
                    'Content Version Id should be updated in the DataJson');
                
            } catch (Exception e) {
                System.assert(false, 'Unexpected exception: ' + e.getMessage());
            }
            
            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testExecuteWithInvalidJobExecutionId() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Create request with invalid job execution ID
            UpdateMigrationSnapshotJobDataJson.Request request = new UpdateMigrationSnapshotJobDataJson.Request();
            request.jobExecutionId = fflib_IDGenerator.generate(copado__JobExecution__c.SObjectType);
            request.metadataRefreshResult = '{"contentVersionId":"' + fflib_IDGenerator.generate(ContentVersion.SObjectType) + '"}';
            
            Test.startTest();
            
            try {
                UpdateMigrationSnapshotJobDataJson.execute(new List<UpdateMigrationSnapshotJobDataJson.Request>{request});
                System.assert(false, 'Should have thrown an exception for invalid job execution ID');
            } catch (Exception e) {
                System.assert(String.isNotBlank(e.getMessage()), 'Exception should have a message');
                System.assert(e instanceof ApplicationException, 'Should throw ApplicationException');
            }
            
            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testExecuteWithInvalidJson() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__JobExecution__c jobExecution = [SELECT Id, copado__DataJson__c FROM copado__JobExecution__c LIMIT 1];
            
            // Create request with invalid JSON
            UpdateMigrationSnapshotJobDataJson.Request request = new UpdateMigrationSnapshotJobDataJson.Request();
            request.jobExecutionId = jobExecution.Id;
            request.metadataRefreshResult = 'invalid json string';
            
            Test.startTest();
            
            try {
                UpdateMigrationSnapshotJobDataJson.execute(new List<UpdateMigrationSnapshotJobDataJson.Request>{request});
                System.assert(false, 'Should have thrown an exception for invalid JSON');
            } catch (Exception e) {
                System.assert(String.isNotBlank(e.getMessage()), 'Exception should have a message');
                System.assert(e instanceof ApplicationException, 'Should throw ApplicationException');
            }
            
            Test.stopTest();
        }
    }

    private static void createTestData() {
        // Create Environment and Credential
        Environment devSf = new Environment().name('Dev env').indexBackPromotionMetadata(true);
        Credential cred = new Credential(devSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
        Repository repo = new Repository().name('My Repo');
        new Pipeline().name('Test Pipeline');

        new Snapshot(cred, null, repo);
        
        // Create ContentVersion for testing
        ContentVersion cv = new ContentVersion(
            Title = 'Test Metadata File',
            PathOnClient = 'metadata.json',
            VersionData = Blob.valueOf('{"test": "data"}'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Create test Job Execution record with initial SnapshotMigrationJson structure
        UpdateMigrationSnapshotJobDataJson.SnapshotMigrationJson initialDataJson = 
            new UpdateMigrationSnapshotJobDataJson.SnapshotMigrationJson();
        initialDataJson.snapshotInformation = 'Test snapshot information';
        initialDataJson.message = 'Initial message';
        initialDataJson.metadataRefreshResult = null;
        
        new JobExecution()
            .status('Planned')
            .dataJSON(JSON.serialize(initialDataJson))
            .persist();
    }
}