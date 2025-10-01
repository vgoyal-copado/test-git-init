@isTest
private class GenerateSshKeyTest {

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
    }

    @IsTest
    private static void execute() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // Setup
            copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                                .name('testRepo')
                                                                                .uri('https://github.com/account/repoName')
                                                                                .persist();
            Attachment sshKey = new Attachment(Name = 'id_rsa.pub', ParentId = repository.Id, Body = Blob.valueOf('aszxdcRwfdftg123'));
            insert sshKey;

            // Exercise
            Test.startTest();

            GenerateSshKey.Request request = new GenerateSshKey.Request();
            request.gitRepositoryId = repository.Id;

            List<GenerateSshKey.Response> responses = GenerateSshKey.execute(new List<GenerateSshKey.Request> { request });

            Test.stopTest();

            // Verify
            Assert.areEqual('aszxdcRwfdftg123', responses[0].sshKey, 'The key does not match');
        }
    }

    @IsTest
    private static void executeWithException() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // Setup
            copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                                .name('testRepo')
                                                                                .uri('https://github.com/account/repoName')
                                                                                .persist();

            // Exercise
            Test.startTest();

            GenerateSshKey.Request request = new GenerateSshKey.Request();
            request.gitRepositoryId = repository.Id;

            GenerateSshKey.testkeyResponse = '{"error": "Keys not created"}';

            List<GenerateSshKey.Response> responses = GenerateSshKey.execute(new List<GenerateSshKey.Request> { request });

            Test.stopTest();

            // Verify
            Assert.isNull(responses[0].sshKey, 'The key is not null');
        }
    }
}