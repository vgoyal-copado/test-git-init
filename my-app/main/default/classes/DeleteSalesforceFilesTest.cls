@IsTest
private class DeleteSalesforceFilesTest {
    private static final String HASH_METADATA_TYPE_AND_NAME1 = 'd5def579c255cb0f448e98020c5fefbc';
    private static final String HASH_METADATA_TYPE_AND_NAME2 = 'd5def579c255cb0f448e98020c5fefbe';
    private static final String HASH_METADATA_TYPE_AND_NAME3 = 'd5def579c255cb0f448e98020c5fefbd';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void deleteSessionFilesOnUSTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup

            Id userStoryId = getUserStory().Id;

            // Exercise

            Test.startTest();
            DeleteSalesforceFiles.deleteContentDocuments(
                new List<Id>{ userStoryId },
                new List<String>{ '%_session', '%_base', '%_feature', '%_destination', '%_source', '%_structure' }
            );
            Test.stopTest();

            // Verify
            Set<String> searchPatterns = new Set<String>{ '%_session', '%_base', '%_feature', '%_destination', '%_source' , '%_structure'};
            List<ContentDocumentLink> selectiveCommtFiles = new ContentDocumentLinksSelector()
                .contentDocumentByLinkedEntityIdAndTitle(new Set<Id>{ userStoryId }, searchPatterns);
            Assert.areEqual(0, selectiveCommtFiles.size(), 'All the selective commit session files on the US should be deleted');
        }
    }

    @IsTest
    private static void deleteOutdatedContentDocumentsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup

            Id userStoryId = getUserStory().Id;
            Set<String> fileNames = new Set<String>{ 'test_session' };

            // Exercise

            Test.startTest();
            createContentVersions(userStoryId);
            Map<String, ContentDocument> result = DeleteSalesforceFiles.deleteOutdatedContentDocumentsAndReturnLatest(fileNames, userStoryId);
            Test.stopTest();

            // Verify

            Assert.areEqual(1, result.size(), 'Outdated content document should be deleted');
            ContentDocument newContentDocument = result.get('test_session');
            List<ContentDocumentLink> links = new ContentDocumentLinksSelector().byLinkedEntityIdAndTitles(new Set<Id>{ userStoryId }, fileNames);
            Assert.areEqual(newContentDocument.Id, links[0].ContentDocument.Id, 'Outdated Content Documents should be deleted.');
        }
    }

    private static void createData() {
        Credential credential = new Credential(new Environment().type('Production/Developer'));
        copado__User_Story__c userStory = (copado__User_Story__c) new UserStory().title('US 1').status('Draft').credential(credential).persist();
        createSelectiveCommitFilesOnUS(userStory.Id);
    }

    private static copado__User_Story__c getUserStory() {
        return [SELECT Id FROM copado__User_Story__c LIMIT 1];
    }

    private static void createContentVersions(Id userStoryId) {
        new ContentVersion_t()
            .title('test_session')
            .pathOnClient('test_session')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('Old Session file for File 2'))
            .persist();

        new ContentVersion_t()
            .title('test_session')
            .pathOnClient('test_session')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('New Session file for File 2'))
            .persist();
    }

    private static void createSelectiveCommitFilesOnUS(Id userStoryId) {
        for (String filename : CommitFunctionCallback.SELECTIVE_COMMIT_HASH_SUFFIXES) {
            new ContentVersion_t()
                .title(HASH_METADATA_TYPE_AND_NAME1 + filename)
                .pathOnClient(HASH_METADATA_TYPE_AND_NAME1 + filename)
                .firstPublishLocationId(userStoryId)
                .versionData(Blob.valueOf('old data for Selective Commit'))
                .persist();

            new ContentVersion_t()
                .title(HASH_METADATA_TYPE_AND_NAME1 + filename)
                .pathOnClient(HASH_METADATA_TYPE_AND_NAME1 + filename)
                .firstPublishLocationId(userStoryId)
                .versionData(Blob.valueOf('new retrieved data for selective commit'))
                .persist();
        }

        new ContentVersion_t()
            .title(HASH_METADATA_TYPE_AND_NAME2 + '_session')
            .pathOnClient(HASH_METADATA_TYPE_AND_NAME2 + '_session')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('Session file for File 2'));

            new ContentVersion_t()
            .title(HASH_METADATA_TYPE_AND_NAME3 + '_structure')
            .pathOnClient(HASH_METADATA_TYPE_AND_NAME3 + '_structure')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('Structure file for File 3'))
            .persist();
    }
}