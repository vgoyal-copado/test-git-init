@IsTest
private class PollPipelineInitializerRefreshTest {

    @TestSetup
    private static void testSetup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }


    @IsTest
    private static void executeWithRetry() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            String cronExpression = new CronCalculator().nextFireCron(2);
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;
            Map<Id, copado__Org__c> orgsById = new Map<Id, copado__Org__c>([SELECT Id FROM copado__Org__c]);
    
            // Exercise
            Test.startTest();
            System.schedule(
                'Poll for Refresh Metadata',
                cronExpression,
                new PollPipelineInitializerRefreshMetadata(orgsById.keySet(), 0, pipelineId, DateTime.now())
            );
            Test.stopTest();
    
            // Verify
            List<CronTrigger> scheduledJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Poll for Refresh Metadata%'];
            Assert.isTrue(scheduledJobs.size() > 0, 'One job should be scheduled for next iteration');
        }
    }


    @IsTest
    private static void executeWithMaxIteration() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            String cronExpression = new CronCalculator().nextFireCron(2);
            String cronTitle = 'Poll for Refresh Metadata ' + new CronCalculator().nextFireCron(5);
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;
            Map<Id, copado__Org__c> orgsById = new Map<Id, copado__Org__c>([SELECT Id FROM copado__Org__c]);
    
            // Exercise
            Test.startTest();
            System.schedule(
                'Poll for Refresh Metadata',
                cronExpression,
                new PollPipelineInitializerRefreshMetadata(orgsById.keySet(), 121, pipelineId, DateTime.now())
            );
            Test.stopTest();
    
            // Verify
            List<CronTrigger> scheduledJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :cronTitle];
            Assert.areEqual(0, scheduledJobs.size(), 'No job should be scheduled for next iteration');

            String initializationDetails = getInitializationDetails();
            PipelineInitializationDetails initializationDataWithKeys = getInitializationDataWithKeys(initializationDetails);
            Assert.areEqual(3, initializationDataWithKeys.activityLog.size(), 'The number of log entries do not match');
            Assert.areEqual(Label.CalculatingDifferences, initializationDataWithKeys.activityLog[2].title, 'The log title does not match');
            Assert.areEqual('Error', initializationDataWithKeys.activityLog[2].status, 'The log status does not match');
        }
    }


    @IsTest
    private static void executeWithNotificationCompleted() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            String cronExpression = new CronCalculator().nextFireCron(2);
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c].Id;
            Map<Id, copado__Org__c> orgsById = new Map<Id, copado__Org__c>([SELECT Id FROM copado__Org__c]);
            createCopadoNotifications(orgsById.keySet());
    
            // Exercise
            Test.startTest();
            System.schedule(
                'Poll for Refresh Metadata',
                cronExpression,
                new PollPipelineInitializerRefreshMetadata(orgsById.keySet(), 0, pipelineId, DateTime.now().addDays(-1))
            );
            Test.stopTest();
    
            // Verify
            List<copado__JobExecution__c> diffAnalysisJob = [SELECT Id, copado__status__c FROM copado__JobExecution__c WHERE copado__Template__r.copado__ApiName__c = 'SFDX_Difference_Analysis_1'];
            Assert.areEqual(2, diffAnalysisJob.size(), '2 jobs Execution should be created for Diff analysis');
            Assert.areEqual('In Progress', diffAnalysisJob[0].copado__status__c, '2 parallel job Execution should initiate for Diff analysis');
            Assert.areEqual('In Progress', diffAnalysisJob[1].copado__status__c, '2 parallel job Execution should initiate for Diff analysis');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            JobTemplate jobTemplate = new JobTemplate().name('SFDX_Difference_Analysis');
            new JobStep(jobTemplate).name('Run').type('Manual');

            Environment dev1 = new Environment().name('Dev1');
            Environment staging = new Environment().name('Staging');
            Environment preprod = new Environment().name('Preprod');
            Environment prod = new Environment().name('Production');
            new Credential(dev1).default(true).orgId('a00X');
            new Credential(staging).default(true).orgId('a00Y');
            new Credential(preprod).default(true).orgId('a00U');
            new Credential(prod).default(true).orgId('a00Z');

            PipelineInitializationDetails initializationDetails = new PipelineInitializationDetails();
            initializationDetails.initializationType = 'WIP Diff Grid';
            initializationDetails.status = 'Main initialzed';

            PipelineInitializationDetails.ActivityLog logEntry1 = new PipelineInitializationDetails.ActivityLog();
            logEntry1.status = 'Retried';
            logEntry1.title = Label.CalculatingDifferences;

            PipelineInitializationDetails.ActivityLog logEntry2 = new PipelineInitializationDetails.ActivityLog();
            logEntry2.status = 'In Progress';
            logEntry2.title = 'Test';

            initializationDetails.activityLog = new List<PipelineInitializationDetails.ActivityLog>{ logEntry1, logEntry2 };

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .initializationData(JSON.serializePretty(initializationDetails))
                .add(new Project())
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('staging').branch('dev1'))
                .add(new PipelineConnection().sourceEnvironment(staging).destinationEnvironment(preprod).destinationBranch('preprod').branch('staging'))
                .add(new PipelineConnection().sourceEnvironment(preprod).destinationEnvironment(prod).destinationBranch('main').branch('preprod'))
            .persist();
        }
    }

    private static void createCopadoNotifications(Set<Id> credentialIds) {
        List<copado__Copado_Notification__c> notifications = new List<copado__Copado_Notification__c>();

        for(Id credentialId : credentialIds) {
            notifications.add(new copado__Copado_Notification__c(
                copado__ParentId__c = credentialId,
                copado__isFinished__c = true
            ));
        }
        insert notifications;
    }

    private static String getInitializationDetails() {
        return [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c].Initialization_Data__c;
    }

    private static PipelineInitializationDetails getInitializationDataWithKeys(String initializationDetails) {
        return (PipelineInitializationDetails) JSON.deserialize(initializationDetails, PipelineInitializationDetails.class);
    }
}