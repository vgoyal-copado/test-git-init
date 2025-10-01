@IsTest
private class OverviewPipelineFilterControllerTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    private static final String PIPELINE_ID_NULL = 'PIPELINE_ID_NULL';
    private static final String ERROR_FETCHING_PROJECTS = 'ERROR_FETCHING_PROJECTS';
    private static final String ERROR_FETCHING_RELEASES = 'ERROR_FETCHING_RELEASES';

    @TestSetup
    static void setupTestData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Repository repo = TestUtilities.createRepository();
            Pipeline activePipeline = TestUtilities.createPipeline(repo, 'Active Pipeline').active(true).platform('SFDX');
            TestUtilities.createPipeline(repo, 'Inactive Pipeline').active(false).platform('SFDX');

            Project project = new Project(activePipeline);

            new Release()
                .name('Release 1')
                .project(project);
            new Release()
                .name('Release 2')
                .persist();
        }
    }

    @IsTest
    static void testGetPipelines() {
        // SETUP
        List<copado__Deployment_Flow__c> pipelines;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // EXERCISE
            Test.startTest();
            pipelines = OverviewPipelineFilterController.getPipelines();
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, pipelines.size(), 'Should return only active pipelines');
        copado__Deployment_Flow__c pipelineQueried = [
            SELECT copado__Active__c FROM copado__Deployment_Flow__c WHERE Id = :pipelines[0].Id LIMIT 1
        ];
        Assert.isTrue(pipelineQueried.copado__Active__c, 'Retrieved pipeline should be active');
    }

    @IsTest
    static void testGetProjects() {
        // SETUP
        List<copado__Project__c> projects;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c 
                           WHERE copado__Active__c = true LIMIT 1].Id;

            // EXERCISE
            Test.startTest();
            projects = OverviewPipelineFilterController.getProjects(pipelineId);
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, projects.size(), 'Should return one project');
        Assert.isNotNull(projects[0].Name, 'The field name should be returned');
    }

    @IsTest
    static void testGetReleases() {
        // SETUP
        List<copado__Release__c> releases;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c 
                           WHERE copado__Active__c = true LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;

            // EXERCISE
            Test.startTest();
            releases = OverviewPipelineFilterController.getReleases(pipelineId, projectId);
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, releases.size(), 'Should return one release for the project');
        Assert.isNotNull(releases[0].Name, 'The field name should be returned');
    }

    @IsTest
    static void testGetReleasesWithoutProject() {
        // SETUP
        List<copado__Release__c> releases;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c 
                           WHERE copado__Active__c = true LIMIT 1].Id;

            // EXERCISE
            Test.startTest();
            releases = OverviewPipelineFilterController.getReleases(pipelineId, null);
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, releases.size(), 'Should return all releases for the pipeline');
    }
}