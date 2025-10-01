@IsTest
private class OverviewGitRepositoryControllerTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    private static final String SUCCESS = 'success';
    private static final String MOCK_REPO_URL = 'https://github.com/test/repo';
    private static final String MOCK_REPO_NAME = 'Test Repository';

    @TestSetup
    static void setupTestData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Repository repo = TestUtilities.createRepository()
                .name(MOCK_REPO_NAME)
                .pullRequestBaseUrl(MOCK_REPO_URL);
            
            TestUtilities.createPipeline(repo, 'SFDX')
                .active(true);
            
            TestUtilities.createPipeline(null, 'SFDX')
                .active(true).persist();
        }
    }

    @IsTest
    static void testGetGitRepositorySuccess() {
        OverviewGitRepositoryController.GitRepositoryWrapper result;
        
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [
                SELECT Id 
                FROM copado__Deployment_Flow__c 
                WHERE copado__Git_Repository__c != null 
                LIMIT 1
            ].Id;

            Test.startTest();
            result = OverviewGitRepositoryController.getGitRepository(pipelineId);
            Test.stopTest();
        }

        Assert.isNotNull(result, 'Should return a repository wrapper');
        Assert.isNotNull(result.id, 'Repository ID should not be null');
        Assert.areEqual(MOCK_REPO_URL, result.url, 'Repository URL should match');
        Assert.areEqual(MOCK_REPO_NAME, result.name, 'Repository name should match');
        Assert.isTrue(result.isAuthenticated, 'Repository should be authenticated');
    }

    @IsTest
    static void testGetGitRepositoryNullPipeline() {
        OverviewGitRepositoryController.GitRepositoryWrapper result;
        
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Test.startTest();
            result = OverviewGitRepositoryController.getGitRepository(null);
            Test.stopTest();
        }

        Assert.isNull(result, 'Should return null for null pipeline ID');
    }

    @IsTest
    static void testGetGitRepositoryPipelineWithoutRepo() {
        OverviewGitRepositoryController.GitRepositoryWrapper result;
        
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [
                SELECT Id 
                FROM copado__Deployment_Flow__c 
                WHERE copado__Git_Repository__c = null 
                LIMIT 1
            ].Id;

            Test.startTest();
            result = OverviewGitRepositoryController.getGitRepository(pipelineId);
            Test.stopTest();
        }

        Assert.isNull(result, 'Should return null for pipeline without repository');
    }

    @IsTest
    static void testGitRepositoryWrapperConstructor() {
        OverviewGitRepositoryController.GitRepositoryWrapper wrapper;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Test.startTest();
            wrapper = 
                new OverviewGitRepositoryController.GitRepositoryWrapper(
                    null, 
                    MOCK_REPO_URL, 
                    MOCK_REPO_NAME
                );
            Test.stopTest();
        }

        Assert.isNull(wrapper.id, 'ID should be null');
        Assert.areEqual(MOCK_REPO_URL, wrapper.url, 'URL should match');
        Assert.areEqual(MOCK_REPO_NAME, wrapper.name, 'Name should match');
        Assert.isNull(wrapper.isAuthenticated, 'Authentication should be null for null ID');
    }
}