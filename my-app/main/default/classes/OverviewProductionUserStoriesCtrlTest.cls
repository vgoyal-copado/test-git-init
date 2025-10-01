@IsTest
private class OverviewProductionUserStoriesCtrlTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    private static final String USER_STORY_TITLE = 'Test User Story';
    private static final String OK = 'ok';

    @TestSetup
    static void setupTestData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Environment devEnv = TestUtilities.createEnvironment('DEV');
            Environment prodEnv = TestUtilities.createEnvironment('PROD');
            
            Repository repo = TestUtilities.createRepository();
            Pipeline pipeline = TestUtilities.createPipeline(repo, 'Test Pipeline').active(true);
            
            new PipelineConnection(pipeline, devEnv, prodEnv);
            
            Project project = new Project(pipeline);
            Release release = new Release().project(project);
            
            new UserStory()
                .title(USER_STORY_TITLE)
                .project(project)
                .release(release)
                .environment(prodEnv)
                .excludeFromCBM(false)
                .stopIndexingMetadata(false);
                
            new UserStory()
                .title('Excluded ' + USER_STORY_TITLE)
                .project(project)
                .release(release)
                .environment(prodEnv)
                .excludeFromCBM(true)
                .stopIndexingMetadata(true)
                .persist();
        }
    }

    @IsTest
    static void testGetProductionUserStoryCount() {
        // SETUP
        Integer storyCount;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;
            Id releaseId = [SELECT Id FROM copado__Release__c LIMIT 1].Id;

            // EXERCISE
            Test.startTest();
            storyCount = OverviewProductionUserStoriesController.getProductionUserStoryCount(
                pipelineId, 
                projectId, 
                releaseId
            );
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, storyCount, 'Should return count of non-excluded user stories');
    }

    @IsTest
    static void testGetProductionUserStoryCountNullPipeline() {
        // SETUP
        Integer storyCount;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // EXERCISE
            Test.startTest();
            storyCount = OverviewProductionUserStoriesController.getProductionUserStoryCount(
                null, 
                null, 
                null
            );
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(0, storyCount, 'Should return 0 for null pipeline');
    }

    @IsTest
    static void testGetUserStoryData() {
        // SETUP
        List<OverviewProductionUserStoriesController.UserStoryWrapper> stories;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;
            Id releaseId = [SELECT Id FROM copado__Release__c LIMIT 1].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;
            lwcParams.selectedReleaseId = releaseId;
            lwcParams.queryLimit = 10;
            lwcParams.offset = 0;

            // EXERCISE
            Test.startTest();
            stories = OverviewProductionUserStoriesController.getUserStoryData(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, stories.size(), 'Should return one non-excluded user story');
        Assert.areEqual(USER_STORY_TITLE, stories[0].title, 'Story title should match');
        Assert.areEqual(Label.No, stories[0].excludeFromPipeline, 'Story should not be excluded');
    }

    @IsTest
    static void testGetUserStoryDataWithSearch() {
        // SETUP
        final String SEARCH_TERM = '-newUsTitle'; // NOPMD - PMD.LocalVariableNamingConventions

        new UserStory()
            .title(USER_STORY_TITLE + SEARCH_TERM)
            .environmentId([SELECT Id FROM copado__Environment__c WHERE Name = 'PROD' LIMIT 1][0].Id)
            .projectId([SELECT Id FROM copado__Project__c LIMIT 1][0].Id)
            .persist();

        List<OverviewProductionUserStoriesController.UserStoryWrapper> stories;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.queryLimit = 10;
            lwcParams.offset = 0;
            lwcParams.searchTerm = SEARCH_TERM;

            // EXERCISE
            Test.startTest();
            stories = OverviewProductionUserStoriesController.getUserStoryData(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, stories.size(), 'Should return one story matching search term');
        Assert.isTrue(stories[0].title.contains(SEARCH_TERM), 'Retrieved story should match search term');
    }

    @IsTest
    static void testExcludeUserStories() {
        // SETUP
        String result;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id userStoryId = [
                SELECT Id 
                FROM copado__User_Story__c 
                WHERE copado__Exclude_From_CBM__c = false 
                LIMIT 1
            ].Id;

            // EXERCISE
            Test.startTest();
            result = OverviewProductionUserStoriesController.excludeUserStories(
                new List<Id>{userStoryId}
            );
            Test.stopTest();

            copado__User_Story__c updatedStory = [
                SELECT copado__Exclude_From_CBM__c, copado__Stop_Indexing_Metadata__c 
                FROM copado__User_Story__c 
                WHERE Id = :userStoryId
            ];

            // VERIFY
            Assert.areEqual(OK, result, 'Should return OK status');
            Assert.isTrue(updatedStory.copado__Exclude_From_CBM__c, 'Story should be excluded');
            Assert.isTrue(
                updatedStory.copado__Stop_Indexing_Metadata__c, 
                'Story should stop indexing metadata'
            );
        }
    }

    @IsTest
    static void testUserStoryWrapper() {
        // SETUP
        OverviewProductionUserStoriesController.UserStoryWrapper wrapper;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            copado__User_Story__c story = [
                SELECT Id, Name, copado__User_Story_Title__c, RecordType.Name, 
                       copado__Status__c, copado__Exclude_From_CBM__c, 
                       copado__Stop_Indexing_Metadata__c
                FROM copado__User_Story__c 
                WHERE copado__Exclude_From_CBM__c = false 
                LIMIT 1
            ];

            // EXERCISE
            Test.startTest();
            wrapper = new OverviewProductionUserStoriesController.UserStoryWrapper(story);
            Test.stopTest();
        }

        // VERIFY
        Assert.isNotNull(wrapper.id, 'Wrapper ID should not be null');
        Assert.isNotNull(wrapper.name, 'Wrapper name should not be null');
        Assert.areEqual(USER_STORY_TITLE, wrapper.title, 'Wrapper title should match');
        Assert.areEqual(Label.No, wrapper.excludeFromPipeline, 'Should not be excluded from pipeline');
        Assert.areEqual(
            Label.No, 
            wrapper.excludeFromOverlapAwareness, 
            'Should not be excluded from overlap awareness'
        );
        Assert.isTrue(wrapper.url.startsWith('/'), 'URL should start with /');
    }
}