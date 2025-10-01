@IsTest
private class CreateGitRepositoryTest {
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
            copado__Deployment_Flow__c pipeline = [SELECT Id, copado__Git_Repository__c, copado__Git_Repository__r.copado__Git_Provider__c FROM copado__Deployment_Flow__c];

            CreateGitRepository.Request request = new CreateGitRepository.Request();
            request.classicPipelineId = pipeline.Id;
            request.repositoryUri = 'git@github.com:test-copado/SFP-Pipeline-2.git';

            // EXERCISE
            CreateGitRepository.execute(new List<CreateGitRepository.Request>{ request });

            // VERIFY
            List<copado__Git_Repository__c> repositories = [SELECT Id, Name, copado__URI__c, copado__Git_Provider__c FROM copado__Git_Repository__c
            WHERE Id != :pipeline.copado__Git_Repository__c];

            Assert.areEqual(1, repositories.size(), 'The number of new git repos do not match');
            Assert.areEqual('SFP - Test Repo', repositories[0].Name, 'The name of new git repo does not match');
            Assert.areEqual(pipeline.copado__Git_Repository__r.copado__Git_Provider__c, repositories[0].copado__Git_Provider__c, 'The git provider of new git repo does not match');
            Assert.areEqual(request.repositoryUri, repositories[0].copado__URI__c, 'The URI of new git repo does not match');
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