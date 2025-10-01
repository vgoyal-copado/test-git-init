@IsTest
private class RollbackDeploymentExtraFlagsTest {
    private static final String EXTRA_FLAGS = '--ignore-warnings';
    private static final String TEST_FILE_DATA = '[{"a":"Add"},{"a":"Delete"}]';
    private static final String TEST_FILE_DATA_NO_DELETE = '[{"a":"Add"},{"a":"Update"}]';

    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void testWithDestructiveChanges() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            setupContentVersion(TEST_FILE_DATA);
            Id jobStepId = [SELECT Id FROM copado__JobStep__c LIMIT 1].Id;

            // EXERCISE
            String result = new RollbackDeploymentExtraFlags().execute(jobStepId);

            // VERIFY
            Assert.areEqual('', result, 'Should return empty string when destructive changes are present');
        }
    }

    @IsTest
    private static void testWithoutDestructiveChanges() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            setupContentVersion(TEST_FILE_DATA_NO_DELETE);
            Id jobStepId = [SELECT Id FROM copado__JobStep__c LIMIT 1].Id;

            // EXERCISE
            String result = new RollbackDeploymentExtraFlags().execute(jobStepId);

            // VERIFY
            Assert.areEqual(EXTRA_FLAGS, result, 'Should return empty string when destructive changes are present');
        }
    }

    @IsTest
    private static void testWithoutDestructiveChangesDontIgnoreWarnings() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            setupContentVersion(TEST_FILE_DATA_NO_DELETE);
            Id jobStepId = [SELECT Id FROM copado__JobStep__c LIMIT 1].Id;
            copado__Promotion__c promotion = [SELECT Id FROM copado__Promotion__c LIMIT 1];
            promotion.Ignore_Rollback_Deployment_Warnings__c = false;
            update promotion;

            // EXERCISE
            String result = new RollbackDeploymentExtraFlags().execute(jobStepId);

            // VERIFY
            Assert.areEqual('', result, 'Should return empty string when no destructive changes and warnings not ignored');
        }
    }

    private static void setupContentVersion(String fileData) {
        // Create ContentVersion record
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Copado Rollback Changes',
            PathOnClient = 'Copado Rollback Changes.json',
            VersionData = Blob.valueOf(fileData),
            IsMajorVersion = true
        );
        insert contentVersion;

        Id documentId = [SELECT Id FROM ContentVersion WHERE Id = :contentVersion.Id].Id;

        copado__JobExecution__c jobExecution = [SELECT Id, copado__DataJson__c FROM copado__JobExecution__c LIMIT 1];
        RollbackDeploymentExtraFlags.JobExecutionData jobExecutionData = (RollbackDeploymentExtraFlags.JobExecutionData) JSON.deserialize(
            jobExecution.copado__DataJson__c,
            RollbackDeploymentExtraFlags.JobExecutionData.class
        );
        jobExecutionData.rollbackFileId = documentId;
        jobExecution.copado__DataJson__c = JSON.serialize(jobExecutionData);
        update jobExecution;
    }

    // PRIVATE
    private static void createData() {
        Project project = new Project();

        Environment sourceEnv = new Environment();
        Environment destinationEnv = new Environment();
        Credential sourceCred = new Credential(sourceEnv);
        Credential destinationCred = new Credential(destinationEnv);

        Pipeline pipeline = new Pipeline()
            .name('MyPipeline')
            .platform('SFDX')
            .repository(new Repository())
            .add(project)
            .add(new PipelineConnection().sourceEnvironment(sourceEnv).destinationEnvironment(destinationEnv));
        pipeline.persist();

        copado__Promotion__c promotion = new copado__Promotion__c();
        promotion.copado__Destination_Environment__c = destinationEnv.id;
        promotion.copado__Destination_Org_Credential__c = destinationCred.id;
        promotion.copado__Source_Environment__c = sourceEnv.id;
        promotion.copado__Source_Org_Credential__c = sourceCred.id;
        promotion.copado__Project__c = project.id;
        promotion.Ignore_Rollback_Deployment_Warnings__c = true;
        insert promotion;

        String promotionName = [SELECT Name FROM copado__Promotion__c WHERE Id = :promotion.Id LIMIT 1].Name;

        JobTemplate jobTemplate = new JobTemplate().name('Rollback').type('Custom').apiName('Rollback');
        JobStep jobStep = new JobStep(jobTemplate).name('Rollback').type('Function');
        String dataJson = JSON.serialize(new Map<String, String>{ 'promotion' => promotionName, 'rollbackFileId' => 'dummy-id' });
        new JobExecution(jobTemplate, destinationEnv).pipeline(pipeline).source(sourceEnv).dataJSON(dataJson).add(jobStep).persist();
    }
}