@IsTest
private class MigrationGitInitializerTest {
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Git_Repository__c repo = new copado__Git_Repository__c(
                Name = 'Test Repository',
                copado__URI__c = 'https://github.com/example/repo.git'
            );
            insert repo;
        }
    }
    
    @IsTest
    private static void testSuccessfulExecution() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            // Create job template similar to InitializeSFDXProjectTest
            JobTemplate jobTemplate = new JobTemplate()
                .name('SFDX Git Initialization')
                .apiName('SFDX Git Initialization_1')
                .type('Custom');
            new JobStep(jobTemplate).name('Initialize Git with SFDX Project').type('Function').persist();
            update new copado__JobTemplate__c(
                Id = jobTemplate.id, 
                copado__ApiName__c = 'SFDX Git Initialization_1'
            );
            
            // Create request
            MigrationGitInitializer.Request request = new MigrationGitInitializer.Request();
            request.gitRepositoryId = [SELECT Id FROM copado__Git_Repository__c LIMIT 1].Id;
            request.gitRepositoryURI = 'https://github.com/example/repo.git';
            request.branch = 'main';
            
            // EXERCISE
            Test.startTest();
            List<MigrationGitInitializer.Response> responses = MigrationGitInitializer.execute(
                new List<MigrationGitInitializer.Request>{request}
            );
            Test.stopTest();
            
            // VERIFY
            Assert.areEqual(1, responses.size(), 'Should return one response');
            Assert.isNotNull(responses[0].initializeJobId, 'Job ID should not be null');
            
            // Verify job execution was created
            copado__JobExecution__c jobExecution = [
                SELECT Id, copado__Status__c, copado__Template__r.Name
                FROM copado__JobExecution__c
                WHERE Id = :responses[0].initializeJobId
            ];
            
            Assert.areEqual('SFDX Git Initialization', jobExecution.copado__Template__r.Name, 
                           'Job should use the correct template');
        }
    }
    
    @IsTest
    private static void testExceptionHandling() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            // Create request with invalid repository ID to trigger exception
            MigrationGitInitializer.Request request = new MigrationGitInitializer.Request();
            request.gitRepositoryId = null; // This will cause an exception
            request.gitRepositoryURI = 'https://github.com/example/repo.git';
            request.branch = 'main';
            
            // EXERCISE
            Test.startTest();
            String exceptionMessage;
            try {
                MigrationGitInitializer.execute(new List<MigrationGitInitializer.Request>{request});
                Assert.fail('Should have thrown an exception');
            } catch (Exception e) {
                exceptionMessage = e.getMessage();
            }
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(exceptionMessage, 'An exception message should be present');
        }
    }
}