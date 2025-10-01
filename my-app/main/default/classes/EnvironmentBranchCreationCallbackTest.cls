@IsTest
private class EnvironmentBranchCreationCallbackTest {

    private static final String CREATING_BRANCHES = 'Creating branches';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void executeCallbackWithNoRelatedPipeline() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId
            );
            insert job;

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Successful');

            // VERIFY
            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
        }
    }

    @IsTest
    private static void executeCallbackWithErroredJob() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Error',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.jobIds = new List<Id>{ job.Id };
            initializationDetails.status = CREATING_BRANCHES;

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Error');

            // VERIFY
            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);

            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
            Assert.areEqual('Branch creation failed', latestInitializationDetails.status, 'The status does not match');
        }
    }

    @IsTest
    private static void executeCallbackWithCancelledJob() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Canceled',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.jobIds = new List<Id>{ job.Id };
            initializationDetails.status = CREATING_BRANCHES;

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Canceled');

            // VERIFY
            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);

            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
            Assert.areEqual('Branch creation failed', latestInitializationDetails.status, 'The status does not match');
        }
    }

    @IsTest
    private static void executeCallbackWithAllBranchesCreated() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            createSalesforcePipeline();
            Id classicPipelineId = [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c != 'Salesforce'].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.jobIds = new List<Id>{ job.Id };
            initializationDetails.status = CREATING_BRANCHES;
            initializationDetails.pendingEnvironmentIds = new List<Id>();
            initializationDetails.classicPipelineId = classicPipelineId;
            initializationDetails.userStoryStatusValues = 'Development in Progress';
            initializationDetails.currentEnvironmentId = [SELECT Id FROM copado__Environment__c WHERE Name = 'Dev' AND copado__Platform__c != 'Salesforce'].Id;

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Successful');

            // VERIFY
            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c WHERE copado__Platform__c != 'Salesforce'].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);

            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
            Assert.areEqual(Label.BranchesCreated, latestInitializationDetails.status, 'The status does not match');
            Assert.isTrue(String.isNotBlank(latestInitializationDetails.completedDate), 'There is no completion date');
        }
    }

    @IsTest
    private static void executeSuccessfulJobCallbackWithNoUserStoriesNextEnv() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            createSalesforcePipeline();
            Id classicPipelineId = [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = 'Salesforce'].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.jobIds = new List<Id>{ job.Id };
            initializationDetails.status = CREATING_BRANCHES;
            initializationDetails.pendingEnvironmentIds = getEnvironmentIds();
            initializationDetails.classicPipelineId = classicPipelineId;
            initializationDetails.userStoryStatusValues = 'Development in Progress';
            initializationDetails.currentEnvironmentId = [SELECT Id FROM copado__Environment__c WHERE Name = 'Dev' AND copado__Platform__c != 'Salesforce'].Id;

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Successful');

            // VERIFY
            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c WHERE copado__Platform__c != 'Salesforce'].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);

            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
            Assert.areEqual(CREATING_BRANCHES, latestInitializationDetails.status, 'The status does not match');
            Assert.isTrue(String.isNotBlank(latestInitializationDetails.currentEnvironmentId), 'There is no current environment Id');
        }
    }

    @IsTest
    private static void executeSuccessfulJobCallbackWithUserStoriesToCommit() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            createSalesforcePipeline();
            Id classicPipelineId = [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = 'Salesforce'].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;

            Id envId = [SELECT Id FROM copado__Environment__c WHERE Name = 'Dev' AND copado__Platform__c != 'Salesforce'].Id;

            Map<String, Object> connectionData = generateConnectionsWithIds(envId);

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.jobIds = new List<Id>{ job.Id };
            initializationDetails.status = CREATING_BRANCHES;
            initializationDetails.pendingEnvironmentIds = getEnvironmentIds();
            initializationDetails.classicPipelineId = classicPipelineId;
            initializationDetails.currentEnvironmentId = envId;
            initializationDetails.userStoryStatusValues = 'Development in Progress;Testing Blocked';
            initializationDetails.connections = (String)connectionData.get('json');

            Test.startTest();
            JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit').apiName('sfdx_commit_1');
            new JobStep(jobTemplate).name('CommitMetadat').type('Function');
            createPipelineAction(getPipelineObj('MyPipeline'), jobTemplate, 'Commit').persist();

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));
            createUsAttachmentData(envId, classicPipelineId);

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Successful');
            Test.stopTest();

            // VERIFY
            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c WHERE copado__Platform__c != 'Salesforce'].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);

            Assert.areEqual(2, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
            Assert.areEqual(CREATING_BRANCHES, latestInitializationDetails.status, 'The status does not match');
            Assert.isTrue(String.isNotBlank(latestInitializationDetails.currentEnvironmentId), 'There is no current environment Id');
            Assert.areEqual(2, [SELECT COUNT() FROM copado__User_Story__c], 'The user story count does not match.');
        }
    }

    @IsTest
    private static void executeSuccessfulJobCallbackWithConflictResolution() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            createSalesforcePipeline();
            Id classicPipelineId = [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = 'Salesforce'].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;

            Id envId = [SELECT Id FROM copado__Environment__c WHERE Name = 'Dev' AND copado__Platform__c != 'Salesforce'].Id;

            Map<String, Object> connectionData = generateConnectionsWithIds(envId);

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.jobIds = new List<Id>{ job.Id };
            initializationDetails.status = CREATING_BRANCHES;
            initializationDetails.pendingEnvironmentIds = getEnvironmentIds();
            initializationDetails.classicPipelineId = classicPipelineId;
            initializationDetails.currentEnvironmentId = envId;
            initializationDetails.userStoryStatusValues = 'Development in Progress;Testing Blocked';
            initializationDetails.connections = (String)connectionData.get('json');

            Test.startTest();
            JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit').apiName('sfdx_commit_1');
            new JobStep(jobTemplate).name('CommitMetadat').type('Function');
            createPipelineAction(getPipelineObj('MyPipeline'), jobTemplate, 'Commit').persist();

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));
            createUsAttachmentDataWithConflicts(envId, classicPipelineId);

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Successful');
            Test.stopTest();

            // VERIFY
            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c WHERE copado__Platform__c != 'Salesforce'].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);

            Assert.areEqual(2, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
            Assert.areEqual(CREATING_BRANCHES, latestInitializationDetails.status, 'The status does not match');
            Assert.isTrue(String.isNotBlank(latestInitializationDetails.currentEnvironmentId), 'There is no current environment Id');
            Assert.areEqual(2, [SELECT COUNT() FROM copado__User_Story__c], 'The user story count does not match.');
        }
    }

    @IsTest
    private static void executeSuccessfulJobCallbackWithSimpleConflictResolution() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            createSalesforcePipeline();
            Id classicPipelineId = [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = 'Salesforce'].Id;

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__Pipeline__c = pipelineId
            );
            insert job;

            Id envId = [SELECT Id FROM copado__Environment__c WHERE Name = 'Dev' AND copado__Platform__c != 'Salesforce'].Id;

            Map<String, Object> connectionData = generateConnectionsWithIds(envId);

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.jobIds = new List<Id>{ job.Id };
            initializationDetails.status = CREATING_BRANCHES;
            initializationDetails.pendingEnvironmentIds = getEnvironmentIds();
            initializationDetails.classicPipelineId = classicPipelineId;
            initializationDetails.currentEnvironmentId = envId;
            initializationDetails.userStoryStatusValues = 'Development in Progress';
            initializationDetails.connections = (String)connectionData.get('json');

            Test.startTest();
            JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit').apiName('sfdx_commit_1');
            new JobStep(jobTemplate).name('CommitMetadat').type('Function');
            createPipelineAction(getPipelineObj('MyPipeline'), jobTemplate, 'Commit').persist();

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));
            createUsAttachmentDataWithSimpleConflicts(envId, classicPipelineId);

            // EXERCISE
            new EnvironmentBranchCreationCallback().execute(job, 'Successful');
            Test.stopTest();

            // VERIFY
            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c WHERE copado__Platform__c != 'Salesforce'].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);

            Assert.areEqual(2, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');
            Assert.areEqual(CREATING_BRANCHES, latestInitializationDetails.status, 'The status does not match');
            Assert.areEqual(2, [SELECT COUNT() FROM copado__User_Story__c], 'The user story count does not match.');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {

            JobTemplate jobTemplate = new JobTemplate().name('SFP Migration WIP').apiName('SFP_Migration_WIP_1');
            new JobStep(jobTemplate).name('CreateBranch').type('Function');

            Environment dev1 = new Environment().name('Dev');
            Environment staging = new Environment().name('Staging');
            Environment uat = new Environment().name('Uat');
            new Credential(dev1).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(staging).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(uat).default(true).orgId(fflib_IDGenerator.generate('00D'));

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(new Project())
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('uat').branch('dev'))
                .add(new PipelineConnection().sourceEnvironment(staging).destinationEnvironment(uat).destinationBranch('main').branch('uat'))
                .persist();
        }
    }

    private static void createSalesforcePipeline() {
        Environment devSf = new Environment('Salesforce').name('DevSf');
        Environment uatSf = new Environment('Salesforce').name('UatSf');
        Environment mainSf = new Environment('Salesforce').name('ProductionSf');

        new Pipeline()
            .name('MyPipelineSf')
            .mainBranch('main')
            .platform('Salesforce')
            .add(new Project())
            .add(new PipelineConnection().sourceEnvironment(devSf).destinationEnvironment(uatSf).destinationBranch('uat').branch('dev'))
            .add(new PipelineConnection().sourceEnvironment(uatSf).destinationEnvironment(mainSf).destinationBranch('main').branch('uat'))
            .persist();
    }

    private static void updatePipeline(Id pipelineId, String initializationData) {
        copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c(
            Id = pipelineId,
            Initialization_Data__c = initializationData
        );

        update pipeline;
    }

    private static SfpMigrationDetails.PipelineData getInitializationDataWithKeys(String initializationDetails) {
        return (SfpMigrationDetails.PipelineData) JSON.deserialize(initializationDetails, SfpMigrationDetails.PipelineData.class);
    }

    private static Map<String, Object> generateConnectionsWithIds(Id envId) {
        Id envId1 = fflib_IDGenerator.generate('00D');
        Id envId3 = fflib_IDGenerator.generate('00D');
        Id credId1 = fflib_IDGenerator.generate('0XC');
        Id credId2 = fflib_IDGenerator.generate('0XC');
        Id credId3 = fflib_IDGenerator.generate('0XC');

        Id credId = [SELECT Id FROM copado__Org__c WHERE copado__Environment__c = :envId LIMIT 1].Id;
        
        String connectionsJson = '[' +
            '{' +
                '\"sourceEnvId\":\"' + envId1 + '\",' +
                '\"sourceDefaultCredentialId\":\"' + credId1 + '\",' +
                '\"order\":1,' +
                '\"destinationEnvId\":\"' + envId + '\",' +
                '\"destinationDefaultCredentialId\":\"' + credId + '\",' +
                '\"branchTo\":\"uat\",' +
                '\"branchFrom\":\"main\"' +
            '},' +
            '{' +
                '\"sourceEnvId\":\"' + envId + '\",' +
                '\"sourceDefaultCredentialId\":\"' + credId + '\",' +
                '\"order\":2,' +
                '\"destinationEnvId\":\"' + envId3 + '\",' +
                '\"destinationDefaultCredentialId\":\"' + credId3 + '\",' +
                '\"branchTo\":\"dev\",' +
                '\"branchFrom\":\"uat\"' +
            '}' +
        ']';
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('json', connectionsJson);
        result.put('envId1', envId1);
        result.put('envId', envId);
        result.put('envId3', envId3);
        result.put('credId1', credId1);
        result.put('credId2', credId2);
        result.put('credId3', credId3);
        
        return result;
    }

    private static List<Id> getEnvironmentIds() {
        return new List<Id>(new Map<Id, copado__Environment__c>([SELECT Id FROM copado__Environment__c LIMIT 20]).keySet());
    }

    private static void createUsAttachmentData(Id envId, Id pipelineId) {
        UserStory mockUserStory = new UserStory().status('Development in Progress').title('US1').environmentId(envId).projectId([SELECT Id FROM copado__Project__c WHERE copado__Deployment_Flow__c = :pipelineId LIMIT 1].Id);

        String gitMetadata = '[{"t":"ApexClass","n":"Moebius","b":"Test User","d":"2021-09-02","cb":"Test User","cd":"2021-09-02","r":false,"cmm":"updated","snapshotCommitId":"a0g09000001EJLHAA4"},{"t":"ApexTrigger","n":"FibonacciTrigger","b":"Test User","d":"2021-09-02","cb":"Test User","cd":"2021-09-02","r":false,"cmm":"updated","snapshotCommitId":"a0g09000001EJLHAA4"},{"t":"ApexClass","n":"BlitzClass","b":"Test User","d":"2021-08-18","cb":"Test User","cd":"2021-07-05","r":false,"cmm":"updated","snapshotCommitId":"a0g09000001EJcqAAG"}]';
        new Attachment_t().name('Git Metadata').body(Blob.valueOf(gitMetadata)).parent(mockUserStory).persist();
    }

    private static Pipeline getPipelineObj(String name) {
        return new Pipeline().recordId(getPipeline(name).Id);
    }

    private static PipelineAction createPipelineAction(Pipeline pipeline, JobTemplate template, String action) {
        return new PipelineAction(pipeline).template(template).action(action);
    }

    private static copado__Deployment_Flow__c getPipeline(String name) {
        return [SELECT Id FROM copado__Deployment_Flow__c WHERE Name = :name LIMIT 1][0];
    }

    private static void createUsAttachmentDataWithConflicts(Id envId, Id pipelineId) {
        UserStory mockUserStory = new UserStory()
            .status('Development in Progress')
            .title('US1 - Conflict Test')
            .environmentId(envId)
            .projectId([SELECT Id FROM copado__Project__c WHERE copado__Deployment_Flow__c = :pipelineId LIMIT 1].Id);
    
        String gitMetadata = '[' +
            '{"t":"CustomField","n":"Case.Case_Test__c","b":"Sakshi","d":"2025-08-19","cb":"Sakshi","cd":"2025-08-19","r":false,"cmm":"updated","snapshotCommitId":"a0pWz000000l2hVIAQ"},' +
            '{"t":"CustomObject","n":"Case","r":false,"cmm":"updated"},' +
            '{"t":"Profile","n":"Identity User","b":"salesforce.com","d":"2025-08-19","cb":"salesforce.com","cd":"2025-08-19","r":false,"cmm":"updated","snapshotCommitId":"a0pWz000000l2mLIAQ"},' +
            '{"t":"ApexClass","n":"TestClass","b":"Test User","d":"2025-08-19","cb":"Test User","cd":"2025-08-19","r":false,"cmm":"updated","snapshotCommitId":"a0g09000001EJLHAA4"}' +
        ']';
        new Attachment_t().name('Git MetaData').body(Blob.valueOf(gitMetadata)).parent(mockUserStory);
    
        String deleteMetadata = '[{"t":"CustomField","n":"Case.Case_Test__c","b":"Sakshi","d":"2025-08-19","cb":"Sakshi","cd":"2025-08-19","r":false,"cmm":"deleted","snapshotCommitId":"a0pWz000000l2hVIAQ"}]';
        new Attachment_t().name('Delete MetaData').body(Blob.valueOf(deleteMetadata)).parent(mockUserStory);
    
        String fullProfileMetadata = '[{"t":"Profile","n":"Identity User"}]';
        new Attachment_t().name('Full Profile Permission Set').body(Blob.valueOf(fullProfileMetadata)).parent(mockUserStory).persist();
    }

    private static void createUsAttachmentDataWithSimpleConflicts(Id envId, Id pipelineId) {
        UserStory mockUserStory = new UserStory()
            .status('Development in Progress')
            .title('US1 - Simple Conflict Test')
            .environmentId(envId)
            .projectId([SELECT Id FROM copado__Project__c WHERE copado__Deployment_Flow__c = :pipelineId LIMIT 1].Id);
    
        String gitMetadata = '[' +
            '{"t":"Profile","n":"Identity User","b":"salesforce.com","d":"2025-08-19","cb":"salesforce.com","cd":"2025-08-19","r":false,"cmm":"updated","snapshotCommitId":"a0pWz000000l2mLIAQ"},' +
            '{"t":"CustomObject","n":"Account","r":false,"cmm":"updated"},' +
            '{"t":"ApexClass","n":"AccountHelper","b":"Test User","d":"2025-08-19","cb":"Test User","cd":"2025-08-19","r":false,"cmm":"updated","snapshotCommitId":"a0g09000001EJLHAA4"}' +
        ']';
        new Attachment_t().name('Git MetaData').body(Blob.valueOf(gitMetadata)).parent(mockUserStory);
    
        // Full Profile Permission Set (will conflict with Profile in Git MetaData - Full should win)
        String fullProfileMetadata = '[{"t":"Profile","n":"Identity User"}]';
        new Attachment_t().name('Full Profile Permission Set').body(Blob.valueOf(fullProfileMetadata)).parent(mockUserStory).persist();
    }
}