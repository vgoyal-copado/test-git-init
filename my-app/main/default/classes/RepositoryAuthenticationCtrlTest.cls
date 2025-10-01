@IsTest
private class RepositoryAuthenticationCtrlTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
    }

    @IsTest
    private static void executeAuthenticated() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                                .name('testRepo')
                                                                                .uri('https://github.com/account/repoName')
                                                                                .persist();

            // Exercise
            Test.startTest();
                RepositoryAuthenticationCtrl.testAuthenticationResult = true;
                Boolean result = RepositoryAuthenticationCtrl.isAuthenticated(repository.Id);
            Test.stopTest();

            // Verify
            Assert.isTrue(result, 'Repository is authenticated');
        }
    }
    
    @IsTest
    private static void executeNotAuthenticated() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                                .name('testRepo')
                                                                                .uri('https://github.com/account/repoName')
                                                                                .persist();

            // Exercise
            Test.startTest();
                RepositoryAuthenticationCtrl.testAuthenticationResult = false;
                Boolean result = RepositoryAuthenticationCtrl.isAuthenticated(repository.Id);
            Test.stopTest();

            // Verify
            Assert.isFalse(result, 'Repository is not authenticated');
        }
    }
}