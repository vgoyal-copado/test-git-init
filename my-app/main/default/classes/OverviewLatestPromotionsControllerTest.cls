@IsTest
private class OverviewLatestPromotionsControllerTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String STATUS_IN_PROGRESS = 'In Progress';
    private static final String TEST_STATUS_SUCCESS = 'Success';
    private static final String TEST_STATUS_FAILED = 'Failed';
    private static final String TEST_STATUS_IN_PROGRESS = 'In Progress';
    private static Environment sourceEnv;
    private static Environment destEnv;
    private static Credential sourceCred;
    private static Credential destCred;
    private static Project proj;

    @TestSetup
    static void setupTestData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            sourceEnv = TestUtilities.createEnvironment('DEV');
            destEnv = TestUtilities.createEnvironment('QA');

            sourceCred = new Credential(sourceEnv).name('DEV Credential');
            destCred = new Credential(destEnv).name('QA Credential');

            Repository repo = TestUtilities.createRepository();
            Pipeline ppline = TestUtilities.createPipeline(repo, 'SFDX').active(true);
            new PipelineConnection(ppline, sourceEnv, destEnv);
            proj = new Project(ppline);

            proj.persist();

            createTestPromotions();
        }
    }

    private static void createTestPromotions() {
        List<Promotion> promotions = new List<Promotion>();
        
        promotions.add(new Promotion(proj.Id, sourceCred.Id, sourceEnv.Id, destCred.Id, destEnv.Id)
            .status(STATUS_COMPLETED));
        promotions.add(new Promotion(proj.Id, sourceCred.Id, sourceEnv.Id, destCred.Id, destEnv.Id)
            .status(STATUS_IN_PROGRESS));

        Result lastResultCreated;
        JobTemplate jTemplate = new JobTemplate().name(TestUtilities.generateRandomString(10));

        for(Promotion prom : promotions) {
            JobExecution jobExecution = new JobExecution(jTemplate)
                .promotion(prom)
                .status(STATUS_COMPLETED);

            JobStep jobStep = new JobStep(new JobTemplate().name(TestUtilities.generateRandomString(10)))
                .execution(jobExecution)
                .type('Function')
                .name(TestUtilities.generateRandomString(10));

            lastResultCreated = new Result(jobStep)
                .startTime(Datetime.now().addMinutes(-30))
                .endTime(Datetime.now())
                .progressStatus(TEST_STATUS_SUCCESS)
                .type('Test');
        }

        lastResultCreated.persist();
    }

    @IsTest
    static void testGetLatestPromotionsTotalRecords() {
        // SETUP
        Integer totalRecords;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;

            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;
            lwcParams.timePeriod = 'thisMonth';

            // EXERCISE
            Test.startTest();
            totalRecords = OverviewLatestPromotionsController.getLatestPromotionsTotalRecords(
                JSON.serialize(lwcParams)
            );
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(2, totalRecords, 'Should return 2 promotions');
    }

    @IsTest
    static void testGetLatestPromotions() {
        // SETUP
        List<OverviewLatestPromotionsController.PromotionWrapper> results;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;

            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;
            lwcParams.timePeriod = 'thisMonth';
            lwcParams.queryLimit = 10;
            lwcParams.offset = 0;

            // EXERCISE
            Test.startTest();
            results = OverviewLatestPromotionsController.getLatestPromotions(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(2, results.size(), 'Should return 2 promotion wrappers');
        for(OverviewLatestPromotionsController.PromotionWrapper wrapper : results) {
            Assert.isNotNull(wrapper.Id, 'The property Id should be fulfilled');
            Assert.isNotNull(wrapper.Name, 'The property Name should be fulfilled');
            Assert.isNotNull(wrapper.status, 'The property status should be fulfilled');
            Assert.isNotNull(wrapper.CreatedDate, 'The property CreatedDate should be fulfilled');
            Assert.isNotNull(wrapper.LastModifiedDate, 'The property LastModifiedDate should be fulfilled');
            Assert.isNotNull(wrapper.promotionUrl, 'The property promotionUrl should be fulfilled');
            Assert.isNotNull(wrapper.sourceEnvironmentName, 'The property sourceEnvironmentName should be fulfilled');
            Assert.isNotNull(wrapper.destinationEnvironmentName, 'The property destinationEnvironmentName should be fulfilled');
            Assert.isNotNull(wrapper.isDeployed, 'The property isDeployed should be fulfilled');
            Assert.isNotNull(wrapper.qualityResult, 'The property qualityResult should be fulfilled');
        }
    }

    @IsTest
    static void testGetLatestPromotionsWithSearch() {
        // SETUP
        List<OverviewLatestPromotionsController.PromotionWrapper> results;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;

            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;
            lwcParams.timePeriod = 'thisMonth';
            lwcParams.queryLimit = 10;
            lwcParams.offset = 0;
            lwcParams.searchTerm = 'DEV';

            // EXERCISE
            Test.startTest();
            results = OverviewLatestPromotionsController.getLatestPromotions(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.isTrue(results.size() > 0, 'Should return promotions matching search term');
    }
}