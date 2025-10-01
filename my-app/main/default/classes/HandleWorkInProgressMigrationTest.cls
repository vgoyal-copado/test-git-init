@IsTest
private class HandleWorkInProgressMigrationTest {

    private static final String CREATING_BRANCHES = 'Creating branches';

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

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.status = CREATING_BRANCHES;

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            HandleWorkInProgressMigration.CommitOtherInformation commitJson = new HandleWorkInProgressMigration.CommitOtherInformation();
            commitJson.pipelineId = pipelineId;
            HandleWorkInProgressMigration.JsonInformation jobJsonData = new HandleWorkInProgressMigration.JsonInformation();
            jobJsonData.jsonInformation = JSON.serialize(commitJson);
            String jobJson = JSON.serialize(jobJsonData);

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Error',
                copado__Template__c = templateId,
                copado__DataJson__c = jobJson
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
            new HandleWorkInProgressMigration().execute(job, 'Error');

            // VERIFY
            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');

            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);
            Assert.areEqual('Commit failed', latestInitializationDetails.status, 'The status does not match');
        }
    }

    @IsTest
    private static void executeCallbackWithCancelledJob() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.status = CREATING_BRANCHES;

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            HandleWorkInProgressMigration.CommitOtherInformation commitJson = new HandleWorkInProgressMigration.CommitOtherInformation();
            commitJson.pipelineId = pipelineId;
            HandleWorkInProgressMigration.JsonInformation jobJsonData = new HandleWorkInProgressMigration.JsonInformation();
            jobJsonData.jsonInformation = JSON.serialize(commitJson);
            String jobJson = JSON.serialize(jobJsonData);

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Canceled',
                copado__Template__c = templateId,
                copado__DataJson__c = jobJson
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
            new HandleWorkInProgressMigration().execute(job, 'Canceled');

            // VERIFY
            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'No new job execution is created');

            String pipelineInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
            SfpMigrationDetails.PipelineData latestInitializationDetails = getInitializationDataWithKeys(pipelineInitializationDetails);
            Assert.areEqual('Commit failed', latestInitializationDetails.status, 'The status does not match');
        }
    }

    @IsTest
    private static void executeSuccessfulJobAndAllBranchesCreated() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.status = Label.BranchesCreated;
            initializationDetails.completedDate = System.now().toString();
            initializationDetails.pendingEnvironmentIds = new List<Id>();

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            HandleWorkInProgressMigration.CommitOtherInformation commitJson = new HandleWorkInProgressMigration.CommitOtherInformation();
            commitJson.pipelineId = pipelineId;
            HandleWorkInProgressMigration.JsonInformation jobJsonData = new HandleWorkInProgressMigration.JsonInformation();
            jobJsonData.jsonInformation = JSON.serialize(commitJson);
            String jobJson = JSON.serialize(jobJsonData);

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__DataJson__c = jobJson
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
            new HandleWorkInProgressMigration().execute(job, 'Successful');
            Test.stopTest();

            // VERIFY
            String finalInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;

            SfpMigrationDetails.PipelineData initializationDataWithKeys = getInitializationDataWithKeys(finalInitializationDetails);
            Assert.areEqual(0, initializationDataWithKeys.pendingEnvironmentIds.size(), 'The pending environment list size does not match');
            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'Job Execution count does not match');
        }
    }

    @IsTest
    private static void executeSuccessfulJobAndCreateNextBranch() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;
            List<Id> environmentIds = getEnvironmentIds();

            Map<String, Object> connectionData = generateConnectionsWithIds();

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.pendingEnvironmentIds = environmentIds;
            initializationDetails.connections = (String)connectionData.get('json');
            initializationDetails.currentEnvironmentId = (Id)connectionData.get('envId2');

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            HandleWorkInProgressMigration.CommitOtherInformation commitJson = new HandleWorkInProgressMigration.CommitOtherInformation();
            commitJson.pipelineId = pipelineId;
            HandleWorkInProgressMigration.JsonInformation jobJsonData = new HandleWorkInProgressMigration.JsonInformation();
            jobJsonData.jsonInformation = JSON.serialize(commitJson);
            String jobJson = JSON.serialize(jobJsonData);

            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__DataJson__c = jobJson
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
            new HandleWorkInProgressMigration().execute(job, 'Successful');
            Test.stopTest();

            // VERIFY
            String finalInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
            Id latestJobId = [SELECT Id FROM copado__JobExecution__c WHERE Id != :job.Id].Id;

            SfpMigrationDetails.PipelineData initializationDataWithKeys = getInitializationDataWithKeys(finalInitializationDetails);
            Assert.areEqual(2, [SELECT COUNT() FROM copado__JobExecution__c], 'Job Execution count does not match');
            Assert.isTrue(initializationDataWithKeys.jobIds.contains(latestJobId), 'The job Id is not present on the pipeline data');
        }
    }

    @IsTest
    private static void executeCreateBranches() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = [SELECT Id, Name FROM copado__Deployment_Flow__c LIMIT 1];
            
            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.pendingEnvironmentIds = getEnvironmentIds();
            Map<String, Object> connectionData = generateConnectionsWithIds();
            initializationDetails.connections = (String)connectionData.get('json');
            initializationDetails.currentEnvironmentId = (Id)connectionData.get('envId2');
            
            updatePipeline(pipeline.Id, JSON.serializePretty(initializationDetails));

            // EXERCISE
            Test.startTest();
            new HandleWorkInProgressMigration().createBranches(pipeline);
            Test.stopTest();

            // VERIFY
            String finalInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
            Id latestJobId = [SELECT Id FROM copado__JobExecution__c].Id;

            SfpMigrationDetails.PipelineData initializationDataWithKeys = getInitializationDataWithKeys(finalInitializationDetails);
            Assert.areEqual(1, [SELECT COUNT() FROM copado__JobExecution__c], 'Job Execution count does not match');
            Assert.isTrue(initializationDataWithKeys.jobIds.contains(latestJobId), 'The job Id is not present on the pipeline data');
        }
    }

    @IsTest
    private static void executeInitialActionFromFlow() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            SfpMigrationDetails jobData = new SfpMigrationDetails();
            Map<String, Object> connectionData = generateConnectionsWithIds();
            jobData.connections = (String)connectionData.get('json');
            jobData.sfpPipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;
           
            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(
                copado__Status__c = 'Successful',
                copado__Template__c = templateId,
                copado__DataJson__c = JSON.serialize(jobData)
            );
            insert job;

            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;

            SfpMigrationDetails.PipelineData initializationDetails = new SfpMigrationDetails.PipelineData();
            initializationDetails.connections = (String)connectionData.get('json');

            updatePipeline(pipelineId, JSON.serializePretty(initializationDetails));

            // EXERCISE
            Test.startTest();
            HandleWorkInProgressMigration.Request request = new HandleWorkInProgressMigration.Request();
            request.jobExecutionId = job.Id;
            HandleWorkInProgressMigration.execute(new List<HandleWorkInProgressMigration.Request>{ request });
            Test.stopTest();

            // VERIFY
            String finalInitializationDetails = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
            Id latestJobId = [SELECT Id FROM copado__JobExecution__c WHERE Id != :job.Id].Id;

            SfpMigrationDetails.PipelineData initializationDataWithKeys = getInitializationDataWithKeys(finalInitializationDetails);
            Assert.areEqual(2, [SELECT COUNT() FROM copado__JobExecution__c], 'Job Execution count does not match');
            Assert.isTrue(initializationDataWithKeys.jobIds.contains(latestJobId), 'The job Id is not present on the pipeline data');
            Assert.areEqual(CREATING_BRANCHES, initializationDataWithKeys.status, 'The status does not match');
            Assert.areEqual(job.Id, initializationDataWithKeys.migrationJobId, 'The job Id does not match');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {

            JobTemplate jobTemplate = new JobTemplate().name('SFP Migration WIP').apiName('SFP_Migration_WIP_1');
            new JobStep(jobTemplate).name('CreateBranch').type('Function');

            Environment dev1 = new Environment().name('Dev1');
            Environment staging = new Environment().name('Staging');

            new Credential(dev1).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(staging).default(true).orgId(fflib_IDGenerator.generate('00D'));

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(new Project())
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('main').branch('dev1'))
            .persist();
        }
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

    private static List<Id> getEnvironmentIds() {
        return new List<Id>(new Map<Id, copado__Environment__c>([SELECT Id FROM copado__Environment__c LIMIT 20]).keySet());
    }

    private static Map<String, Object> generateConnectionsWithIds() {
        Id envId1 = fflib_IDGenerator.generate('00D');
        Id envId2 = fflib_IDGenerator.generate('00D');
        Id envId3 = fflib_IDGenerator.generate('00D');
        Id credId1 = fflib_IDGenerator.generate('0XC');
        Id credId2 = fflib_IDGenerator.generate('0XC');
        Id credId3 = fflib_IDGenerator.generate('0XC');
        
        String connectionsJson = '[' +
            '{' +
                '\"sourceEnvId\":\"' + envId1 + '\",' +
                '\"sourceDefaultCredentialId\":\"' + credId1 + '\",' +
                '\"order\":1,' +
                '\"destinationEnvId\":\"' + envId2 + '\",' +
                '\"destinationDefaultCredentialId\":\"' + credId2 + '\",' +
                '\"branchTo\":\"uat\",' +
                '\"branchFrom\":\"main\"' +
            '},' +
            '{' +
                '\"sourceEnvId\":\"' + envId2 + '\",' +
                '\"sourceDefaultCredentialId\":\"' + credId2 + '\",' +
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
        result.put('envId2', envId2);
        result.put('envId3', envId3);
        result.put('credId1', credId1);
        result.put('credId2', credId2);
        result.put('credId3', credId3);
        
        return result;
    }
}