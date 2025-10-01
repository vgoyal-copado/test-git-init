@IsTest
private class StartClassicToSfpMigrationTest {
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
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            StartClassicToSfpMigration.Request request = new StartClassicToSfpMigration.Request();
            request.pipelineId = pipelineId;
            request.hasWip = false;
            request.refreshSandboxes = false;
            request.userStoryStatusValues = 'Testing in Progress';
            request.repositoryUri = 'git@github.com:test-copado/SFP-Pipeline-1.git';

            // EXERCISE
            List<StartClassicToSfpMigration.Response> responses = StartClassicToSfpMigration.execute(new List<StartClassicToSfpMigration.Request>{ request });

            // VERIFY
            copado__JobExecution__c job = [SELECT Id, copado__Source__c, copado__Destination__c, copado__Pipeline__c, copado__DataJson__c FROM copado__JobExecution__c WHERE Id=:responses[0].jobExecutionId LIMIT 1];
            Id envId = [SELECT Id FROM copado__Environment__c WHERE copado__Platform__c = 'Salesforce' AND Name = 'ProductionSf' LIMIT 1].Id;
            SfpMigrationDetails jsonData = (SfpMigrationDetails) JSON.deserialize(job.copado__DataJson__c, SfpMigrationDetails.class);

            Assert.areEqual(envId, job.copado__Source__c, 'The env Id does not match');
            Assert.areEqual(envId, job.copado__Destination__c, 'The env Id does not match');
            Assert.areEqual(pipelineId, job.copado__Pipeline__c, 'The pipeline Id does not match');
            Assert.areEqual('Testing in Progress', jsonData.userStoryStatusValues, 'The status values do not match');
            Assert.isFalse(jsonData.hasWip, 'The value of hasWip does not match');
            Assert.isFalse(jsonData.refreshSandboxes, 'The value of refreshSandboxes does not match');
        }
    }

    @IsTest
    private static void executeGetDefaultCredentialId() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            // EXERCISE
            Id credentialId = StartClassicToSfpMigration.getDefaultCredentialId(pipelineId);

            // VERIFY
            Assert.areEqual(credentialId, [SELECT Id FROM copado__Org__c WHERE copado__Default_Credential__c = TRUE AND copado__Environment__r.Name = 'ProductionSf' LIMIT 1].Id, 'The credential Id does not match');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {

            JobTemplate jobTemplate = new JobTemplate().name('Classic to Source Format Migration').version(2).apiName('Classic_to_Source_Format_Migration_2');
            new JobStep(jobTemplate).name('CreateBranch').type('Function');

            Environment devSf = new Environment('Salesforce').name('DevSf');
            Environment uatSf = new Environment('Salesforce').name('UatSf');
            Environment mainSf = new Environment('Salesforce').name('ProductionSf');

            new Credential(devSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(uatSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(mainSf).default(true).orgId(fflib_IDGenerator.generate('00D'));

            new Pipeline(new Repository().name('Test Repo').uri('git@github.com:test-copado/SFP-Pipeline-1.git'))
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