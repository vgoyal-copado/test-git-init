@IsTest
private class OverviewPromotionExecutionStatsCtrlTest {
    private static final String SFDX_PROMOTE = 'SFDX Promote';
    private static final String SFDX_DEPLOY = 'SFDX Deploy';
    private static final String ERROR = 'Error';
    private static final String SUCCESSFUL = 'Successful';
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';

    private static Environment createdSourceEnv;
    private static Environment createdDestEnv;
    private static Credential createdSourceCred;
    private static Credential createdDestCred;
    private static Project createdProj;
    private static JobTemplate createdPromoteTemplate;
    private static JobTemplate createdDeployTemplate;

    @TestSetup
    static void setupTestData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            createdSourceEnv = TestUtilities.createEnvironment('DEV');
            createdDestEnv = TestUtilities.createEnvironment('QA');

            createdSourceCred = new Credential(createdSourceEnv).name('DEV Credential');
            createdDestCred = new Credential(createdDestEnv).name('QA Credential');

            Repository repo = TestUtilities.createRepository();

            Pipeline ppline = TestUtilities.createPipeline(repo, 'SFDX').active(true);

            new PipelineConnection(ppline, createdSourceEnv, createdDestEnv);

            createdProj = new Project(ppline);

            createdPromoteTemplate = new JobTemplate().name(SFDX_PROMOTE);
            createdDeployTemplate = new JobTemplate().name(SFDX_DEPLOY);

            new PipelineAction(ppline).template(createdPromoteTemplate);
            PipelineAction pipelineActionDeploy = new PipelineAction(ppline).template(createdDeployTemplate);
            pipelineActionDeploy.persist();

            createTestPromotions();
        }
    }

    private static void createTestPromotions() {
        List<Promotion> promotions = new List<Promotion>();

        for(Integer i = 0; i < 5; i++) {
            promotions.add(new Promotion(
                createdProj.Id, createdSourceCred.Id, createdSourceEnv.Id, createdDestCred.Id, createdDestEnv.Id)
            );
        }
        
        List<Result> results = new List<Result>();

        for(Promotion prom : promotions) {
            JobExecution promoteJobExecution = createJobExecution(createdPromoteTemplate, prom, null);
            JobStep promoteJobStep = createJobStep(promoteJobExecution, 'Function');
            results.add(createResult(promoteJobStep, 'sfdx_promote'));

            Deployment deployment = new Deployment().promotion(prom);
            JobExecution deployJobExecution = createJobExecution(createdDeployTemplate, prom, deployment);
            JobStep deployJobStep = createJobStep(deployJobExecution, 'Function');
            results.add(createResult(deployJobStep, 'sfdx_deploy'));
            JobStep manualDeployJobStep = createJobStep(deployJobExecution, 'Manual');
            results.add(createResult(manualDeployJobStep, 'Manual'));
        }

        results[results.size() - 1].persist();
    }

    private static JobExecution createJobExecution(JobTemplate jTemplate, Promotion prom, Deployment deployment) {
        JobExecution jExecution = new JobExecution(jTemplate.Id)
            .promotion(prom)
            .status(Math.random() >= 0.5 ? SUCCESSFUL : ERROR)
            .dataJSON('{"deploymentDryRun":false}');

        if (deployment != null) {
            jExecution.deployment(deployment);
        }

        return jExecution;
    }

    private static JobStep createJobStep(JobExecution jExecution, String type) {
        return new JobStep(new JobTemplate().name(TestUtilities.generateRandomString(10)))
                .execution(jExecution)
                .type(type)
                .name(TestUtilities.generateRandomString(10));
    }

    private static Result createResult(JobStep jStep, String type) {
        Datetime startTime = Datetime.now().addMinutes(-30);
        return new Result(jStep)
            .startTime(startTime)
            .endTime(Datetime.now())
            .type(type);
    }

    private static Id queryEnvironmentIdByName(String name) {
        List<copado__Environment__c> environments = new EnvironmentsSelector(true, true).byName(name);
        return environments.isEmpty() ? null : environments.get(0).Id;
    }

    @IsTest
    static void testGetDeploymentDetails() {
        // SETUP
        List<OverviewPromotionExecutionStatsCtrl.DeploymentDetailWrapper> results;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id sourceEnvId = queryEnvironmentIdByName('DEV');
            Id destEnvId = queryEnvironmentIdByName('QA');
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1][0].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.sourceEnvId = sourceEnvId;
            lwcParams.destEnvId = destEnvId;
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.timePeriod = '90';
            lwcParams.includeValidations = true;

            // EXERCISE
            Test.startTest();
            results = 
                OverviewPromotionExecutionStatsCtrl.getDeploymentDetails(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(5, results.size(), 'Should return 5 deployment details');
        for (OverviewPromotionExecutionStatsCtrl.DeploymentDetailWrapper deploymentWrapper : results) {
            Assert.isNotNull(deploymentWrapper, 'A null wrapper was returned');
            Assert.isNotNull(deploymentWrapper.promotionId, 'The property promotionId should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.promotionName, 'The property promotionName should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.jobId, 'The property jobId should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.jobName, 'The property jobName should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.status, 'The property status should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.errorMessage, 'The property errorMessage should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.userId, 'The property userId should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.userName, 'The property userName should be fulfilled.');
            Assert.isNotNull(deploymentWrapper.startTime, 'The property startTime should be fulfilled.');
            Assert.isTrue(deploymentWrapper.duration.contains('1h'), 'The property duration was not calculated properly.');
            Assert.areEqual(1, deploymentWrapper.manualTaskCount, 'The property manualTaskCount was not calculated properly.');
            Assert.areEqual('30m', deploymentWrapper.idleTime, 'The property idleTime was not calculated properly.');
        }
    }

    @IsTest
    static void testGetMergeDetails() {
        // SETUP
        List<OverviewPromotionExecutionStatsCtrl.MergeDetailWrapper> results;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id sourceEnvId = queryEnvironmentIdByName('DEV');
            Id destEnvId = queryEnvironmentIdByName('QA');
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1][0].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.sourceEnvId = sourceEnvId;
            lwcParams.destEnvId = destEnvId;
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.timePeriod = '7';
            lwcParams.queryLimit = 10;
            lwcParams.offset = 0;
    
            // EXERCISE
            Test.startTest();
            results = 
                OverviewPromotionExecutionStatsCtrl.getMergeDetails(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(5, results.size(), 'Should return 5 merge details');
        for (OverviewPromotionExecutionStatsCtrl.MergeDetailWrapper mergeWrapper : results) {
            Assert.isNotNull(mergeWrapper, 'A null wrapper was returned.');
            Assert.isNotNull(mergeWrapper.promotionId, 'The property promotionId should be fulfilled.');
            Assert.isNotNull(mergeWrapper.promotionName, 'The property promotionName should be fulfilled.');
            Assert.isNotNull(mergeWrapper.jobId, 'The property jobId should be fulfilled.');
            Assert.isNotNull(mergeWrapper.jobName, 'The property jobName should be fulfilled.');
            Assert.isNotNull(mergeWrapper.status, 'The property status should be fulfilled.');
            Assert.isNotNull(mergeWrapper.stepId, 'The property stepId should be fulfilled.');
            Assert.isNotNull(mergeWrapper.stepName, 'The property stepName should be fulfilled.');
            Assert.isNotNull(mergeWrapper.errorMessage, 'The property errorMessage should be fulfilled.');
            Assert.isNotNull(mergeWrapper.userId, 'The property userId should be fulfilled.');
            Assert.isNotNull(mergeWrapper.userName, 'The property userName should be fulfilled.');
            Assert.isNotNull(mergeWrapper.startTime, 'The property startTime should be fulfilled.');
            Assert.areEqual('30m', mergeWrapper.duration, 'The property duration was not calculated properly.');
        }
    }

    @IsTest
    static void testGetExecutionStats() {
        // SETUP
        List<OverviewPromotionExecutionStatsCtrl.ExecutionStatWrapper> results;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1][0].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1][0].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;
            lwcParams.timePeriod = 'thisMonth';
            lwcParams.includeValidations = true;
    
            // EXERCISE
            Test.startTest();
            results = 
                OverviewPromotionExecutionStatsCtrl.getExecutionStats(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, results.size(), 'Should return 1 execution stat.');
        
        OverviewPromotionExecutionStatsCtrl.ExecutionStatWrapper execStatWrapper = results[0];
        Assert.isNotNull(execStatWrapper, 'A null wrapper was returned.');
        Assert.isNotNull(execStatWrapper.id, 'The property Id should be fulfilled.');
        Assert.isNotNull(execStatWrapper.sourceEnvironmentName, 'The property sourceEnvironmentName should be fulfilled.');
        Assert.isNotNull(execStatWrapper.sourceEnvironmentId, 'The property sourceEnvironmentId should be fulfilled.');
        Assert.isNotNull(execStatWrapper.destinationEnvironmentName, 'The property destinationEnvironmentName should be fulfilled.');
        Assert.isNotNull(execStatWrapper.destinationEnvironmentId, 'The property destinationEnvironmentId should be fulfilled.');
        Assert.isNotNull(execStatWrapper.totalMerges, 'The property totalMerges should be fulfilled.');
        Assert.isNotNull(execStatWrapper.failedMerges, 'The property failedMerges should be fulfilled.');
        Assert.isNotNull(execStatWrapper.avgMergeTime, 'The property avgMergeTime should be fulfilled.');
        Assert.isNotNull(execStatWrapper.totalDeployments, 'The property totalDeployments should be fulfilled.');
        Assert.isNotNull(execStatWrapper.failedDeployments, 'The property failedDeployments should be fulfilled.');
        Assert.isNotNull(execStatWrapper.avgDeploymentTime, 'The property avgDeploymentTime should be fulfilled.');
    }

    @IsTest
    static void testGetExecutionStatsTotalRecords() {
        // SETUP
        Integer totalRecords;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            copado__Deployment_Flow__c pipeline = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
            copado__Project__c project = [SELECT Id FROM copado__Project__c LIMIT 1];
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipeline.Id;
            lwcParams.selectedProjectId = project.Id;
            lwcParams.timePeriod = '180';
    
            // EXERCISE
            Test.startTest();
            totalRecords = OverviewPromotionExecutionStatsCtrl.getExecutionStatsTotalRecords(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, totalRecords, 'Should return 1 execution stat.');
    }
}