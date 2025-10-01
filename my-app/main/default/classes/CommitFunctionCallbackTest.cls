@IsTest
private class CommitFunctionCallbackTest {
    private static final String HASH_FILE1 = 'd5def579c255cb0f448e98020c5fefbc';
    private static final String HASH_FILE2 = 'd5def579c255cb0f448e98020c5fefbe';
    private static final String HASH_FILE3 = 'd41d8cd98f00b204e9800998ecf8427e';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void handleSessionAndCommitFilesOnUSTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup

            Id userStoryId = getUserStory().Id;
            Function function = new Function().apiName('sfdx_commit');
            new ContentVersion_t()
                .title(HASH_FILE2 + '_session')
                .pathOnClient(HASH_FILE2 + '_session')
                .firstPublishLocationId(userStoryId)
                .versionData(Blob.valueOf('Duplicate Session file for File 2'))
                .persist();

            // Exercise

            Test.startTest();
            new CommitFunctionCallback().execute(new Copado__Function__c(Id = function.Id), getResult(), 'Success');
            Test.stopTest();

            // Verify

            Set<String> fileNames = new Set<String>{ '%_session', '%_commit', '%_base', '%_source', '%_destination', '%_feature', '%_temp', '%_structure' };

            List<ContentDocumentLink> commitFiles = new ContentDocumentLinksSelector()
                .contentDocumentByLinkedEntityIdAndTitle(new Set<Id>{ userStoryId }, fileNames);
            Assert.areEqual(2, commitFiles.size(), 'There should be commit files on the US');
            for (ContentDocumentLink link : commitFiles) {
                if (link.ContentDocument.title == HASH_FILE1 + '_commit') {
                    Assert.areEqual(
                        'new commit file',
                        link.ContentDocument.LatestPublishedVersion.VersionData.toString(),
                        'Commit file with no session should not have changed'
                    );
                } else if (link.ContentDocument.title == HASH_FILE2 + '_commit') {
                    Assert.areEqual(
                        'Duplicate Session file for File 2',
                        link.ContentDocument.LatestPublishedVersion.VersionData.toString(),
                        'Outdated Commit file with session file should have been deleted and session file should be renamed to commit file'
                    );
                }
            }
        }
    }

    @IsTest
    private static void deleteObsoleteSelectiveCommitFilesFromPreviousCommit() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Environment env = TestUtilities.createEnvironment('Env1');
            Credential credential = TestUtilities.createCredential(false, env);
            copado__User_Story__c userStory = (copado__User_Story__c) new UserStory().title('US 1').status('Draft').credential(credential).persist();

            createCommitChangesFile(userStory.Id, getChanges(new List<String>{'Add'}, new List<String>{''}, new List<String>{'Test'}, new List<String>{'Layout'}));
            new ContentVersion_t()
                .title(HASH_FILE2 + '_commit')
                .pathOnClient(HASH_FILE2 + '_commit')
                .firstPublishLocationId(userStory.Id)
                .versionData(Blob.valueOf('Commit file for File 2'));
            new ContentVersion_t()
                .title(HASH_FILE2 + '_session')
                .pathOnClient(HASH_FILE2 + '_session')
                .firstPublishLocationId(userStory.Id)
                .versionData(Blob.valueOf('Session file for File 2'));

            JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit1').type('Custom');
            JobStep jobStep = new JobStep(jobTemplate).name('Commit Step').type('Function');
            JobExecution jobExecution = new JobExecution(jobTemplate, env)
                .dataJson(
                    '{"sampleKey":"sampleValue", "userStoryId" : "' +
                        userStory.Id +
                        '", "fileWithSelectedChanges": "' +
                        getContentVersionId('Copado Commit Changes', userStory.Id) +
                        '"}'
                )
                .add(jobStep);
            new Result(jobStep).type('Integration').status('Success').data('{"commitId":"sampleCommitId"}');

            Function function = new Function().apiName('commit');
            new UserStoryMetadata_t()
                .name('Test')
                .type('Layout')
                .action('SelectiveCommit')
                .category('SFDX')
                .jsonInfo('{\"selectiveCommitFileId\":\"0687Q00000LwcedQAB\",\"selectiveCommitHash\":\"' + HASH_FILE2 + '\"}')
                .userStory(new UserStory().recordId(userStory.Id))
                .persist();

            // Exercise

            Test.startTest();
            new CommitFunctionCallback()
                .execute(new Copado__Function__c(Id = function.Id), getResultByStep(getJobStep(jobExecution.Id, 'Commit Step').Id), 'Success');
            Test.stopTest();

            // Verify

            List<ContentDocumentLink> commitFiles = new ContentDocumentLinksSelector()
                .contentDocumentByLinkedEntityIdAndTitle(new Set<Id>{ userStory.Id }, new Set<String>{ '%_session', '%_commit' });
            Assert.areEqual(0, commitFiles.size(), 'There should be no commit files on the US');
        }
    }

    @IsTest
    private static void renameSessionFilesOnUSTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup

            Function function = new Function().apiName('sfdx_commit');

            // Exercise

            Test.startTest();
            new CommitFunctionCallback().execute(new Copado__Function__c(Id = function.Id), getResult(), 'Success');
            Test.stopTest();

            // Verify
            Set<String> searchPatterns = new Set<String>{ '%_base', '%_destination', '%_feature', '%_source', '%_session', '%_temp' };
            List<ContentDocumentLink> filesOnUS = new ContentDocumentLinksSelector()
                .contentDocumentByLinkedEntityIdAndTitle(new Set<Id>{ getUserStory().Id }, searchPatterns);
            Assert.areEqual(0, filesOnUS.size(), 'All the selective commit files on the US should be deleted');
        }
    }

    @IsTest
    private static void invalidResultStatus() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup

            copado__Result__c commitResult = getResult();
            commitResult.copado__Status__c = 'Failed';
            update commitResult;

            Function function = new Function().apiName('sfdx_commit');

            // Exercise

            Test.startTest();
            new CommitFunctionCallback().execute(new Copado__Function__c(Id = function.Id), commitResult, 'Failed');
            Test.stopTest();

            // Verify

            copado__JobExecution__c jobExecution = getJobExecution();
            Map<String, Object> dataJsonResponse = (Map<String, Object>) JSON.deserializeUntyped(jobExecution.copado__DataJson__c);
            System.assertEquals(null, jobExecution.copado__ErrorMessage__c, 'The result of commit function callback should be blank');
            String actionCallback = dataJsonResponse.containsKey('actionCallback') ? (String) dataJsonResponse.get('actionCallback') : '';
            System.assert(String.isBlank(actionCallback), 'The action callback of commit job execution should be blank');
        }
    }

    @IsTest
    private static void invalidResultData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup

            copado__Result__c commitResult = getResult();
            commitResult.copado__Result_Data__c = '{"status":"No Changes"}';
            update commitResult;

            Function function = new Function().apiName('sfdx_commit');

            // Exercise

            Test.startTest();
            new CommitFunctionCallback().execute(new Copado__Function__c(Id = function.Id), commitResult, 'Success');
            Test.stopTest();

            // Verify

            copado__JobExecution__c jobExecution = getJobExecution();
            Map<String, Object> dataJsonResponse = (Map<String, Object>) JSON.deserializeUntyped(jobExecution.copado__DataJson__c);
            System.assertEquals(null, jobExecution.copado__ErrorMessage__c, 'The result of commit function callback should be blank');
            String actionCallback = dataJsonResponse.containsKey('actionCallback') ? (String) dataJsonResponse.get('actionCallback') : '';
            System.assert(String.isBlank(actionCallback), 'The action callback of commit job execution should be blank');
        }
    }

    @IsTest
    private static void createBundledCommitFileFromSessionFileTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Environment env = TestUtilities.createEnvironment('Env1');
            Credential credential = TestUtilities.createCredential(false, env);
            copado__User_Story__c userStory = (copado__User_Story__c) new UserStory().title('US 1').status('Draft').credential(credential).persist();

            new ContentVersion_t()
            .title(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .pathOnClient(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('{"LightningComponentBundle:testLWC" : ["path1", "path2"]}'))
            .persist();

            List<String> actions = new List<String>{'SelectiveCommit'};
            List<String> additionalInfo = new List<String>{'{"selectiveCommitHash" : "Tdshgd"}'};
            List<String> names = new List<String>{'testLWC'};
            List<String> types = new List<String>{'LightningComponentBundle'};

            createCommitChangesFile(userStory.Id, getChanges(actions, additionalInfo, names, types));

            JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit1').type('Custom');
            JobStep jobStep = new JobStep(jobTemplate).name('Commit Step').type('Function');
            JobExecution jobExecution = new JobExecution(jobTemplate, env)
                .dataJson(
                    '{"sampleKey":"sampleValue", "userStoryId" : "' +
                        userStory.Id +
                        '", "fileWithSelectedChanges": "' +
                        getContentVersionId('Copado Commit Changes', userStory.Id) +
                        '","recreateFeatureBranch" : "true"}'
                )
                .add(jobStep);
            new Result(jobStep).type('Integration').status('Success').data('{"commitId":"sampleCommitId"}');

            Function function = new Function().apiName('commit');
            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action('SelectiveCommit')
                .category('SFDX')
                .jsonInfo('{\"selectiveCommitFileId\":\"0687Q00000LwcedQAB\",\"selectiveCommitHash\":\"TGlnaHRu\"}')
                .userStory(new UserStory().recordId(userStory.Id))
                .persist();

            // Exercise

            Test.startTest();
            new CommitFunctionCallback()
                .execute(new Copado__Function__c(Id = function.Id), getResultByStep(getJobStep(jobExecution.Id, 'Commit Step').Id), 'Success');
            Test.stopTest();

            // Verify

            List<ContentVersion> commitFiles = new ContentVersionsSelector().byFirstPublishLocationIdAndTitleAndIsLatest(new Set<Id>{ userStory.Id }, new List<String>{ CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT });
            Assert.areEqual(1, commitFiles.size(), 'There should be  commit file for bundled mdt on the US');
            Assert.areEqual('{"LightningComponentBundle:testLWC":["path1","path2"]}', commitFiles[0].VersionData?.toString(), 'Session Content should be copied to Commit file');
        }
    }

    @IsTest
    private static void createNewBundledCommitFileAndDeleteOutdatedFileTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Environment env = TestUtilities.createEnvironment('Env1');
            Credential credential = TestUtilities.createCredential(false, env);
            copado__User_Story__c userStory = (copado__User_Story__c) new UserStory().title('US 1').status('Draft').credential(credential).persist();

            new ContentVersion_t()
            .title(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .pathOnClient(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('{"LightningComponentBundle:testLWC" : ["path3", "path4"], "AuraDefinitionBundle:testAura": ["path5"]}'))
            .persist();

            new ContentVersion_t()
            .title(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT)
            .pathOnClient(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT)
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('{"LightningComponentBundle:testLWC" : ["path1", "path2"]}'))
            .persist();

            List<String> actions = new List<String>{'SelectiveCommit', 'SelectiveCommit'};
            List<String> additionalInfo = new List<String>{'{"selectiveCommitHash" : "Tdshgd"}', '{"selectiveCommitHash" : "hash2"}'};
            List<String> names = new List<String>{'testLWC', 'testAura'};
            List<String> types = new List<String>{'LightningComponentBundle', 'AuraDefinitionBundle'};

            createCommitChangesFile(userStory.Id, getChanges(actions, additionalInfo, names, types));

            JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit1').type('Custom');
            JobStep jobStep = new JobStep(jobTemplate).name('Commit Step').type('Function');
            JobExecution jobExecution = new JobExecution(jobTemplate, env)
                .dataJson(
                    '{"sampleKey":"sampleValue", "userStoryId" : "' +
                        userStory.Id +
                        '", "fileWithSelectedChanges": "' +
                        getContentVersionId('Copado Commit Changes', userStory.Id) +
                        '","recreateFeatureBranch" : "true"}'
                )
                .add(jobStep);
            new Result(jobStep).type('Integration').status('Success').data('{"commitId":"sampleCommitId"}');

            Function function = new Function().apiName('commit');
            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action('SelectiveCommit')
                .category('SFDX')
                .jsonInfo('{\"selectiveCommitFileId\":\"0687Q00000LwcedQAB\",\"selectiveCommitHash\":\"TGlnaHRu\"}')
                .userStory(new UserStory().recordId(userStory.Id))
                .persist();
            new UserStoryMetadata_t()
                .name('testAura')
                .type('AuraDefinitionBundle')
                .action('SelectiveCommit')
                .category('SFDX')
                .jsonInfo('{\"selectiveCommitFileId\":\"0687Q00000LwcedQAB\",\"selectiveCommitHash\":\"TGlnaHRu\"}')
                .userStory(new UserStory().recordId(userStory.Id))
                .persist();

            // Exercise

            Test.startTest();
            new CommitFunctionCallback()
                .execute(new Copado__Function__c(Id = function.Id), getResultByStep(getJobStep(jobExecution.Id, 'Commit Step').Id), 'Success');
            Test.stopTest();

            // Verify

            List<ContentVersion> commitFiles = new ContentVersionsSelector().byFirstPublishLocationIdAndTitleAndIsLatest(new Set<Id>{ userStory.Id }, new List<String>{ CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT });
            Assert.areEqual(1, commitFiles.size(), 'There should be  commit file for bundled mdt on the US');
            Assert.areEqual('{"AuraDefinitionBundle:testAura":["path5"],"LightningComponentBundle:testLWC":["path3","path4"]}', commitFiles[0].VersionData?.toString(), 'Session Content should be copied to Commit file');
        }
    }

    @IsTest
    private static void recreateFeatureBranchFalseForBundledSelectiveCommit() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Environment env = TestUtilities.createEnvironment('Env1');
            Credential credential = TestUtilities.createCredential(false, env);
            copado__User_Story__c userStory = (copado__User_Story__c) new UserStory().title('US 1').status('Draft').credential(credential).persist();

            new ContentVersion_t()
            .title(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT)
            .pathOnClient(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT)
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('{"LightningComponentBundle:testLWC" : ["path3", "path4"], "AuraDefinitionBundle:testAura": ["path5"]}'))
            .persist();

            new ContentVersion_t()
            .title(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .pathOnClient(CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('{"LightningComponentBundle:testLWC" : ["path1", "path2"]}'))
            .persist();

            List<String> actions = new List<String>{'SelectiveCommit'};
            List<String> additionalInfo = new List<String>{'{"selectiveCommitHash" : "Tdshgd"}'};
            List<String> names = new List<String>{'testLWC'};
            List<String> types = new List<String>{'LightningComponentBundle'};

            createCommitChangesFile(userStory.Id, getChanges(actions, additionalInfo, names, types));
            JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit1').type('Custom');
            JobStep jobStep = new JobStep(jobTemplate).name('Commit Step').type('Function');
            JobExecution jobExecution = new JobExecution(jobTemplate, env)
                .dataJson(
                    '{"sampleKey":"sampleValue", "userStoryId" : "' +
                        userStory.Id +
                        '", "fileWithSelectedChanges": "' +
                        getContentVersionId('Copado Commit Changes', userStory.Id) +
                        '","recreateFeatureBranch" : "false"}'
                )
                .add(jobStep);
            new Result(jobStep).type('Integration').status('Success').data('{"commitId":"sampleCommitId"}');

            Function function = new Function().apiName('commit');
            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action('SelectiveCommit')
                .category('SFDX')
                .jsonInfo('{\"selectiveCommitFileId\":\"0687Q00000LwcedQAB\",\"selectiveCommitHash\":\"TGlnaHRu\"}')
                .userStory(new UserStory().recordId(userStory.Id))
                .persist();
            new UserStoryMetadata_t()
                .name('testAura')
                .type('AuraDefinitionBundle')
                .action('SelectiveCommit')
                .category('SFDX')
                .jsonInfo('{\"selectiveCommitFileId\":\"0687Q00000LwcedQAB\",\"selectiveCommitHash\":\"TGlnaHRu\"}')
                .userStory(new UserStory().recordId(userStory.Id))
                .persist();

            // Exercise

            Test.startTest();
            new CommitFunctionCallback()
                .execute(new Copado__Function__c(Id = function.Id), getResultByStep(getJobStep(jobExecution.Id, 'Commit Step').Id), 'Success');
            Test.stopTest();

            // Verify

            List<ContentVersion> commitFiles = new ContentVersionsSelector().byFirstPublishLocationIdAndTitleAndIsLatest(new Set<Id>{ userStory.Id }, new List<String>{ CommitFunctionCallback.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT });
            Assert.areEqual(1, commitFiles.size(), 'There should be  commit file for bundled mdt on the US');
            Assert.areEqual('{"AuraDefinitionBundle:testAura":["path5"],"LightningComponentBundle:testLWC":["path1","path2"]}', commitFiles[0].VersionData?.toString(), 'Session Content should be copied to Commit file');
        }
    }

    private static void createData() {
        Credential credential = new Credential(new Environment().type('Production/Developer'));
        copado__User_Story__c userStory = (copado__User_Story__c) new UserStory().title('US 1').status('Draft').credential(credential).persist();
        List<String> actions = new List<String>{'SelectiveCommit'};
        List<String> additionalInfo = new List<String>{'{\"selectiveCommitFileId\":\"0687Q00000LwcedQAB\",\"selectiveCommitHash\":\"' + HASH_FILE2 + '\"}'};
        List<String> names = new List<String>{'Test'};
        List<String> types = new List<String>{'Layout'};
        createCommitChangesFile(userStory.Id, getChanges(actions, additionalInfo, names, types));

        createSelectiveCommitFilesOnUS(userStory.Id);

        JobTemplate jobTemplate = new JobTemplate().name('Commit').type('Custom');
        JobStep jobStep = new JobStep(jobTemplate).name('Commit Step').type('Function');
        new JobExecution(jobTemplate, new Environment())
            .dataJson(
                '{"sampleKey":"sampleValue", "userStoryId" : "' +
                    userStory.Id +
                    '", "fileWithSelectedChanges": "' +
                    getContentVersionId('Copado Commit Changes', userStory.Id) +
                    '"}'
            )
            .add(jobStep);
        new Result(jobStep).type('Integration').status('Success').data('{"commitId":"sampleCommitId"}').persist();
    }

    private static copado__Result__c getResult() {
        return [SELECT Id, copado__Result_Data__c, copado__Status__c FROM copado__Result__c LIMIT 1];
    }

    private static copado__JobStep__c getJobStep(Id jobExecutionId, String stepName) {
        return [
            SELECT Id, Name, copado__JobExecution__c
            FROM copado__JobStep__c
            WHERE copado__JobExecution__c = :jobExecutionId AND Name = :stepName
            LIMIT 1
        ];
    }

    private static copado__Result__c getResultByStep(Id jobStepId) {
        return [
            SELECT Id, Name, copado__Result_Data__c, copado__Error_Message__c, copado__JobStep__c, copado__Status__c
            FROM copado__Result__c
            WHERE copado__JobStep__c = :jobStepId
            LIMIT 1
        ];
    }

    private static copado__User_Story__c getUserStory() {
        return [SELECT Id FROM copado__User_Story__c LIMIT 1];
    }

    private static copado__JobExecution__c getJobExecution() {
        return [SELECT Id, copado__DataJson__c, copado__ErrorMessage__c FROM copado__JobExecution__c LIMIT 1];
    }

    private static Id getContentVersionId(String title, Id userStoryId) {
        return [SELECT Id FROM ContentVersion WHERE title = :title AND firstPublishLocationId = :userStoryId][0].Id;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String getChanges(List<String> actions, List<String> jsonInfo, List<String> names, List<String> types) {
        List<MetaDataItem> result = new List<MetaDataItem>();

        for(Integer index = 0 ; index < names.size() ; index++){
        MetaDataItem change = new MetaDataItem();
            change.a = actions[index];
            change.n = names[index];
            change.t = types[index];
        change.m = '';
        change.c = 'SFDX';
            change.j = jsonInfo[index];
        result.add(change);
        }

        return JSON.serialize(result);
    }

    private static void createCommitChangesFile(Id userStoryId, String content) {
        new ContentVersion_t()
            .title('Copado Commit Changes')
            .pathOnClient('Copado Commit Changes')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf(content))
            .persist();
    }

    private static void createSelectiveCommitFilesOnUS(Id userStoryId) {
        for (String filename : CommitFunctionCallback.SELECTIVE_COMMIT_HASH_SUFFIXES) {
            new ContentVersion_t()
                .title(HASH_FILE1 + filename)
                .pathOnClient(HASH_FILE1 + filename)
                .firstPublishLocationId(userStoryId)
                .versionData(Blob.valueOf('random file data'))
                .persist();

            new ContentVersion_t()
                .title(HASH_FILE2 + filename)
                .pathOnClient(HASH_FILE1 + filename)
                .firstPublishLocationId(userStoryId)
                .versionData(Blob.valueOf('random file data'))
                .persist();
        }

        new ContentVersion_t()
            .title(HASH_FILE1 + '_commit')
            .pathOnClient(HASH_FILE1 + '_commit')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('new commit file'))
            .persist();

        new ContentVersion_t()
            .title(HASH_FILE2 + '_commit')
            .pathOnClient(HASH_FILE2 + '_commit')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('Commit file for File 2'))
            .persist();

        new ContentVersion_t()
            .title(HASH_FILE2 + '_session')
            .pathOnClient(HASH_FILE2 + '_session')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('Session file for File 2'))
            .persist();

        new ContentVersion_t()
            .title(HASH_FILE3 + '_session')
            .pathOnClient(HASH_FILE3 + '_session')
            .firstPublishLocationId(userStoryId)
            .versionData(Blob.valueOf('Session file for File 3'))
            .persist();
    }
}