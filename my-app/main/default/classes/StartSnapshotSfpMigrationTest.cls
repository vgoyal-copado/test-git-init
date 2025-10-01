@IsTest
private class StartSnapshotSfpMigrationTest {
    private static final String MFP_TO_SFP_SNAPSHOT_MIGRATION = 'MFP_to_SFP_Snapshot_Migration_1';
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createJobTemplateAndStep();
            createTestData();
        }
    }
    
    @IsTest
    private static void testExecuteWithValidRequest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            StartSnapshotSfpMigration.Request request = createValidRequest();
            
            // EXERCISE
            Test.startTest();
            List<StartSnapshotSfpMigration.Response> responses = StartSnapshotSfpMigration.execute(new List<StartSnapshotSfpMigration.Request>{ request });
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(responses, 'Response should not be null');
            Assert.areEqual(1, responses.size(), 'Should return one response');
            Assert.isNotNull(responses[0].jobExecutionId, 'Job execution ID should not be null');
            
            // Verify job execution details
            copado__JobExecution__c jobExecution = [
                SELECT Id, copado__DataJson__c, copado__Template__r.copado__ApiName__c, 
                       copado__ParentId__c, copado__Pipeline__c, copado__Source__c
                FROM copado__JobExecution__c 
                WHERE Id = :responses[0].jobExecutionId
            ];
            
            Assert.areEqual(MFP_TO_SFP_SNAPSHOT_MIGRATION, jobExecution.copado__Template__r.copado__ApiName__c, 
                           'Template API name should match');
            Assert.areEqual(request.snapshotId, jobExecution.copado__ParentId__c, 
                           'Parent ID should match snapshot ID');
            Assert.areEqual(request.pipelineId, jobExecution.copado__Pipeline__c, 
                           'Pipeline ID should match');
            Assert.areEqual(request.sourceOrgId, jobExecution.copado__Source__c, 
                           'Source ID should match source org ID');
            
            // Verify data JSON contains expected values
            String dataJson = jobExecution.copado__DataJson__c;
            Assert.isTrue(dataJson.contains('"message":"Snapshot commit"'), 
                         'DataJson should contain message');
            Assert.isTrue(dataJson.contains('"snapshotInformation":"' + request.snapshotInformation + '"'), 
                         'DataJson should contain snapshot information');
        }
    }
    
    @IsTest
    private static void testExecuteWithInvalidJobTemplate() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            // Update the job template to have a different API name
            copado__JobTemplate__c template = [
                SELECT Id, copado__ApiName__c 
                FROM copado__JobTemplate__c 
                WHERE copado__ApiName__c = :MFP_TO_SFP_SNAPSHOT_MIGRATION
                LIMIT 1
            ];
            template.copado__ApiName__c = 'Different_API_Name';
            update template;
            
            StartSnapshotSfpMigration.Request request = createValidRequest();
            String exceptionMessage;
            
            // EXERCISE
            Test.startTest();
            try {
                StartSnapshotSfpMigration.execute(new List<StartSnapshotSfpMigration.Request>{ request });
            } catch (Exception error) {
                exceptionMessage = error.getMessage();
            }
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(exceptionMessage, 'An exception should be thrown');
            Assert.isTrue(
                exceptionMessage.contains('Template not found') || 
                exceptionMessage.contains('Invalid template'),
                'The error should indicate template issue: ' + exceptionMessage
            );
        }
    }
    
    @IsTest
    private static void testExecuteWithNullRequest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            StartSnapshotSfpMigration.Request nullRequest = null;
            String exceptionMessage;
            
            // EXERCISE
            Test.startTest();
            try {
                StartSnapshotSfpMigration.execute(new List<StartSnapshotSfpMigration.Request>{ nullRequest });
            } catch (Exception error) {
                exceptionMessage = error.getMessage();
            }
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(exceptionMessage, 'An exception should be thrown');
            Assert.isTrue(
                exceptionMessage.contains('null') || 
                exceptionMessage.contains('Attempt to de-reference'),
                'The error should indicate null reference issue: ' + exceptionMessage
            );
        }
    }
    
    @IsTest
    private static void testExecuteWithMissingRequiredFields() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            StartSnapshotSfpMigration.Request incompleteRequest = new StartSnapshotSfpMigration.Request();
            // Only set some fields, leaving others null
            incompleteRequest.snapshotId = fflib_IDGenerator.generate('a0x');
            incompleteRequest.pipelineId = fflib_IDGenerator.generate('a0y');
            // Missing sourceOrgId, branch, and snapshotInformation
            
            String exceptionMessage;
            
            // EXERCISE
            Test.startTest();
            try {
                StartSnapshotSfpMigration.execute(new List<StartSnapshotSfpMigration.Request>{ incompleteRequest });
            } catch (Exception error) {
                exceptionMessage = error.getMessage();
            }
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(exceptionMessage, 'An exception should be thrown for missing required fields');
        }
    }
    
    @IsTest
    private static void testExecuteWithInvalidIds() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            StartSnapshotSfpMigration.Request requestWithInvalidIds = new StartSnapshotSfpMigration.Request();
            // Set invalid IDs
            requestWithInvalidIds.sourceOrgId = fflib_IDGenerator.generate('001'); // Invalid org ID
            requestWithInvalidIds.snapshotId = fflib_IDGenerator.generate('a0x');
            requestWithInvalidIds.pipelineId = fflib_IDGenerator.generate('a0y');
            requestWithInvalidIds.branch = 'main';
            requestWithInvalidIds.snapshotInformation = 'Test snapshot info';
            
            String exceptionMessage;
            
            // EXERCISE
            Test.startTest();
            try {
                StartSnapshotSfpMigration.execute(new List<StartSnapshotSfpMigration.Request>{ requestWithInvalidIds });
            } catch (Exception error) {
                exceptionMessage = error.getMessage();
            }
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(exceptionMessage, 'An exception should be thrown for invalid IDs');
        }
    }
    
    @IsTest
    private static void testJobExecutionSelector() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            StartSnapshotSfpMigration.Request request = createValidRequest();
            
            // EXERCISE
            Test.startTest();
            List<StartSnapshotSfpMigration.Response> responses = 
                StartSnapshotSfpMigration.execute(new List<StartSnapshotSfpMigration.Request>{ request });
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(responses, 'Response should not be null');
            Assert.areEqual(1, responses.size(), 'Should return one response');
            
            // Test the JobExecutionsSelector by retrieving the job execution
            Id jobExecutionId = responses[0].jobExecutionId;
            List<copado__JobExecution__c> jobExecutions = new JobExecutionsSelector().byIds(new Set<Id>{ jobExecutionId });
            
            Assert.areEqual(1, jobExecutions.size(), 'Should retrieve one job execution');
            Assert.areEqual(jobExecutionId, jobExecutions[0].Id, 'Job execution ID should match');
        }
    }
    
    // HELPER METHODS
    
    private static void createJobTemplateAndStep() {
        JobTemplate jobTemplate = new JobTemplate().name('MFP to SFP Snapshot Migration').apiName(MFP_TO_SFP_SNAPSHOT_MIGRATION).type('Custom');
        new JobStep(jobTemplate).name('Migrate Snapshot').type('Function').persist();
    }
    
    private static void createTestData() {
        Environment devSf = new Environment().name('Dev env').indexBackPromotionMetadata(true);
        Credential cred = new Credential(devSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
        Repository repo = new Repository().name('My Repo');
        new Pipeline().name('Test Pipeline');

        new Snapshot(cred, null, repo).persist();
    }
    
    private static StartSnapshotSfpMigration.Request createValidRequest() {
        // Get IDs from test data
        Id sourceOrgId = [SELECT Id FROM copado__Environment__c LIMIT 1].Id;
        Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
        Id snapshotId = [SELECT Id FROM copado__Git_Backup__c LIMIT 1].Id;
        
        StartSnapshotSfpMigration.Request request = new StartSnapshotSfpMigration.Request();
        request.sourceOrgId = sourceOrgId;
        request.snapshotId = snapshotId;
        request.pipelineId = pipelineId;
        request.branch = 'main';
        request.snapshotInformation = 'Test snapshot information with metadata details';
        
        return request;
    }
}