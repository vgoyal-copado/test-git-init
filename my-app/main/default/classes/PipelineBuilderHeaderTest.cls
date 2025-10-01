@IsTest
private class PipelineBuilderHeaderTest {
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void getPipelines() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Test.startTest();
            List<copado__Deployment_Flow__c> pipelines = PipelineBuilderHeader.getPipelines();
            Test.stopTest();

            // VERIFY
            Assert.areEqual(1, pipelines.size(), 'There is one SFDX pipeline');
        }
    }

    @IsTest
    private static void validateBranches() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            SObject mockResult = createResult().persist();
            PipelineBuilderHeader.mockResult = getResultObject(mockResult.Id);

            // EXERCISE
            Test.startTest();
            String resultId = PipelineBuilderHeader.validateBranches(getPipeline('SFDX').Id, new List<String>{'dev', 'test'});
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(resultId, 'Function result not found.');
        }
    }

    @IsTest
    private static void validateEnvironments() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Test.startTest();
            List<PipelineBuilderHeader.EnvironmentDetail> environmentDetail = PipelineBuilderHeader.validateEnvironments(getEnvironmentIds());
            Test.stopTest();

            // VERIFY
            Assert.areEqual(1, environmentDetail.size(), 'There are invalid environments.');
        }
    }

    @IsTest
    private static void getResult() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            SObject mockResult = createResult().persist();
            PipelineBuilderHeader.mockResult = getResultObject(mockResult.Id);
            
            // EXERCISE
            Test.startTest();
            copado__Result__c result = PipelineBuilderHeader.getResult(mockResult.Id);
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(result, 'Function result not found.');
        }
    }

    @IsTest
    private static void isFunctionRunning() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            
            SObject mockResult = createResult().persist();
            PipelineBuilderHeader.mockResult = getResultObject(mockResult.Id);

            // EXERCISE
            Test.startTest();
            Boolean result = PipelineBuilderHeader.isFunctionRunning(mockResult.Id);
            Test.stopTest();

            // VERIFY
            Assert.isTrue(result, 'Function is not running.');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Project project = new Project();

            new Repository().name('DX');
            Environment dev1 = new Environment().name('Dev1');
            Environment staging = new Environment().name('Staging');
            new Credential(dev1).default(true);
            new Credential(staging).default(true).orgId('a00Y');

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(project)
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('staging').branch('dev1'))
            .persist();
        }
    }

    private static copado__Deployment_Flow__c getPipeline(String name) {
        return [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = :name LIMIT 1][0];
    }

    private static List<Id> getEnvironmentIds() {
        List<Id> result = new List<Id>();
        for(copado__Environment__c env : [SELECT Id FROM copado__Environment__c]){
            result.add(env.Id);
        }

        return result;
    }

    private static Result createResult() {
        return new Result().type('Function').status('In Progress');
    }

    private static Result getResultObject(Id recordId) {
        return new Result().recordId(recordId);
    }
}