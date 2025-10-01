@isTest
private class AuthenticateGitRepositoryTest {

    private static final String EXTRA_HEADERS = 'Extra Headers';

    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
    }

    @IsTest
    private static void saveWithShortExtraHeaders() {
        System.runAs(TestUtilities.getRunAsUser()) {

        // Setup
        copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                            .name('testRepo')
                                                                            .uri('https://github.com/account/repoName')
                                                                            .persist();

       insert new Note(
           Title = EXTRA_HEADERS, 
           ParentId = repository.Id, 
           Body = 'Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json'
        );

        // Exercise
        Test.startTest();
        AuthenticateGitRepository.Request request = new AuthenticateGitRepository.Request();
        request.sfRepositoryId = repository.Id;
        request.repositoryUri = 'https://github.com/account/repoName';
        request.userName = 'test+gitrepository@copado.com';
        request.password = 'azs123!!??@';
        request.extraHeaders = 'Accept: application/json';
        AuthenticateGitRepository.execute(new List<AuthenticateGitRepository.Request> { request });
        Test.stopTest();

        // Verify
        List<Note> headers = [SELECT Id FROM Note WHERE ParentId = :repository.Id AND Title = :EXTRA_HEADERS LIMIT 1];
        
        Assert.isTrue(headers.isEmpty(), 'Short extra headers must be stored in a Sensitive Information record and old Note records must be deleted.');
        }
    }

    @IsTest
    private static void saveWithLongExtraHeaders() {
        System.runAs(TestUtilities.getRunAsUser()) {

        // Setup
        copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                            .name('testRepo')
                                                                            .uri('https://github.com/account/repoName')
                                                                            .persist();

        // Exercise
        Test.startTest();
        AuthenticateGitRepository.Request request = new AuthenticateGitRepository.Request();
        request.sfRepositoryId = repository.Id;
        request.repositoryUri = 'https://github.com/account/repoName';
        request.userName = 'rtoro+gitrepository@copado.com';
        request.password = 'azs123!!??@';
        request.extraHeaders = 'Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json';
        AuthenticateGitRepository.execute(new List<AuthenticateGitRepository.Request> { request });
        Test.stopTest();

        // Verify
        List<Note> headers = [SELECT Body FROM Note WHERE ParentId = :repository.Id AND Title = :EXTRA_HEADERS LIMIT 1];
        
        Assert.isTrue(!headers.isEmpty(), 'Long extra headers must be stored in a Note record.');
        }
    }
}