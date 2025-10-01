@IsTest
private class CloneClassicPipelineToSourceFormatTest {

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void executeRequest() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;
            Id repoId = [SELECT Id FROM copado__Git_Repository__c].Id;

            SfpMigrationDetails jsonData = new SfpMigrationDetails();
            jsonData.refreshSandboxes = false;
            jsonData.classicGitRepositoryId = repoId;
            jsonData.provider = 'Github';

            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__DataJson__c = JSON.serialize(jsonData)
            );
            insert job;

            CloneClassicPipelineToSourceFormat.Request request = new CloneClassicPipelineToSourceFormat.Request();
            request.pipelineId = pipelineId;
            request.repositoryId = repoId;
            request.jobExecutionId = [SELECT Id FROM copado__JobExecution__c].Id;

            // EXERCISE
            List<CloneClassicPipelineToSourceFormat.Response> responses = CloneClassicPipelineToSourceFormat.execute(new List<CloneClassicPipelineToSourceFormat.Request>{ request });

            // VERIFY
            Assert.areEqual(responses[0].sfpPipelineId, [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = 'SFDX'].Id, 'There is no SFDX pipeline created');
            Assert.areEqual(0, [SELECT COUNT() FROM copado__Environment__c WHERE copado__Platform__c = 'Salesforce'], 'The count of Salesforce environments does not match');
            Assert.areEqual(1, [SELECT COUNT() FROM copado__Project__c WHERE copado__Deployment_Flow__c = :responses[0].sfpPipelineId], 'The count of projects does not match');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {

            JobTemplate jobTemplate = new JobTemplate().name('SFP Migration WIP').apiName('SFP_Migration_WIP_1');
            new JobStep(jobTemplate).name('CreateBranch').type('Function');

            Environment devSf = new Environment('Salesforce').name('DevSf');
            Environment uatSf = new Environment('Salesforce').name('UatSf');
            Environment mainSf = new Environment('Salesforce').name('ProductionSf');

            new Credential(devSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(uatSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(mainSf).default(true).orgId(fflib_IDGenerator.generate('00D'));

            new Pipeline(new Repository().name('Test Repo'))
                .name('MyPipelineSf')
                .mainBranch('main')
                .platform('Salesforce')
                .add(new Project())
                .add(new PipelineConnection().sourceEnvironment(devSf).destinationEnvironment(uatSf).destinationBranch('uat').branch('dev'))
                .add(new PipelineConnection().sourceEnvironment(uatSf).destinationEnvironment(mainSf).destinationBranch('main').branch('uat'))
                .persist();
        }
    }
}