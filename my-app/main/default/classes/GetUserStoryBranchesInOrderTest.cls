@IsTest
private class GetUserStoryBranchesInOrderTest {
    private static final String PROMOTION_US_MERGE_ORDER = 'promotion_us_merge_order.json';
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void executeGetUserStoryBranchesInOrderForEnvSyncBackwardPromotion() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__JobStep__c context = getJobStep('Promote Backward Environment Sync');
            copado__Promotion__c promo = [
                SELECT Id, copado__Back_Promotion__c, copado__Promotion_Method__c
                FROM copado__Promotion__c
                WHERE Id = :context.copado__JobExecution__r.copado__Promotion__c
                LIMIT 1
            ];
            promo.copado__Back_Promotion__c = true;
            promo.copado__Promotion_Method__c = 'Environment Sync';
            update promo;

            String response;
            Test.startTest();
            List<copado__User_Story__c> userStories = [SELECT Id, Name FROM copado__User_Story__c WHERE copado__User_Story_Title__c = 'US 1' LIMIT 1];
            List<copado__Org__c> credentials = [SELECT Id FROM copado__Org__c WHERE copado__Environment__r.Name = 'Dev1' LIMIT 1];
            new UserStoryCommit_t(new SnapshotCommit().credentialId(credentials[0].Id).status('Complete')).userStoryId(userStories[0].Id).persist();

            // EXERCISE
            response = new GetUserStoryBranchesInOrder().execute(context.Id);
            Test.stopTest();

            // VERIFY
            GetUserStoryBranchesInOrder.Response jsonResponse = (GetUserStoryBranchesInOrder.Response) JSON.deserialize(
                response,
                GetUserStoryBranchesInOrder.Response.class
            );

            // Order may vary based on data, assert same set of branches
            Set<String> expected = new Set<String>(getFeatureBranchesWithNames(new List<String>{ 'US 1', 'US 2' }));
            Datetime commitDate = [SELECT CreatedDate FROM copado__User_Story_Commit__c WHERE copado__User_Story__c = :userStories[0].Id LIMIT 1][0].CreatedDate;
            Date commitDateOneMonthOld = commitDate.date().addMonths(-1);
            Assert.areEqual(expected, new Set<String>(jsonResponse.userStoryBranches), 'Returned branches should match expected set.');
            Assert.areEqual(String.valueOf(commitDateOneMonthOld), jsonResponse.shallowSinceDate, 'The oldest Commit date matches');
        }
    }

    @IsTest
    private static void executeGetUserStoryBranchesInOrderForBackwardPromotion() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__JobStep__c context = getJobStep('Promote Backward');
            String response;

            // EXERCISE

            Test.startTest();
            response = new GetUserStoryBranchesInOrder().execute(context.Id);
            Test.stopTest();

            // VERIFY
            GetUserStoryBranchesInOrder.Response jsonResponse = (GetUserStoryBranchesInOrder.Response) JSON.deserialize(
                response,
                GetUserStoryBranchesInOrder.Response.class
            );
            Assert.areEqual(
                getFeatureBranchesInOrder(new List<String>{ 'US 2', 'US 1' }),
                jsonResponse.userStoryBranches,
                'The US merge order returned is incorrect'
            );
            Assert.areEqual('', jsonResponse.logError, 'No error should be returned while ordering the US.');
        }
    }

    @IsTest
    private static void executeGetUserStoryBranchesInOrderForForwardPromotions() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            copado__JobStep__c context = getJobStep('Promote Forward');
            String response;

            // EXERCISE

            Test.startTest();
            response = new GetUserStoryBranchesInOrder().execute(context.Id);
            Test.stopTest();

            // VERIFY
            GetUserStoryBranchesInOrder.Response jsonResponse = (GetUserStoryBranchesInOrder.Response) JSON.deserialize(
                response,
                GetUserStoryBranchesInOrder.Response.class
            );
            Assert.areEqual(
                getFeatureBranchesInOrder(new List<String>{ 'US 1', 'US 2' }),
                jsonResponse.userStoryBranches,
                'The US merge order returned is incorrect'
            );
            Assert.areEqual('', jsonResponse.logError, 'No error should be returned while ordering the US.');
        }
    }

    @IsTest
    private static void executeGetUserStoryBranchesInOrderWithEmptyDataJson() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            copado__JobStep__c context = getJobStep('Promote Empty DataJson');
            String exceptionMessage;

            // EXERCISE
            try {
                Test.startTest();
                new GetUserStoryBranchesInOrder().execute(context.Id);
                Test.stopTest();
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }

            // VERIFY

            Assert.isTrue(
                exceptionMessage.contains('Unable to fetch the list of user story branches for the promotion'),
                'The error: ' + exceptionMessage + ' is incorrect'
            );
        }
    }

    @IsTest
    private static void executeGetUserStoryBranchesInOrderWithNoFileOnPromotion() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            String response;
            copado__JobStep__c context = getJobStep('Promote Backward');
            List<copado__Promotion__c> forwardPromotions = [
                SELECT Id
                FROM copado__Promotion__c
                WHERE copado__Destination_Environment__c = :getEnvironment('Staging').Id
            ];
            Map<Id, copado__Promotion__c> promotionsById = new Map<Id, copado__Promotion__c>(forwardPromotions);

            List<ContentDocument> filesOnPromotion = [
                SELECT Id
                FROM ContentDocument
                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE FirstPublishLocationId IN :promotionsById.keySet())
            ];
            delete filesOnPromotion;

            // EXERCISE

            Test.startTest();
            response = new GetUserStoryBranchesInOrder().execute(context.Id);
            Test.stopTest();

            // VERIFY
            GetUserStoryBranchesInOrder.Response jsonResponse = (GetUserStoryBranchesInOrder.Response) JSON.deserialize(
                response,
                GetUserStoryBranchesInOrder.Response.class
            );
            Assert.areEqual(
                getFeatureBranchesInOrder(new List<String>{ 'US 1', 'US 2' }),
                jsonResponse.userStoryBranches,
                'The US merge order returned is incorrect'
            );
            Assert.areEqual(
                Label.BackPromotionOrderFileNotFound,
                jsonResponse.logError,
                'Error should be returned while ordering the US, if order file is not found.'
            );
        }
    }

    @IsTest
    private static void errorWhileOrderingUS() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            String response;
            copado__JobStep__c context = getJobStep('Promote Backward');
            List<copado__Promotion__c> forwardPromotions = [
                SELECT Id
                FROM copado__Promotion__c
                WHERE copado__Destination_Environment__c = :getEnvironment('Staging').Id
            ];
            List<ContentDocument> filesOnPromotion = [
                SELECT Id
                FROM ContentDocument
                WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE FirstPublishLocationId = :forwardPromotions[0].Id)
            ];
            delete filesOnPromotion;
            createInvalidFileWithMergeOrderOn(forwardPromotions[0].Id);

            // EXERCISE

            Test.startTest();
            response = new GetUserStoryBranchesInOrder().execute(context.Id);
            Test.stopTest();

            // VERIFY
            GetUserStoryBranchesInOrder.Response jsonResponse = (GetUserStoryBranchesInOrder.Response) JSON.deserialize(
                response,
                GetUserStoryBranchesInOrder.Response.class
            );
            Assert.areNotEqual('', jsonResponse.logError, 'Error should be returned in the response for invalid data.');
        }
    }

    private static void createData() {
        // Create environments in bulk
        List<Environment> environments = new List<Environment>{
            new Environment().name('Dev1').platform('SFDX'),
            new Environment().name('Dev2').platform('SFDX'),
            new Environment().name('Staging').platform('SFDX'),
            new Environment().name('Production').platform('SFDX')
        };

        // Create credentials in bulk
        List<Credential> credentials = new List<Credential>();
        for (Environment env : environments) {
            credentials.add(new Credential(env));
        }

        // Create repository and project
        Repository repository = new Repository().name('My Repo');
        Project project = new Project().name('My Project');

        // Create pipeline with all connections
        Pipeline pipeline = new Pipeline().name('My Pipeline').platform('SFDX').add(project).repository(repository).mainBranch('main');

        // Create pipeline connections in bulk
        new List<PipelineConnection>{
            new PipelineConnection()
                .sourceEnvironment(environments[0])
                .destinationEnvironment(environments[2])
                .branch('dev')
                .destinationBranch('staging')
                .pipeline(pipeline),
            new PipelineConnection()
                .sourceEnvironment(environments[1])
                .destinationEnvironment(environments[2])
                .branch('dev2')
                .destinationBranch('staging')
                .pipeline(pipeline),
            new PipelineConnection()
                .sourceEnvironment(environments[2])
                .destinationEnvironment(environments[3])
                .branch('staging')
                .destinationBranch('main')
                .pipeline(pipeline)
        };

        // Create user stories in bulk
        List<UserStory> userStories = new List<UserStory>{
            new UserStory().title('US 1').status('Ready for Testing').credential(credentials[0]).project(project),
            new UserStory().title('US 2').status('Ready for Testing').credential(credentials[0]).project(project),
            new UserStory().title('US 3').status('Ready for Testing').credential(credentials[0]).project(project)
        };
        for (UserStory us : userStories) {
            us.persist();
        }
        // Create promotions in bulk
        List<Promotion> promotions = new List<Promotion>{
            createPromotion(environments[0].id, environments[2].id, project.id),
            createPromotion(environments[0].id, environments[2].id, project.id),
            createPromotion(environments[2].id, environments[1].id, project.id)
        };

        // Set promotion statuses and execution IDs
        promotions[0].status('Completed').lastDeploymentExecutionId(fflib_IDGenerator.generate(copado__JobExecution__c.SObjectType));
        promotions[1].status('Completed').lastDeploymentExecutionId(fflib_IDGenerator.generate(copado__JobExecution__c.SObjectType));
        promotions[2].isBackPromotion(true);

        // Create promoted user stories in bulk
        List<PromotedUserStory> promotedUserStories = new List<PromotedUserStory>{
            new PromotedUserStory().userStory(userStories[0].id).promotion(promotions[0].id).status('Active'),
            new PromotedUserStory().userStory(userStories[2].Id).promotion(promotions[0].id).status('Active'),
            new PromotedUserStory().userStory(userStories[1].id).promotion(promotions[1].id).status('Active'),
            new PromotedUserStory().userStory(userStories[0].id).promotion(promotions[2].id).status('Active'),
            new PromotedUserStory().userStory(userStories[1].id).promotion(promotions[2].id).status('Active')
        };
        for (PromotedUserStory pus : promotedUserStories) {
            pus.persist();
        }

        // Create merge order files
        List<String> usMergeOrder1 = getFeatureBranchesInOrder(new List<String>{ 'US 1', 'US 3' });
        List<String> usMergeOrder2 = getFeatureBranchesInOrder(new List<String>{ 'US 2' });

        createFileWithMergeOrderOn(usMergeOrder1, Datetime.newInstance(2024, 1, 18, 11, 0, 0), promotions[0].id);
        createFileWithMergeOrderOn(usMergeOrder2, Datetime.newInstance(2024, 1, 18, 10, 0, 0), promotions[1].id);

        // Create job template and steps
        JobTemplate jobTemplate = new JobTemplate().name('SFDX Promote').type('Custom').apiName('SFDX_Promote');

        // Create job steps and executions in bulk
        List<JobStep> jobSteps = new List<JobStep>{
            new JobStep(jobTemplate).name('Promote Backward').type('Function'),
            new JobStep(jobTemplate).name('Promote Backward Environment Sync').type('Function'),
            new JobStep(jobTemplate).name('Promote Forward').type('Function'),
            new JobStep(jobTemplate).name('Promote Empty DataJson').type('Function')
        };

        List<JobExecution> jobExecutions = new List<JobExecution>{
            new JobExecution(jobTemplate)
                .source(environments[2])
                .destination(environments[1])
                .add(jobSteps[0])
                .promotion(promotions[2])
                .dataJSON(getDataJson()),
            new JobExecution(jobTemplate)
                .source(environments[2])
                .destination(environments[1])
                .add(jobSteps[1])
                .promotion(promotions[2])
                .dataJSON(getDataJsonForEnvironmentSync()),
            new JobExecution(jobTemplate)
                .source(environments[0])
                .destination(environments[2])
                .add(jobSteps[2])
                .promotion(promotions[0])
                .dataJSON(getDataJson()),
            new JobExecution(jobTemplate).source(environments[0]).destination(environments[2]).add(jobSteps[3]).promotion(promotions[0])
        };

        for (JobExecution je : jobExecutions) {
            je.persist();
        }
    }

    private static copado__Environment__c getEnvironment(String name) {
        return [SELECT Id, copado__Type__c FROM copado__Environment__c WHERE Name = :name LIMIT 1];
    }

    private static JobTemplate getJobTemplate(String name) {
        Id template = [SELECT Id FROM copado__JobTemplate__c WHERE Name = :name LIMIT 1][0].Id;
        return new JobTemplate().recordId(template);
    }

    private static Pipeline getPipeline(String name) {
        Id template = [SELECT Id FROM copado__Deployment_Flow__c WHERE Name = :name LIMIT 1][0].Id;
        return new Pipeline().recordId(template);
    }

    private static Promotion createPromotion(Id sourceEnvironmentId, Id destinationEnvironmentId, Id projectId) {
        copado__Promotion__c result = new copado__Promotion__c(
            copado__Source_Environment__c = sourceEnvironmentId,
            copado__Destination_Environment__c = destinationEnvironmentId,
            copado__Project__c = projectId
        );
        insert result;
        return new Promotion().recordId(result.Id);
    }

    private static void createInvalidFileWithMergeOrderOn(Id promotionId) {
        new ContentVersion_t()
            .title(PROMOTION_US_MERGE_ORDER)
            .pathOnClient(PROMOTION_US_MERGE_ORDER)
            .firstPublishLocationId(promotionId)
            .versionData(Blob.valueOf('invalid data'))
            .persist();
    }

    private static void createFileWithMergeOrderOn(List<String> usMergeOrder, Datetime deploymentDate, Id promotionId) {
        GetUserStoryBranchesInOrder.PromotionUSMergeOrder mergeOrder = new GetUserStoryBranchesInOrder.PromotionUSMergeOrder();
        mergeOrder.usMergeOrder = usMergeOrder;
        mergeOrder.deploymentDate = deploymentDate;

        new ContentVersion_t()
            .title(PROMOTION_US_MERGE_ORDER)
            .pathOnClient(PROMOTION_US_MERGE_ORDER)
            .firstPublishLocationId(promotionId)
            .versionData(Blob.valueOf(JSON.serialize(mergeOrder)))
            .persist();
    }

    private static List<copado__User_Story__c> getUserStory(List<String> userStoryTitles) {
        return [SELECT Id, copado__User_Story_Title__c, Name FROM copado__User_Story__c WHERE copado__User_Story_Title__c IN :userStoryTitles];
    }

    private static List<String> getFeatureBranches(List<String> userStoryTitles) {
        List<String> result = new List<String>();
        List<copado__User_Story__c> userStories = getUserStory(userStoryTitles);
        for (copado__User_Story__c userStory : userStories) {
            result.add('feature/' + userStory.Id);
        }
        return result;
    }

    private static copado__JobStep__c getJobStep(String name) {
        return [SELECT Id, copado__JobExecution__r.copado__Promotion__c FROM copado__JobStep__c WHERE Name = :name LIMIT 1];
    }

    private static String getDataJson() {
        GetUserStoryBranchesInOrder.DataJson result = new GetUserStoryBranchesInOrder.DataJson();
        result.userStoryBranches = getFeatureBranchesInOrder(new List<String>{ 'US 1', 'US 2' });
        return JSON.serialize(result);
    }

    private static String getDataJsonForEnvironmentSync() {
        GetUserStoryBranchesInOrder.DataJson result = new GetUserStoryBranchesInOrder.DataJson();
        result.userStoryBranches = getFeatureBranchesWithNames(new List<String>{ 'US 1', 'US 2' });
        return JSON.serialize(result);
    }

    private static List<String> getFeatureBranchesInOrder(List<String> userStoryTitles) {
        List<String> result = new List<String>();
        Map<String, String> featureBranchesByTitle = new Map<String, String>();
        List<copado__User_Story__c> userStories = getUserStory(userStoryTitles);
        for (copado__User_Story__c userStory : userStories) {
            featureBranchesByTitle.put(userStory.copado__User_Story_Title__c, 'feature/' + userStory.Id);
        }
        for (String userStoryTitle : userStoryTitles) {
            result.add(featureBranchesByTitle.get(userStoryTitle));
        }
        return result;
    }

    private static List<String> getFeatureBranchesWithNames(List<String> userStoryTitles) {
        List<String> result = new List<String>();
        Map<String, String> featureBranchesByTitle = new Map<String, String>();
        List<copado__User_Story__c> userStories = getUserStory(userStoryTitles);
        for (copado__User_Story__c userStory : userStories) {
            featureBranchesByTitle.put(userStory.copado__User_Story_Title__c, 'feature/' + userStory.Name);
        }
        for (String userStoryTitle : userStoryTitles) {
            result.add(featureBranchesByTitle.get(userStoryTitle));
        }
        return result;
    }

    private static copado__Promotion__c getPromotion(Id promotionId) {
        List<copado__Promotion__c> promotions = new PromotionsSelector().byIds(new Set<Id>{ promotionId });
        return promotions.isEmpty() ? null : promotions[0];
    }
}