@isTest
private class CheckSfpMigratedPipelineWipStatusTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Deployment_Flow__c testPipeline = new copado__Deployment_Flow__c(Name = 'Test Pipeline', copado__Active__c = true);
            insert testPipeline;
        }
    }

    @isTest
    static void testExecuteWithCompletedStatus() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Get the test pipeline
            copado__Deployment_Flow__c pipeline = getPipeline();

            // Create pipeline data with completed status
            SfpMigrationDetails.PipelineData pipelineData = new SfpMigrationDetails.PipelineData();
            pipelineData.status = Label.BranchesCreated;

            // Update pipeline with initialization data
            pipeline.Initialization_Data__c = JSON.serialize(pipelineData);
            update pipeline;

            Test.startTest();
            // Create request
            CheckSfpMigratedPipelineWipStatus.Request request = new CheckSfpMigratedPipelineWipStatus.Request();
            request.sfpPipelineId = pipeline.Id;

            // Execute the method
            List<CheckSfpMigratedPipelineWipStatus.Response> responses = CheckSfpMigratedPipelineWipStatus.execute(
                new List<CheckSfpMigratedPipelineWipStatus.Request>{ request }
            );
            Test.stopTest();

            // Verify results - Response returns String values, not Boolean
            System.assertEquals(1, responses.size(), 'Should return one response');
            System.assertEquals('true', responses[0].isCompleted, 'Status should be completed');
            System.assertEquals('false', responses[0].isFailed, 'Status should not be failed');
        }
    }

    @isTest
    static void testExecuteWithFailedStatus() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Get the test pipeline
            copado__Deployment_Flow__c pipeline = getPipeline();

            // Create pipeline data with failed status
            SfpMigrationDetails.PipelineData pipelineData = new SfpMigrationDetails.PipelineData();
            pipelineData.status = Label.BranchesCreationFailed;

            // Update pipeline with initialization data
            pipeline.Initialization_Data__c = JSON.serialize(pipelineData);
            update pipeline;

            Test.startTest();
            // Create request
            CheckSfpMigratedPipelineWipStatus.Request request = new CheckSfpMigratedPipelineWipStatus.Request();
            request.sfpPipelineId = pipeline.Id;

            // Execute the method
            List<CheckSfpMigratedPipelineWipStatus.Response> responses = CheckSfpMigratedPipelineWipStatus.execute(
                new List<CheckSfpMigratedPipelineWipStatus.Request>{ request }
            );
            Test.stopTest();

            // Verify results - Response returns String values, not Boolean
            System.assertEquals(1, responses.size(), 'Should return one response');
            System.assertEquals('false', responses[0].isCompleted, 'Status should not be completed');
            System.assertEquals('true', responses[0].isFailed, 'Status should be failed');
        }
    }

    @isTest
    static void testExecuteWithInProgressStatus() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Get the test pipeline
            copado__Deployment_Flow__c pipeline = getPipeline();

            // Create pipeline data with in-progress status
            SfpMigrationDetails.PipelineData pipelineData = new SfpMigrationDetails.PipelineData();
            pipelineData.status = 'In Progress'; // Some other status

            // Update pipeline with initialization data
            pipeline.Initialization_Data__c = JSON.serialize(pipelineData);
            update pipeline;

            Test.startTest();
            // Create request
            CheckSfpMigratedPipelineWipStatus.Request request = new CheckSfpMigratedPipelineWipStatus.Request();
            request.sfpPipelineId = pipeline.Id;

            // Execute the method
            List<CheckSfpMigratedPipelineWipStatus.Response> responses = CheckSfpMigratedPipelineWipStatus.execute(
                new List<CheckSfpMigratedPipelineWipStatus.Request>{ request }
            );
            Test.stopTest();

            // Verify results - Response returns String values, not Boolean
            System.assertEquals(1, responses.size(), 'Should return one response');
            System.assertEquals('false', responses[0].isCompleted, 'Status should not be completed');
            System.assertEquals('false', responses[0].isFailed, 'Status should not be failed');
        }
    }

    @isTest
    static void testExecuteWithEmptyInitializationData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Get the test pipeline
            copado__Deployment_Flow__c pipeline = getPipeline();

            // Pipeline has empty initialization data
            pipeline.Initialization_Data__c = '';
            update pipeline;

            Test.startTest();
            // Create request
            CheckSfpMigratedPipelineWipStatus.Request request = new CheckSfpMigratedPipelineWipStatus.Request();
            request.sfpPipelineId = pipeline.Id;

            // Execute the method - should handle empty data gracefully
            List<CheckSfpMigratedPipelineWipStatus.Response> responses = CheckSfpMigratedPipelineWipStatus.execute(
                new List<CheckSfpMigratedPipelineWipStatus.Request>{ request }
            );
            Test.stopTest();

            // Verify results - should return default false values
            System.assertEquals(1, responses.size(), 'Should return one response');
            System.assertEquals('false', responses[0].isCompleted, 'Status should not be completed');
            System.assertEquals('false', responses[0].isFailed, 'Status should not be failed');
        }
    }

    @isTest
    static void testExecuteWithNullInitializationData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Get the test pipeline
            copado__Deployment_Flow__c pipeline = getPipeline();

            // Pipeline has null initialization data
            pipeline.Initialization_Data__c = null;
            update pipeline;

            Test.startTest();
            // Create request
            CheckSfpMigratedPipelineWipStatus.Request request = new CheckSfpMigratedPipelineWipStatus.Request();
            request.sfpPipelineId = pipeline.Id;

            // Execute the method - should handle null data gracefully
            List<CheckSfpMigratedPipelineWipStatus.Response> responses = CheckSfpMigratedPipelineWipStatus.execute(
                new List<CheckSfpMigratedPipelineWipStatus.Request>{ request }
            );
            Test.stopTest();

            // Verify results - should return default false values
            System.assertEquals(1, responses.size(), 'Should return one response');
            System.assertEquals('false', responses[0].isCompleted, 'Status should not be completed');
            System.assertEquals('false', responses[0].isFailed, 'Status should not be failed');
        }
    }

    @isTest
    static void testExecuteWithInvalidPipelineId() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Test.startTest();
            // Create request with non-existent pipeline ID
            CheckSfpMigratedPipelineWipStatus.Request request = new CheckSfpMigratedPipelineWipStatus.Request();
            request.sfpPipelineId = getFakeId(copado__Deployment_Flow__c.SObjectType);

            // Execute the method and expect exception
            try {
                CheckSfpMigratedPipelineWipStatus.execute(new List<CheckSfpMigratedPipelineWipStatus.Request>{ request });
                System.assert(false, 'Should have thrown an exception');
            } catch (Exception e) {
                // Verify exception was thrown with correct message
                System.assert(e.getMessage().contains(Label.NoPipelineFound), 'Exception should contain NoPipelineFound message: ' + e.getMessage());
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testExecuteWithInvalidJsonData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Get the test pipeline
            copado__Deployment_Flow__c pipeline = getPipeline();

            // Pipeline has invalid JSON data
            pipeline.Initialization_Data__c = '{"invalid": json}';
            update pipeline;

            Test.startTest();
            // Create request
            CheckSfpMigratedPipelineWipStatus.Request request = new CheckSfpMigratedPipelineWipStatus.Request();
            request.sfpPipelineId = pipeline.Id;

            // Execute the method and expect exception due to invalid JSON
            try {
                CheckSfpMigratedPipelineWipStatus.execute(new List<CheckSfpMigratedPipelineWipStatus.Request>{ request });
                System.assert(false, 'Should have thrown an exception for invalid JSON');
            } catch (Exception e) {
                // Verify exception was thrown
                System.assert(e instanceof ApplicationException, 'Should throw ApplicationException: ' + e.getTypeName());
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testExecuteWithMultipleRequests() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Get the test pipeline
            copado__Deployment_Flow__c pipeline = getPipeline();

            // Create pipeline data with completed status
            SfpMigrationDetails.PipelineData pipelineData = new SfpMigrationDetails.PipelineData();
            pipelineData.status = Label.BranchesCreated;

            // Update pipeline with initialization data
            pipeline.Initialization_Data__c = JSON.serialize(pipelineData);
            update pipeline;

            Test.startTest();
            // Create multiple requests (though implementation only processes first one)
            CheckSfpMigratedPipelineWipStatus.Request request1 = new CheckSfpMigratedPipelineWipStatus.Request();
            request1.sfpPipelineId = pipeline.Id;

            CheckSfpMigratedPipelineWipStatus.Request request2 = new CheckSfpMigratedPipelineWipStatus.Request();
            request2.sfpPipelineId = pipeline.Id;

            // Execute the method
            List<CheckSfpMigratedPipelineWipStatus.Response> responses = CheckSfpMigratedPipelineWipStatus.execute(
                new List<CheckSfpMigratedPipelineWipStatus.Request>{ request1, request2 }
            );
            Test.stopTest();

            // Verify results - should still return only one response
            System.assertEquals(1, responses.size(), 'Should return one response even with multiple requests');
            System.assertEquals('true', responses[0].isCompleted, 'Status should be completed');
            System.assertEquals('false', responses[0].isFailed, 'Status should not be failed');
        }
    }

    // Helper method to generate fake IDs for testing
    private static Id getFakeId(Schema.SObjectType sot) {
        String keyPrefix = sot.getDescribe().getKeyPrefix();
        String fakeId = keyPrefix + '0'.repeat(12);
        return Id.valueOf(fakeId);
    }

    private static copado__Deployment_Flow__c getPipeline() {
        return [SELECT Id FROM copado__Deployment_Flow__c WHERE Name = 'Test Pipeline' LIMIT 1];
    }
}