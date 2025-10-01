@IsTest
private class SfpMigrationJobCallbackTest {
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void executeCallbackWithErroredJob() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            SfpMigrationDetails jsonData = new SfpMigrationDetails();
            jsonData.refreshSandboxes = false;
            jsonData.provider = 'Github';

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Error',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId,
                copado__DataJson__c = JSON.serialize(jsonData)
            );
            insert job;
            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__Type__c = 'Flow',
                copado__ConfigJson__c = '{"flowName" : "MockedFlow"}',
                Name = 'Take logs',
                copado__JobExecution__c = job.Id
            );
            insert jobStep;
            copado__Result__c result = new copado__Result__c(
                copado__Job_Type__c = 'Integration',
                copado__Status__c = 'Failed',
                copado__JobStep__c = jobStep.Id
            );
            insert result;
            jobStep.copado__Result__c = result.Id;
            update jobStep;

            // EXERCISE
            new SfpMigrationJobCallback().execute(job, 'Error');

            // VERIFY
            List<copado__Deployment_Flow__c> pipeline = [SELECT Id, copado__Active__c, copado__Block_Commits__c FROM copado__Deployment_Flow__c LIMIT 1];
            Assert.isTrue(pipeline[0].copado__Active__c, 'The pipeline is not active');
            Assert.isFalse(pipeline[0].copado__Block_Commits__c, 'The pipeline\'s commits are not blocked');
            Assert.areEqual('Salesforce', [SELECT Id, copado__Platform__c FROM copado__Environment__c LIMIT 1].copado__Platform__c, 'The environment platform does not match');
        }
    }

    @IsTest
    private static void executeCallbackWithCancelledJob() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            createSfpPipeline();
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = 'Salesforce'].Id;

            SfpMigrationDetails jsonData = new SfpMigrationDetails();
            jsonData.refreshSandboxes = false;
            jsonData.provider = 'Github';
            jsonData.gitRepositoryId = [SELECT Id FROM copado__Git_Repository__c WHERE Name = 'SFP Migrated Repo'].Id;
            jsonData.sfpPipelineId = [SELECT Id FROM copado__Deployment_Flow__c WHERE Name = 'MySourceFormatPipeline'].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Canceled',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId,
                copado__DataJson__c = JSON.serialize(jsonData)
            );
            insert job;
            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__Type__c = 'Flow',
                copado__ConfigJson__c = '{"flowName" : "MockedFlow"}',
                Name = 'Take logs',
                copado__JobExecution__c = job.Id
            );
            insert jobStep;
            copado__Result__c result = new copado__Result__c(
                copado__Job_Type__c = 'Integration',
                copado__Status__c = 'Cancelled',
                copado__JobStep__c = jobStep.Id
            );
            insert result;
            jobStep.copado__Result__c = result.Id;
            update jobStep;

            // EXERCISE
            new SfpMigrationJobCallback().execute(job, 'Canceled');

            // VERIFY
            List<copado__Deployment_Flow__c> pipeline = [SELECT Id, copado__Active__c, copado__Block_Commits__c FROM copado__Deployment_Flow__c WHERE copado__Platform__c = 'Salesforce' LIMIT 1];
            Assert.isTrue(pipeline[0].copado__Active__c, 'The pipeline is not active');
            Assert.isFalse(pipeline[0].copado__Block_Commits__c, 'The pipeline\'s commits are not blocked');
            Assert.areEqual('Salesforce', [SELECT Id, copado__Platform__c FROM copado__Environment__c LIMIT 1].copado__Platform__c, 'The environment platform does not match');
            Assert.areEqual(0, [SELECT COUNT() FROM copado__Deployment_Flow__c WHERE Name = 'MySourceFormatPipeline'], 'The SFP pipeline is not deleted.');
            Assert.areEqual(0, [SELECT COUNT() FROM copado__Git_Repository__c WHERE Name = 'SFP Migrated Repo'], 'The SFP repository is not deleted.');
        }
    }

    @IsTest
    private static void executeSuccessfulJob() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;
            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__Type__c = 'Flow',
                copado__ConfigJson__c = '{"flowName" : "MockedFlow"}',
                Name = 'Take logs',
                copado__JobExecution__c = job.Id
            );
            insert jobStep;
            copado__Result__c result = new copado__Result__c(
                copado__Job_Type__c = 'Integration',
                copado__Status__c = 'Success',
                copado__JobStep__c = jobStep.Id
            );
            insert result;
            jobStep.copado__Result__c = result.Id;
            update jobStep;

            // EXERCISE
            Test.startTest();
            new SfpMigrationJobCallback().execute(job, 'Successful');
            Test.stopTest();

            // VERIFY
            List<copado__Deployment_Flow__c> pipeline = [SELECT Id, copado__Active__c, copado__Block_Commits__c FROM copado__Deployment_Flow__c LIMIT 1];
            Assert.isFalse(pipeline[0].copado__Active__c, 'The pipeline is not active');
            Assert.isTrue(pipeline[0].copado__Block_Commits__c, 'The pipeline\'s commits are not blocked');
            Assert.areEqual('SFDX', [SELECT Id, copado__Platform__c FROM copado__Environment__c LIMIT 1].copado__Platform__c, 'The environment platform does not match');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {

            JobTemplate jobTemplate = new JobTemplate().name('SFP Migration WIP').apiName('SFP_Migration_WIP_1');
            new JobStep(jobTemplate).name('CreateBranch').type('Function');

            Environment devSf = new Environment().name('DevSf');
            Environment uatSf = new Environment().name('UatSf');
            Environment mainSf = new Environment().name('ProductionSf');

            new Credential(devSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(uatSf).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(mainSf).default(true).orgId(fflib_IDGenerator.generate('00D'));

            new Pipeline(new Repository().name('Test Repo'))
                .name('MyPipelineSf')
                .mainBranch('main')
                .platform('Salesforce')
                .active(false)
                .blockCommits(true)
                .add(new Project())
                .add(new PipelineConnection().sourceEnvironment(devSf).destinationEnvironment(uatSf).destinationBranch('uat').branch('dev'))
                .add(new PipelineConnection().sourceEnvironment(uatSf).destinationEnvironment(mainSf).destinationBranch('main').branch('uat'))
                .persist();
        }
    }

    private static void createSfpPipeline() {
        Environment dev1 = new Environment().name('Dev1');
        Environment staging = new Environment().name('Staging');
        new Credential(dev1);
        new Credential(staging);

        new Pipeline(new Repository().name('SFP Migrated Repo'))
            .name('MySourceFormatPipeline')
            .mainBranch('main')
            .platform('SFDX')
            .add(new Project())
            .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('staging').branch('dev1'))
        .persist();
    }
}