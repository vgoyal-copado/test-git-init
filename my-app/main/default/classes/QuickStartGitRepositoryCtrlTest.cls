@isTest
private class QuickStartGitRepositoryCtrlTest {

    private static final String SSH_KEY_NAME = 'id_rsa.pub';
    private static final String EXTRA_HEADERS = 'Extra Headers';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
    }

    @IsTest
    private static void validateGitConnectionException() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // Setup
            String exceptionMessage;
    
            // Exercise
            Test.startTest();
            try {
                QuickStartGitRepositoryCtrl.validateGitConnection(null);
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }
            Test.stopTest();
    
            // Verify
            Assert.isNotNull(exceptionMessage, 'There is no exception');
            Assert.areEqual('Argument cannot be null.', exceptionMessage, 'The exception message does not match');
        }
    }

    @IsTest
    private static void createSSHKey() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // Setup
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Complete', '{"ok": "Keys created"}', null));

            // Exercise
            Test.startTest();
            String key = QuickStartGitRepositoryCtrl.createSSHKey(null);
            Test.stopTest();
    
            // Verify
            Assert.areEqual(
                '', 
                key, 
                'Incorrect SSH key generation result: response should be OK.'
            );
        }
    }

    @IsTest
    private static void createSSHKeyException() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // Setup
            String exceptionMessage;
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Complete', '{"ok": "Keys created"}', null));

            // Exercise
            Test.startTest();
            try {
                QuickStartGitRepositoryCtrl.createSSHKey(UserInfo.getUserId());
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }
            Test.stopTest();
    
            // Verify
            Assert.areEqual(
                'An error occurred when creating SSH Key. Please contact your System Administrator', 
                exceptionMessage, 
                'The exception message does not match'
            );
        }
    }

    @IsTest
    private static void getSSHKey() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // Setup
            copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                            .name('testRepo')
                                                                            .uri('https://github.com/account/repoName')
                                                                            .persist();
    
            Attachment sshKey = new Attachment(Name = SSH_KEY_NAME, ParentId = repository.Id, Body = Blob.valueOf('aszxdcRwfdftg123'));
            insert sshKey;
    
            // Exercise
            Test.startTest();
            String result = QuickStartGitRepositoryCtrl.getSSHKey(repository.Id);
            Test.stopTest();
    
            // Verify
            Assert.areEqual(
                '{"key":"aszxdcRwfdftg123","attachmentId":"' + sshKey.Id + '"}', 
                result, 
                'Incorrect SSH key value returned for selected repository.'
            );
        }
    }

    @IsTest
    private static void deleteSSHKey() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                                .name('testRepo')
                                                                                .uri('https://github.com/account/repoName')
                                                                                .persist();
    
            Attachment sshKey = new Attachment(Name = SSH_KEY_NAME, ParentId = repository.Id, Body = Blob.valueOf('aszxdcRwfdftg123'));
            insert sshKey;
    
            // Exercise
            Test.startTest();
            QuickStartGitRepositoryCtrl.deleteSSHKey(sshKey.Id);
            Test.stopTest();
    
            // Verify
            List<Attachment> result = [SELECT Id FROM Attachment WHERE Id = :sshKey.Id];
    
            Assert.isTrue(result.isEmpty(), 'SSH Key for selected repository must have been deleted.');
        }
    }

    @IsTest
    private static void getExistingRepositories() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__Git_Repository__c repository = (copado__Git_Repository__c) new GitRepository()
                                                                                .name('testRepo')
                                                                                .uri('https://github.com/account/repoName')
                                                                                .persist();
    
            Attachment attachment = new Attachment();
            attachment.Body = Blob.valueOf('Test 123');
            attachment.Name = 'Repositories';
            attachment.ParentId = repository.Id;
            insert attachment;
    
            // Exercise
            Test.startTest();
            String result = QuickStartGitRepositoryCtrl.getExistingRepositories(repository.Id);
            Test.stopTest();
    
            // Verify
            Assert.areEqual('Test 123', result, 'The attachment content does not match');
        }
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
        QuickStartGitRepositoryCtrl.save(repository.Id, 'HTTPS', 'test+gitrepository@copado.com', 'azs123!!??@', 'Accept: application/json');
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
        QuickStartGitRepositoryCtrl.save(
            repository.Id, 
            'HTTPS', 
            'rtoro+gitrepository@copado.com', 
            'azs123!!??@', 
            'Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json,Accept: application/json'
        );
        Test.stopTest();

        // Verify
        List<Note> headers = [SELECT Body FROM Note WHERE ParentId = :repository.Id AND Title = :EXTRA_HEADERS LIMIT 1];
        
        Assert.isTrue(!headers.isEmpty(), 'Long extra headers must be stored in a Note record.');
        }
    }

    @IsTest
    private static void saveException() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // Setup
            String exceptionMessage;

            // Exercise
            Test.startTest();
            try {
                QuickStartGitRepositoryCtrl.save(null, 'test', null, null, null);
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }
            Test.stopTest();

            // Verify
            Assert.isNotNull(exceptionMessage, 'There is no exception');
            Assert.areEqual('Script-thrown exception', exceptionMessage, 'The exception message does not match');
        }
    }

    @IsTest
    private static void saveRepositorySelectionTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Exception expectedException = null;

            // Setup
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Complete', 'Internal Server Error', null));
            
            // Exercise
            QuickStartGitRepositoryCtrl.GitRepoRequest request = new QuickStartGitRepositoryCtrl.GitRepoRequest();
            request.recordId = null;
            Test.startTest();
            try {
                QuickStartGitRepositoryCtrl.saveRepositorySelection(JSON.serialize(request));
                Test.stopTest();
            } catch(Exception ex) {
                expectedException = ex;
            }

            // Verify
            Assert.isNotNull(expectedException, 'There is no exception');
        }
    }

    @IsTest
    private static void initHTTPSRepository() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__Org__c cred = (copado__Org__c) new Credential(new Environment().name('dev').platform('SFDX').type('Production/Developer')).type('Production/Developer').persist();

            Note headers = new Note(Title = EXTRA_HEADERS, ParentId = cred.Id, Body = 'Accept: application/json');
            insert headers;

            // Exercise
            Test.startTest();
            QuickStartGitRepositoryCtrl.Configuration result = QuickStartGitRepositoryCtrl.init(cred.Id);
            Test.stopTest();

            // Verify
            Assert.areEqual(null, result.headers, 'The headers are not null');
        }
    }
}