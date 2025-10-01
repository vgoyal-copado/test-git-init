@IsTest
private class GetSelectionsForBundledMetadataTest {
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION = 'cmcSf_SelectionsForBundledMetadata_session';
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT = 'cmcSf_SelectionsForBundledMetadata_commit';
    private static final String SFDX_BUNDLED_METADATA_SELECTIVE_COMMIT_SETUP = 'SFDX_Bundled_Metadata_Selective_Commit_Setup_1';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void executeWithSelectionsFileOnUserStory() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            Id jobExecutionId = createJobExecution(
                getJobTemplateId('SFDX_Commit_1'),
                getEnvironmentId('dev'),
                getPipelineId('My Pipeline'),
                getPayload()
            );

            // WHEN

            String result = new GetSelectionsForBundledMetadata().execute(getJobStepId(jobExecutionId));

            // THEN

            Set<Id> selectionsFile = getFiles(new List<String>{CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION, CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT});

            for(Id fileId : selectionsFile) {
                Assert.isTrue(result.contains(fileId),'The contentversion id returned by the dynamic expression is ' + result + 'instead of ' + fileId);
            }
        }

    }

    @IsTest
    private static void executeWithoutAnySelectionsFile() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            deleteFile(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION, getUserStoryId('My User Story'));

            Id jobExecutionId = createJobExecution(
                getJobTemplateId('SFDX_Commit_1'),
                getEnvironmentId('dev'),
                getPipelineId('My Pipeline'),
                getPayload()
            );

            // WHEN

            String result = new GetSelectionsForBundledMetadata().execute(getJobStepId(jobExecutionId));

            // THEN
            Set<Id> selectionsFile = getFiles(new List<String>{CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT});
            for(Id fileId : selectionsFile) {
                Assert.isTrue(result.contains(fileId),'The contentversion id returned by the dynamic expression is ' + result + 'instead of ' + fileId);
            }
        }

    }

    @IsTest
    private static void executeWithInvalidJobStepId() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            createJobExecution(
                getJobTemplateId('SFDX_Commit_1'),
                getEnvironmentId('dev'),
                getPipelineId('My Pipeline'),
                getPayload()
            );

            // WHEN

            String result = new GetSelectionsForBundledMetadata().execute(fflib_IDGenerator.generate(copado__JobStep__c.SObjectType));

            // THEN

            Assert.areEqual('', result, 'The contentversion id returned by the dynamic expression is ' + result + 'instead of blank');
        }

    }

    private static void createData() {
        JobTemplate jobTemplate = new JobTemplate().name('SFDX Commit').apiName('SFDX_Commit').type('Custom');
        new JobStep(jobTemplate).name('Commit').type('Function');

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
            .title(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .pathOnClient(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION)
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf(getSelectionsForBundledMetadata()))
            .persist();
        new ContentVersion_t()
            .title(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT)
            .pathOnClient(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT)
            .firstPublishLocationId(userStory.Id)
            .versionData(Blob.valueOf(getSelectionsForBundledMetadata()))
            .persist();
    }

    private static String getSelectionsForBundledMetadata() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        result.put('LightningComponentBundle:myLwc', new List<String>{ 'test1', 'test2' });
        result.put('ExperienceBundle:myBundle', new List<String>{ 'sampleFile1', 'sampleFile2' });
        return JSON.serialize(result);
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static Id createJobExecution(Id templateId, Id sourceEvironmentId, Id pipelineId, String dataJson) {
        JobTemplate jobTemplate = new JobTemplate().recordId(templateId);
        Environment sourceEnvironment = new Environment().recordId(sourceEvironmentId);
        Pipeline pipeline = new Pipeline().recordId(pipelineId);
        JobExecution jobExecution = new JobExecution(jobTemplate).source(sourceEnvironment).dataJSON(dataJson).pipeline(pipeline);

        new JobStep().execution(jobExecution).name('Commit').type('Function').persist();

        return jobExecution.Id;
    }

    private static Id getUserStoryId(String name) {
        return [SELECT Id FROM copado__User_Story__c WHERE copado__User_Story_Title__c = :name LIMIT 1].Id;
    }

    private static Set<Id> getFiles(List<String> titles) {
        return new Map<Id, ContentVersion>([SELECT Id FROM ContentVersion WHERE Title IN :titles]).keySet();
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

    private static Id getJobStepId(Id jobExecutionId) {
        return [SELECT Id FROM copado__JobStep__c WHERE copado__JobExecution__c = :jobExecutionId LIMIT 1].Id;
    }

    private static String getPayload() {
        JobExecutionPayload result = new JobExecutionPayload();
        result.userStoryId = getUserStoryId('My User Story');
        return JSON.serializePretty(result);
    }

    private static void deleteFile(String fileName, String recordId) {
        List<ContentVersion> contentVersions = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE FirstPublishLocationId = :recordId AND Title = :fileName
        ];
        if (!contentVersions.isEmpty()) {
            delete [SELECT Id FROM ContentDocument WHERE Id = :contentVersions[0].ContentDocumentId];
        }
    }

    private class JobExecutionPayload {
        public String userStoryId;
    }
}