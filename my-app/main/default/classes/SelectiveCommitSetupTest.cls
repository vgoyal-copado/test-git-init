@IsTest
@SuppressWarnings('PMD.CognitiveComplexity')
private class SelectiveCommitSetupTest {
    private static final String SFDX_SELECTIVE_COMMIT_SETUP = 'SFDX_Selective_Commit_Setup_1';
    private static final String SFDX_BUNDLED_METADATA_SELECTIVE_COMMIT_SETUP = 'SFDX_Bundled_Metadata_Selective_Commit_Setup_1';
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION = 'cmcSf_SelectionsForBundledMetadata_session';
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT = 'cmcSf_SelectionsForBundledMetadata_commit';
    private static final String FILE_PREFIX = 'file-prefix';
    private static final String FILE_PATH_HASH = 'file-path-hash';
    private static Map<String, Id> latestFileVersionsByTitle = new Map<String, Id>();
    private static final String SOURCE = 'source';
    private static final String DESTINATION = 'destination';
    private static final String BASE = 'base';
    private static final String SESSION = 'session';
    private static final String FEATURE = 'feature';
    private static final String COMMIT_FILE = 'commit';

    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void execute() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            List<copado__JobExecution__c> jobExecutionsForSelectiveCommitSetup;

            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                0,
                jobExecutionsForSelectiveCommitSetup.size(),
                'There already exists job executions for the Selective Commit Setup template'
            );

            SelectiveCommitSetupPayload payload = getPayload('Layout:MyObject__c-MyLayout__c');
            Id pipelineId = getPipelineId('My Pipeline');
            Id sourceId = getEnvironmentId('dev');

            // EXERCISE
            Id jobExecutionId = SelectiveCommitSetup.execute(payload, pipelineId, sourceId);

            // VERIFY
            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                1,
                jobExecutionsForSelectiveCommitSetup.size(),
                'Could not find any job execution for the Selective Commit Setup template'
            );
            Assert.areEqual(jobExecutionsForSelectiveCommitSetup[0].Id, jobExecutionId, 'The job execution id retuned is incorrect');
            Assert.areEqual(
                pipelineId,
                jobExecutionsForSelectiveCommitSetup[0].copado__Pipeline__c,
                'The pipeline id on the job execution is incorrect'
            );
            Assert.areEqual(sourceId, jobExecutionsForSelectiveCommitSetup[0].copado__Source__c, 'The source id on the job execution is incorrect');
            Assert.areEqual(
                JSON.serializePretty(payload),
                jobExecutionsForSelectiveCommitSetup[0].copado__DataJson__c,
                'The datajson on the job execution is incorrect'
            );

            List<copado__JobStep__c> jobSteps = getJobSteps(jobExecutionId);
            Assert.areEqual(1, jobSteps.size(), 'Here only one job step should be present.');
            Assert.areEqual('SFDX Selective Commit Setup', jobSteps[0].Name, 'Here 1st job step should be SFDX Selective Commit Setup');
        }

    }

    @IsTest
    private static void executeForBundledMetadata() {
        System.runAs(TestUtilities.getRunAsUser()) {
            List<copado__JobExecution__c> jobExecutionsForSelectiveCommitSetup;

            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_BUNDLED_METADATA_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                0,
                jobExecutionsForSelectiveCommitSetup.size(),
                'There already exists job executions for the Selective Commit Bundled Metadata Setup template'
            );

            SelectiveCommitSetupPayload payload = getPayload('LightningComponentBundle:myLwc');
            Id pipelineId = getPipelineId('My Pipeline');
            Id sourceId = getEnvironmentId('dev');

            // EXERCISE
            Id jobExecutionId = SelectiveCommitSetup.execute(payload, pipelineId, sourceId);

            // VERIFY
            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_BUNDLED_METADATA_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                1,
                jobExecutionsForSelectiveCommitSetup.size(),
                'Could not find any job execution for the Selective Commit Bundled Metadata Setup template'
            );
            Assert.areEqual(jobExecutionsForSelectiveCommitSetup[0].Id, jobExecutionId, 'The job execution id retuned is incorrect');
            Assert.areEqual(
                pipelineId,
                jobExecutionsForSelectiveCommitSetup[0].copado__Pipeline__c,
                'The pipeline id on the job execution is incorrect'
            );
            Assert.areEqual(sourceId, jobExecutionsForSelectiveCommitSetup[0].copado__Source__c, 'The source id on the job execution is incorrect');
            Assert.areEqual(
                JSON.serializePretty(payload),
                jobExecutionsForSelectiveCommitSetup[0].copado__DataJson__c,
                'The datajson on the job execution is incorrect'
            );

            List<copado__JobStep__c> jobSteps = getJobSteps(jobExecutionId);
            Assert.areEqual(1, jobSteps.size(), 'Here only one job step should be present.');
            Assert.areEqual(
                'SFDX Selective Commit Bundled Metadata Setup',
                jobSteps[0].Name,
                'Here 1st job step should be SFDX Selective Commit Setup'
            );
        }

    }

    @IsTest
    private static void executeWithPreFetchEnabled() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            Id pipelineId = getPipelineId('My Pipeline');
            Id sourceId = getEnvironmentId('dev');

            new SystemProperty(new Pipeline().recordId(pipelineId)).apiName('PreFetchedRepository').value('true').persist();
            List<copado__JobExecution__c> jobExecutionsForSelectiveCommitSetup;

            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                0,
                jobExecutionsForSelectiveCommitSetup.size(),
                'There already exists job executions for the Selective Commit Setup template'
            );

            SelectiveCommitSetupPayload payload = getPayload('Layout:MyObject__c-MyLayout__c');

            // EXERCISE
            Id jobExecutionId = SelectiveCommitSetup.execute(payload, pipelineId, sourceId);

            // VERIFY
            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                1,
                jobExecutionsForSelectiveCommitSetup.size(),
                'Could not find any job execution for the Selective Commit Setup template'
            );
            Assert.areEqual(jobExecutionsForSelectiveCommitSetup[0].Id, jobExecutionId, 'The job execution id retuned is incorrect');
            Assert.areEqual(
                pipelineId,
                jobExecutionsForSelectiveCommitSetup[0].copado__Pipeline__c,
                'The pipeline id on the job execution is incorrect'
            );
            Assert.areEqual(sourceId, jobExecutionsForSelectiveCommitSetup[0].copado__Source__c, 'The source id on the job execution is incorrect');
            Assert.areEqual(
                JSON.serializePretty(payload),
                jobExecutionsForSelectiveCommitSetup[0].copado__DataJson__c,
                'The datajson on the job execution is incorrect'
            );

            List<copado__JobStep__c> jobSteps = getJobSteps(jobExecutionId);
            Assert.areEqual(2, jobSteps.size(), 'Here 2 job steps should be present with first step as PreFetch volume');
            Assert.areEqual('Use Prefetched Volume', jobSteps[0].Name, 'Here 1st step should be Use PreFetch Volume');
            Assert.areEqual('SFDX Selective Commit Setup', jobSteps[1].Name, 'Here 2nd job step should be SFDX Selective Commit Setup');
        }

    }

    @IsTest
    private static void executeWithSameRequestJobExecutionInProgress() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            SelectiveCommitSetupPayload payload = getPayload('Layout:MyObject__c-MyLayout__c');

            Id inProgressJobExecutionId = createJobExecution(
                getJobTemplateId(SFDX_SELECTIVE_COMMIT_SETUP),
                getEnvironmentId('dev'),
                getPipelineId('My Pipeline'),
                JSON.serializePretty(payload)
            );
            updateStatus(inProgressJobExecutionId, 'In Progress');

            List<copado__JobExecution__c> jobExecutionsForSelectiveCommitSetup;

            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                1,
                jobExecutionsForSelectiveCommitSetup.size(),
                'Could not find any job execution for the Selective Commit Setup template'
            );
            Id pipelineId = getPipelineId('My Pipeline');
            Id sourceId = getEnvironmentId('dev');

            // EXERCISE
            Id jobExecutionId = SelectiveCommitSetup.execute(payload, pipelineId, sourceId);

            // VERIFY
            jobExecutionsForSelectiveCommitSetup = getJobExecution(SFDX_SELECTIVE_COMMIT_SETUP);
            Assert.areEqual(
                1,
                jobExecutionsForSelectiveCommitSetup.size(),
                'Number of Job executions for the Selective Commit Setup template changed'
            );
            Assert.areEqual(inProgressJobExecutionId, jobExecutionId, 'The job execution id retuned is incorrect');
            Assert.areEqual(
                pipelineId,
                jobExecutionsForSelectiveCommitSetup[0].copado__Pipeline__c,
                'The pipeline id on the job execution is incorrect'
            );
            Assert.areEqual(sourceId, jobExecutionsForSelectiveCommitSetup[0].copado__Source__c, 'The source id on the job execution is incorrect');
            Assert.areEqual(
                JSON.serializePretty(payload),
                jobExecutionsForSelectiveCommitSetup[0].copado__DataJson__c,
                'The datajson on the job execution is incorrect'
            );
        }

    }

    @IsTest
    private static void getDestinationBranchForUserStory() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            Id pipelineId = getPipelineId('MY Pipeline');
            Id sourceEnvironmentId = getEnvironmentId('dev');

            // EXECUTE

            String destinationBranch = SelectiveCommitSetup.getDestinationBranchForUserStory(pipelineId, sourceEnvironmentId);

            // VERIFY

            Assert.areEqual('staging', destinationBranch, 'The destination branch returned is ' + destinationBranch + '  instead of staging');
        }
    }

    @IsTest
    private static void getJobExecutionDetails() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            Id jobExecutionId = createJobExecution(
                getJobTemplateId(SFDX_SELECTIVE_COMMIT_SETUP),
                getEnvironmentId('dev'),
                JSON.serialize(getPayload('Layout:MyObject__c-MyLayout__c'))
            );
            updateStatus(jobExecutionId, 'In Progress');

            // EXECUTE

            SelectiveCommitSetup.JobExecutionDetails response = SelectiveCommitSetup.getJobExecutionDetails(jobExecutionId);

            // VERIFY

            Assert.areEqual('In Progress', response.status, 'The status returned is ' + response.status + '  instead of In Progress');

            // EXERCISE

            updateStatus(jobExecutionId, 'Successful');
            response = SelectiveCommitSetup.getJobExecutionDetails(jobExecutionId);

            // VERIFY

            Assert.areEqual('Successful', response.status, 'The status returned is ' + response.status + '  instead of Successful');
        }
    }

    @IsTest
    private static void getEditorContentVersionIds() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            Id userStoryId = getUserStoryId('My User Story');
            List<String> titles = new List<String>{
                getFileName(SOURCE),
                getFileName(BASE),
                getFileName(DESTINATION),
                getFileName(FEATURE),
                getFileName(COMMIT_FILE)
            };

            List<Id> latestFileVersionIds = new List<Id>(getLatestFileVersions(userStoryId, titles).keySet());
            latestFileVersionIds.add(createNewSessionFile(userStoryId, getFileName(SESSION)));
            titles.add(getFileName(SESSION));

            // EXECUTE

            List<Id> editorContentVersionIds = SelectiveCommitSetup.getEditorContentVersionIds(userStoryId, titles);

            // VERIFY

            Assert.areEqual(
                6,
                editorContentVersionIds.size(),
                'The number of file ids returned is ' + editorContentVersionIds?.size() + ' instead of 6'
            );

            for (Id editorContentVersionId : editorContentVersionIds) {
                Assert.isTrue(
                    latestFileVersionIds.contains(editorContentVersionId),
                    'Could not find the version id : ' + editorContentVersionId + 'in latest versions list'
                );
            }
        }
    }

    @IsTest
    private static void getContentVersionIdsForBundleFileTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id userStoryId = getUserStoryId('My User Story');

            // EXERCISE
            List<Id> contentVersionIds = SelectiveCommitSetup.getContentVersionIdsForBundleFile(
                getSelectiveCommitBundledMetadataRequest(userStoryId)
            );

            // VERIFY
            Assert.areEqual(
                3,
                contentVersionIds.size(),
                'The number of content version ids returned is ' + contentVersionIds.size() + ' instead of 3'
            );
        }
    }

    @IsTest
    private static void saveSelectionsForBundledMetadataTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id userStoryId = getUserStoryId('My User Story');
            List<String> selectedFilePaths = new List<String>{ 'myLwc/myLwc.js-meta.xml', 'myLwc/myLwc.html', 'myLwc/myLwc.js' };
            String metadataTypeAndName = 'LightningComponentBundle:myLwc';

            // EXERCISE
            SelectiveCommitSetup.saveSelectionsForBundledMetadata(userStoryId, selectedFilePaths, metadataTypeAndName);

            // VERIFY
            List<ContentDocument> selectionsForBundledMetadata = getContentDocuments(new List<String>{ CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION });

            Assert.areEqual(selectionsForBundledMetadata.size(), 1, 'There should be only 1 content document with selections for bundled metadata');
            Map<String, List<String>> selections = (Map<String, List<String>>) JSON.deserialize(
                getFileContent(selectionsForBundledMetadata[0].Id),
                Map<String, List<String>>.class
            );

            Assert.areEqual(selections.size(), 2, 'There should be 2 selections for bundled metadata');
            Assert.areEqual(selections.containsKey(metadataTypeAndName), true, 'The new selection should be added to the file');
            Assert.areEqual(selections.containsKey('ExperienceBundle:myBundle'), true, 'The previous selections should be persisted in the file');
            Assert.areEqual(selections.get(metadataTypeAndName), selectedFilePaths, 'The new selection should show the correct selected file paths');
            Assert.areEqual(
                selections.get('ExperienceBundle:myBundle'),
                new List<String>{ 'file1', 'file2' },
                'The old selection should show the correct selected file paths'
            );
        }
    }

    @IsTest
    private static void getSelectionsForBundledMetadataTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id userStoryId = getUserStoryId('My User Story');
            List<String> selectedFilePaths = new List<String>{ 'myLwc/myLwc.js-meta.xml', 'myLwc/myLwc.html', 'myLwc/myLwc.js' };
            String metadataTypeAndName = 'LightningComponentBundle:myLwc';
            String previouslyCommittedMetadata = 'LightningComponentBundle:testLWC';
            SelectiveCommitSetup.saveSelectionsForBundledMetadata(userStoryId, selectedFilePaths, metadataTypeAndName);

            // WHEN

            Map<String, String> result = SelectiveCommitSetup.getSelectionsForBundledMetadata(userStoryId);
            // VERIFY

            for(String title : result.keySet()){
                if(title == CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION) {
                    Map<String, List<String>> fileContent = (Map<String, List<String>>) JSON.deserialize(result.get(title), Map<String, List<String>>.class);
                    Assert.areEqual(fileContent.size(), 2, 'There should be 2 selections for bundled metadata');
                    Assert.areEqual(fileContent.containsKey(metadataTypeAndName), true, 'The selection should be fetched from the file');
                    Assert.areEqual(fileContent.containsKey('ExperienceBundle:myBundle'), true, 'The selection should be fetched from the file');
                    Assert.areEqual(fileContent.get(metadataTypeAndName), selectedFilePaths, 'The selection should be fetched from the file');
                    Assert.areEqual(
                        fileContent.get('ExperienceBundle:myBundle'),
                        new List<String>{ 'file1', 'file2' },
                        'The selection should be fetched from the file'
                    );

                }

                if(title == CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT) {
                    Map<String, List<String>> fileContent = (Map<String, List<String>>) JSON.deserialize(result.get(title), Map<String, List<String>>.class);
                    Assert.areEqual(fileContent.size(), 1, 'There should be 1 selections for bundled metadata');
                    Assert.areEqual(fileContent.containsKey(previouslyCommittedMetadata), true, 'The selection should be fetched from the file');
                    Assert.areEqual(fileContent.containsKey('LightningComponentBundle:testLWC'), true, 'The selection should be fetched from the file');
                    Assert.areEqual(
                        fileContent.get('LightningComponentBundle:testLWC'),
                        new List<String>{ 'path1', 'path2' },
                        'The selection should be fetched from the file'
                    );

                }
            }
        }
    }

    private static Id createJobExecution(Id templateId, Id sourceEvironmentId, String dataJson) {
        JobTemplate jobTemplate = new JobTemplate().recordId(templateId);
        Environment sourceEnvironment = new Environment().recordId(sourceEvironmentId);
        copado__JobExecution__c jobExecution = (copado__JobExecution__c) new JobExecution(jobTemplate)
            .source(sourceEnvironment)
            .dataJSON(dataJson)
            ?.persist();
        return jobExecution.Id;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static Id createJobExecution(Id templateId, Id sourceEvironmentId, Id pipelineId, String dataJson) {
        JobTemplate jobTemplate = new JobTemplate().recordId(templateId);
        Environment sourceEnvironment = new Environment().recordId(sourceEvironmentId);
        Pipeline pipeline = new Pipeline().recordId(pipelineId);
        copado__JobExecution__c jobExecution = (copado__JobExecution__c) new JobExecution(jobTemplate)
            .source(sourceEnvironment)
            .dataJSON(dataJson)
            .pipeline(pipeline)
            ?.persist();
        return jobExecution.Id;
    }

    private static void updateStatus(Id jobExecutionId, String status) {
        update new copado__JobExecution__c(Id = jobExecutionId, copado__Status__c = status);
    }

    private static SelectiveCommitSetupPayload getPayload(String metadataTypeAndName) {
        SelectiveCommitSetupPayload result = new SelectiveCommitSetupPayload();
        result.baseBranch = 'main';
        result.destinationBranch = 'staging';
        result.featureBranch = 'feature/US-00001';
        result.filePrefix = FILE_PREFIX;
        result.metadataTypeAndName = metadataTypeAndName;
        result.userStoryId = getUserStoryId('My User Story');
        return result;
    }

    private static Id getUserStoryId(String name) {
        return [SELECT Id FROM copado__User_Story__c WHERE copado__User_Story_Title__c = :name LIMIT 1].Id;
    }

    private static Id getPipelineId(String name) {
        return [SELECT Id FROM copado__Deployment_Flow__c WHERE Name = :name LIMIT 1].Id;
    }

    private static Id getEnvironmentId(String name) {
        return [SELECT Id FROM copado__Environment__c WHERE Name = :name LIMIT 1].Id;
    }

    private static Id getJobTemplateId(String name) {
        return [SELECT Id FROM copado__JobTemplate__c WHERE copado__ApiName__c = :name LIMIT 1].Id;
    }
    private static List<copado__JobExecution__c> getJobExecution(String templateName) {
        return [
            SELECT Id, copado__Pipeline__c, copado__Source__c, copado__DataJson__c
            FROM copado__JobExecution__c
            WHERE copado__Template__r.copado__ApiName__c = :templateName
        ];
    }

    private static List<copado__JobStep__c> getJobSteps(Id jobExecutionId) {
        return [
            SELECT Name, copado__JobExecution__c, copado__Order__c
            FROM copado__JobStep__c
            WHERE copado__JobExecution__c = :jobExecutionId
            ORDER BY copado__Order__c
        ];
    }

    private static void createData() {
        JobTemplate jobTemplate = new JobTemplate().name('SFDX Selective Commit Setup').apiName(SFDX_SELECTIVE_COMMIT_SETUP).type('Custom');
        new JobStep(jobTemplate).name('SFDX Selective Commit Setup').type('Function');

        JobTemplate jobTemplateForBundledMetadata = new JobTemplate()
            .name('SFDX Bundled Metadata Selective Commit Setup')
            .apiName(SFDX_BUNDLED_METADATA_SELECTIVE_COMMIT_SETUP)
            .type('Custom');
        new JobStep(jobTemplateForBundledMetadata).name('SFDX Selective Commit Bundled Metadata Setup').type('Function');

        Environment dev = new Environment().name('dev').platform('SFDX');
        Environment staging = new Environment().name('staging').platform('SFDX');
        Credential devAuth = new Credential(dev);
        new Credential(staging);

        Repository repository = new Repository().name('My Repo');
        Project project = new Project().name('My Project');
        Pipeline pipeline = new Pipeline().name('My Pipeline').platform('SFDX').add(project).repository(repository);
        new PipelineConnection().sourceEnvironment(dev).destinationEnvironment(staging).branch('dev').destinationBranch('staging').pipeline(pipeline);

        copado__User_Story__c userStory = (copado__User_Story__c) new UserStory()
            .title('My User Story')
            .credential(devAuth)
            .project(project)
            .persist();

        new ContentVersion_t()
            .title(getFileName(SOURCE))
            .pathOnClient(getFileName(SOURCE))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('source content'));
        new ContentVersion_t()
            .title(getFileName(BASE))
            .pathOnClient(getFileName(BASE))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('base branch content'));
        new ContentVersion_t()
            .title(getFileName(DESTINATION))
            .pathOnClient(getFileName(DESTINATION))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('destination branch content'));
        new ContentVersion_t()
            .title(getFileName(FEATURE))
            .pathOnClient(getFileName(FEATURE))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('feature branch content'));
        new ContentVersion_t()
            .title(getFileName(SESSION))
            .pathOnClient(getFileName(SESSION))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('session file content'));
        new ContentVersion_t()
            .title(getFileName(COMMIT_FILE))
            .pathOnClient(getFileName(COMMIT_FILE))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('commit file content'));
        new ContentVersion_t()
            .title(getFileNameForBundledMetadata(SOURCE))
            .pathOnClient(getFileNameForBundledMetadata(SOURCE))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('source file content'));
        new ContentVersion_t()
            .title(getFileNameForBundledMetadata(BASE))
            .pathOnClient(getFileNameForBundledMetadata(BASE))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('source file content'));
        new ContentVersion_t()
            .title(getFileNameForBundledMetadata(FEATURE))
            .pathOnClient(getFileNameForBundledMetadata(FEATURE))
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf('feature file content'));

        new ContentVersion_t()
            .title(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .pathOnClient(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION + '.json')
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf(getSessionSelectionsForBundledMetadata()))
            .persist();

        new ContentVersion_t()
            .title(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT)
            .pathOnClient(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT + '.json')
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf(getPreviousSelectionsForBundledMetadata()))
            .persist();
    }

    private static String getFileName(String suffix) {
        return FILE_PREFIX + '_' + suffix;
    }

    private static String getFileNameForBundledMetadata(String suffix) {
        return FILE_PREFIX + '_' + FILE_PATH_HASH + '_' + suffix;
    }

    private static Id createNewSessionFile(Id userStoryId, String fileName) {
        ContentVersion sessionFileVersion = (ContentVersion) new ContentVersion_t()
            .title(fileName)
            .pathOnClient(fileName)
            .versionData(Blob.valueOf('updated session file content'))
            .firstPublishLocationId(userStoryId)
            ?.persist();
        return sessionFileVersion.Id;
    }

    private static Map<Id, ContentVersion> getLatestFileVersions(Id userStoryId, List<String> titles) {
        return new Map<Id, ContentVersion>(
            new ContentVersionsSelector().byFirstPublishLocationIdAndTitleAndIsLatest(new Set<Id>{ userStoryId }, titles)
        );
    }

    private static SelectiveCommitBundledMetadataRequest getSelectiveCommitBundledMetadataRequest(Id userStoryId) {
        SelectiveCommitBundledMetadataRequest result = new SelectiveCommitBundledMetadataRequest();
        result.filePathHash = FILE_PATH_HASH;
        result.filePrefix = FILE_PREFIX;
        result.userStoryId = userStoryId;
        return result;
    }

    private static String getSessionSelectionsForBundledMetadata() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('ExperienceBundle:myBundle', new List<String>{ 'file1', 'file2' });
        return JSON.serialize(result);
    }

    private static String getPreviousSelectionsForBundledMetadata() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('LightningComponentBundle:testLWC', new List<String>{ 'path1', 'path2' });
        return JSON.serialize(result);
    }

    private static List<ContentDocument> getContentDocuments(List<String> titles) {
        return [SELECT Id, Title FROM ContentDocument WHERE Title IN :titles];
    }

    private static String getFileContent(Id contentDocumentId) {
        String result = '';
        List<ContentVersion> contentVersions = [
            SELECT ID, ContentDocumentId, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
        ];
        if (contentVersions.size() > 0) {
            result = contentVersions[0].VersionData?.toString();
        }
        return result;
    }
}