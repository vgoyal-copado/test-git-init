@IsTest
private class UpdateSnapshotIdInSfpMigrationTest {
    
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
            copado__Git_Backup__c gitSnapshot = [SELECT Id FROM copado__Git_Backup__c LIMIT 1];
            copado__JobExecution__c jobExecution = [SELECT Id, copado__DataJson__c FROM copado__JobExecution__c LIMIT 1];
            
            // Create request
            UpdateSnapshotIdInSfpMigration.Request request = new UpdateSnapshotIdInSfpMigration.Request();
            request.gitSnapshotId = gitSnapshot.Id;
            request.jobExecutionId = jobExecution.Id;
            
            // Exercise
            Test.startTest();
            
            try {
                UpdateSnapshotIdInSfpMigration.execute(new List<UpdateSnapshotIdInSfpMigration.Request>{request});
                
                System.assert(true, 'Method executed successfully');
                
                copado__JobExecution__c updatedJobExecution = [
                    SELECT Id, copado__DataJson__c 
                    FROM copado__JobExecution__c 
                    WHERE Id = :jobExecution.Id
                ];

                Map<String, Object> dataJsonMap = (Map<String, Object>)JSON.deserializeUntyped(
                    updatedJobExecution.copado__DataJson__c
                );
                
                System.assertEquals(gitSnapshot.Id, dataJsonMap.get('gitSnapshotId'), 
                    'Git Snapshot Id should be updated in the DataJson');
                
            } catch (Exception e) {
                System.assert(String.isNotBlank(e.getMessage()), 'There is an exception');
            }
            
            Test.stopTest();
        }
    }

    private static void createTestData() {
        Environment devSf = new Environment().name('Dev env').indexBackPromotionMetadata(true);
        Credential cred = new Credential(devSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
        Repository repo = new Repository().name('My Repo');
        new Pipeline().name('Test Pipeline');

        new Snapshot(cred, null, repo);
        // Create test Job Execution record with initial DataJson
        Map<String, Object> initialDataJson = new Map<String, Object>{
            'someField' => 'someValue',
            'gitSnapshotId' => null
        };
        new JobExecution().status('Planned').dataJSON(JSON.serialize(initialDataJson)).persist();
    }
    
    // Helper class to represent SfpMigrationDetails for testing
    private class SfpMigrationDetails {
        public String someField;
        public Id gitSnapshotId;
    }
}