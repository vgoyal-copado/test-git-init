@IsTest
private class DeleteObsoleteFilesOnPromotionTest {
    private static final String SUCCESS_STATUS = 'Success';
    private static final String ERROR_MESSAGE = 'Test Error Message';
    private static final String COPADO_ROLLBACK_CHANGES = 'Copado Rollback Changes';
    private static final String COPADO_VLOCITY_ROLLBACK_CHANGES = 'Copado Vlocity Rollback changes';
    private static final String PROMOTIN_US_MERGE_ORDER = 'promotion_us_merge_order.json';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void testExecuteWithValidData() {
        // Setup
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__Result__c result = getResult();

            Assert.areEqual(2, getContentVersion(COPADO_ROLLBACK_CHANGES).size(), 'There should be 2 ' + COPADO_ROLLBACK_CHANGES + ' files');
            Assert.areEqual(
                2,
                getContentVersion(COPADO_VLOCITY_ROLLBACK_CHANGES).size(),
                'There should be 2 ' + COPADO_VLOCITY_ROLLBACK_CHANGES + ' files'
            );
            Assert.areEqual(2, getContentVersion(PROMOTIN_US_MERGE_ORDER).size(), 'There should be 2 ' + PROMOTIN_US_MERGE_ORDER + ' files');

            DeleteObsoleteFilesOnPromotion.Request request = new DeleteObsoleteFilesOnPromotion.Request();
            request.resultId = result.Id;

            // Exercise
            Test.startTest();
            DeleteObsoleteFilesOnPromotion.execute(new List<DeleteObsoleteFilesOnPromotion.Request>{ request });
            Test.stopTest();

            // Verify
            copado__JobExecution__c updatedJobExecution = [
                SELECT copado__ErrorMessage__c
                FROM copado__JobExecution__c
                LIMIT 1
            ];
            System.assertEquals(null, updatedJobExecution.copado__ErrorMessage__c, 'No error message should be set for successful execution');
            Assert.areEqual(1, getContentVersion(COPADO_ROLLBACK_CHANGES).size(), 'There should be 1 ' + COPADO_ROLLBACK_CHANGES + ' file');
            Assert.areEqual(
                1,
                getContentVersion(COPADO_VLOCITY_ROLLBACK_CHANGES).size(),
                'There should be 1 ' + COPADO_VLOCITY_ROLLBACK_CHANGES + ' file'
            );
            Assert.areEqual(1, getContentVersion(PROMOTIN_US_MERGE_ORDER).size(), 'There should be 1 ' + PROMOTIN_US_MERGE_ORDER + ' file');
        }

    }

    @IsTest
    static void testExecuteWithInvalidResult() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            DeleteObsoleteFilesOnPromotion.Request request = new DeleteObsoleteFilesOnPromotion.Request();
            request.resultId = null;

            // Exercise
            Test.startTest();
            DeleteObsoleteFilesOnPromotion.execute(new List<DeleteObsoleteFilesOnPromotion.Request>{ request });
            Test.stopTest();

            // Verify no changes were made due to invalid data
            copado__JobExecution__c jobExecution = [
                SELECT copado__ErrorMessage__c
                FROM copado__JobExecution__c
                LIMIT 1
            ];
            Assert.areEqual(null, jobExecution.copado__ErrorMessage__c, 'No error message should be set for invalid result');
        }
    }

    // PRIVATE
    private static void createData() {
        Environment sourceEnv = new Environment();
        Environment destinationEnv = new Environment();
        Credential sourceCred = new Credential(sourceEnv);
        Credential destinationCred = new Credential(destinationEnv);
        new Promotion(
            new Project(new Pipeline(new Repository().name('Repo 1')).platform('SFDX')),
            sourceCred,
            sourceEnv,
            destinationCred,
            destinationEnv
        );

        JobTemplate jobTemplate = new JobTemplate().name('SFDX Deploy').type('Custom');
        JobStep jobStep = new JobStep(jobTemplate).name('SFDX Deploy').type('Function');
        DataJson dataJson = new DataJson();
        dataJson.deploymentDryRun = false;
        new JobExecution(jobTemplate, destinationEnv).add(jobStep).dataJSON(JSON.serialize(dataJson));
        new Result(jobStep).type('Integration').status('Success').persist();

        copado__Deployment__c deployment = createDeployment();
        addDeploymentOnJobExecution(deployment);
        addFilesOnPromotion();
    }

    private static copado__Deployment__c createDeployment() {
        copado__Promotion__c promotion = [SELECT Id FROM copado__Promotion__c LIMIT 1];
        copado__Deployment__c deployment = new copado__Deployment__c();
        deployment.copado__Promotion__c = promotion.Id;
        insert deployment;
        return deployment;
    }

    private static void addDeploymentOnJobExecution(copado__Deployment__c deployment) {
        copado__JobExecution__c jobExecution = [SELECT Id FROM copado__JobExecution__c LIMIT 1];
        jobExecution.copado__Deployment__c = deployment.Id;
        update jobExecution;
    }

    private static void addFilesOnPromotion() {
        copado__Promotion__c promotion = getPromotion();

        new ContentVersion_t()
            .title(COPADO_ROLLBACK_CHANGES)
            .pathOnClient(COPADO_ROLLBACK_CHANGES + '.json')
            .firstPublishLocationId(promotion.Id)
            .versionData(getRollbackContent())
            .persist();

        new ContentVersion_t()
            .title(COPADO_ROLLBACK_CHANGES)
            .pathOnClient(COPADO_ROLLBACK_CHANGES + '.json')
            .firstPublishLocationId(promotion.Id)
            .versionData(getRollbackContent())
            .persist();

        new ContentVersion_t()
            .title(COPADO_VLOCITY_ROLLBACK_CHANGES)
            .pathOnClient(COPADO_VLOCITY_ROLLBACK_CHANGES + '.json')
            .firstPublishLocationId(promotion.Id)
            .versionData(getVlocityRollbackContent())
            .persist();

        new ContentVersion_t()
            .title(COPADO_VLOCITY_ROLLBACK_CHANGES)
            .pathOnClient(COPADO_VLOCITY_ROLLBACK_CHANGES + '.json')
            .firstPublishLocationId(promotion.Id)
            .versionData(getVlocityRollbackContent())
            .persist();

        new ContentVersion_t()
            .title(PROMOTIN_US_MERGE_ORDER)
            .pathOnClient(PROMOTIN_US_MERGE_ORDER + '.json')
            .firstPublishLocationId(promotion.Id)
            .versionData(getPromotionUSMergeOrder())
            .persist();

        new ContentVersion_t()
            .title(PROMOTIN_US_MERGE_ORDER)
            .pathOnClient(PROMOTIN_US_MERGE_ORDER + '.json')
            .firstPublishLocationId(promotion.Id)
            .versionData(getPromotionUSMergeOrder())
            .persist();
    }

    private static Blob getRollbackContent() {
        List<TestUtilities.RollbackChanges> content = new List<TestUtilities.RollbackChanges>();
        content.add(new TestUtilities.RollbackChanges('Test1', 'ApexClass', 'Delete', 'SFDX', false, true, false));
        content.add(new TestUtilities.RollbackChanges('Test2', 'ApexClass', 'Delete', 'SFDX', false, true, false));
        return Blob.valueOf(JSON.serialize(content));
    }

    private static Blob getVlocityRollbackContent() {
        List<TestUtilities.RollbackChanges> content = new List<TestUtilities.RollbackChanges>();
        content.add(new TestUtilities.RollbackChanges('Test1', 'DataRaptor', 'Update', 'Vlocity', false, true, false));
        content.add(new TestUtilities.RollbackChanges('Test2', 'DataRaptor', 'Update', 'Vlocity', false, true, false));
        return Blob.valueOf(JSON.serialize(content));
    }

    private static copado__Result__c getResult() {
        return [SELECT Id FROM copado__Result__c LIMIT 1];
    }

    private static copado__Promotion__c getPromotion() {
        return [SELECT Id FROM copado__Promotion__c LIMIT 1];
    }

    private static List<ContentDocumentLink> getContentDocumentLink(String title, Id entityId) {
        return [SELECT ContentDocumentId FROM ContentDocumentLink WHERE ContentDocument.Title = :title AND LinkedEntityId = :entityId];
    }

    private static List<ContentVersion> getContentVersion(String title) {
        return [SELECT ContentDocumentId, Title FROM ContentVersion WHERE Title = :title];
    }

    private static Blob getPromotionUSMergeOrder() {
        PromotionUSMergeOrder result = new PromotionUSMergeOrder();
        result.deploymentDate = Datetime.now();
        result.usMergeOrder = new List<String>{ 'US-00001', 'US-00002' };
        return Blob.valueOf(JSON.serialize(result));
    }

    // PRIVATE

    private class PromotionUSMergeOrder {
        public List<String> usMergeOrder;
        public Datetime deploymentDate;
    }

    private class DataJson {
        public Boolean deploymentDryRun;
    }
}