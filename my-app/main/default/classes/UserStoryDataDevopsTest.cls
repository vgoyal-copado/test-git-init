@IsTest
private class UserStoryDataDevopsTest {
    private static final String ENABLE_DATA_DEPLOY_DEVOPS = 'enable_data_deploy_devops';
    private static final String RETRIEVED_DATA_FILE_NAME = 'records_with_related_dependencies.json';
    private static final String DATA_RETRIEVE_TEMPLATE = 'SFDX_Data_Devops_Retrieve';
    private static final String DATA_DEVOPS_PERMISSION_SET = 'Data_Deploy_DevOps_User';
    private static final String DATA_CONFIG_FILE = 'DataDeployDevOpsConfiguration.json';
    private static final String MASTERLIST_RETRIEVE_TEMPLATE = 'SFDX_Data_Devops_Masterlist_Retrieve';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void dataDevopsTabDisabled() {
        System.runAs(TestUtilities.getRunAsUser()) {
            createSystemProperties(getPipelineObj(), 'false', ENABLE_DATA_DEPLOY_DEVOPS).persist();

            Test.startTest();
            UserStoryDataDevops.Response result = UserStoryDataDevops.checkDataDevopsEnablement(getUserStory().Id);
            Test.stopTest();

            Assert.isFalse(result.tabEnabled, 'Data Devops should be disabled');
        }
    }

    @IsTest
    private static void dataDevopsContentEnabled() {
        System.runAs(TestUtilities.getRunAsUser()) {
            assignPermissionSet();
            createSystemProperties(getPipelineObj(), 'true', ENABLE_DATA_DEPLOY_DEVOPS).persist();

            Test.startTest();
            UserStoryDataDevops.Response result = UserStoryDataDevops.checkDataDevopsEnablement(getUserStory().Id);
            Test.stopTest();

            Assert.isTrue(result.tabEnabled, 'Data Devops should be enabled');
        }
    }

    @IsTest
    private static void testExecuteDataRetrieve() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c userStory = getUserStory();
            String payload = '{"sObjects":[{"sobject":"Account"}]}';

            Test.startTest();
            UserStoryDataDevops.Response result = UserStoryDataDevops.executeDataRetrieve(userStory.Id, userStory.copado__Org_Credential__c, payload);
            Test.stopTest();

            Assert.isNotNull(result.copadoJobId, 'Job Id should be returned');
        }
    }

    @IsTest
    private static void testCheckDataJobExecutionStatus() {
        System.runAs(TestUtilities.getRunAsUser()) {
            JobTemplate jobTemplate = getTemplateObj();
            JobStep jobStep = new JobStep().name('step1').type('Function').order(1);
            JobExecution jobExecution = new JobExecution(jobTemplate).add(jobStep);
            new Result(jobStep).type('Function').status('Success').persist();

            Test.startTest();
            copado__Result__c status = UserStoryDataDevops.checkDataJobExecutionStatus(jobExecution.Id);
            Test.stopTest();

            Assert.areEqual('Success', status.copado__Status__c, 'Status should match');
        }
    }

    @IsTest
    private static void testGetDataDevopsAttachmentByName() {
        System.runAs(TestUtilities.getRunAsUser()) {
            String userStoryId = getUserStory().Id;
            JobTemplate jobTemplate = getTemplateObj();
            JobStep jobStep = new JobStep().name('step1').type('Function').order(1);
            JobExecution jobExecution = new JobExecution(jobTemplate).add(jobStep);
            new Result(jobStep).type('Function').status('Success').data('{"deploymentId":"TEST_DEPLOYMENT","sourceSessionUrl":""}').persist();

            new Attachment_t().name('TEST_DEPLOYMENT_' + RETRIEVED_DATA_FILE_NAME).body(Blob.valueOf('Test Content')).parent(userStoryId).persist();

            Test.startTest();
            String content = UserStoryDataDevops.getDataDevopsFileByName(userStoryId, jobExecution.Id);
            Test.stopTest();

            Assert.areEqual('Test Content', content, 'File content should match');
        }
    }

    @IsTest
    private static void testDeleteOldAttachments() {
        System.runAs(TestUtilities.getRunAsUser()) {
            String userStoryId = getUserStory().Id;
            new Attachment_t().name('OLD_' + RETRIEVED_DATA_FILE_NAME).body(Blob.valueOf('Old Content')).parent(userStoryId).persist();

            Test.startTest();
            UserStoryDataDevops.deleteOldFiles(userStoryId);
            Test.stopTest();

            List<Attachment> remainingAttachments = [
                SELECT Id
                FROM Attachment
                WHERE ParentId = :userStoryId
            ];

            Assert.areEqual(0, remainingAttachments.size(), 'All files should be deleted');
        }
    }

    @IsTest
    private static void testGetDataDevopsFileByName() {
        System.runAs(TestUtilities.getRunAsUser()) {
            String userStoryId = getUserStory().Id;
            JobTemplate jobTemplate = getTemplateObj();
            JobStep jobStep = new JobStep().name('step1').type('Function').order(1);
            JobExecution jobExecution = new JobExecution(jobTemplate).add(jobStep);
            new Result(jobStep).type('Function').status('Success').data('{"deploymentId":"TEST_DEPLOYMENT","sourceSessionUrl":""}').persist();

            new ContentVersion_t()
                .title('TEST_DEPLOYMENT_' + RETRIEVED_DATA_FILE_NAME)
                .pathOnClient('TEST_DEPLOYMENT_' + RETRIEVED_DATA_FILE_NAME)
                .versionData(Blob.valueOf('Test Content'))
                .firstPublishLocationId(userStoryId)
                .persist();

            Test.startTest();
            String content = UserStoryDataDevops.getDataDevopsFileByName(userStoryId, jobExecution.Id);
            Test.stopTest();

            Assert.areEqual('Test Content', content, 'File content should match');
        }
    }

    @IsTest
    private static void testDeleteOldFiles() {
        System.runAs(TestUtilities.getRunAsUser()) {
            String userStoryId = getUserStory().Id;
            new ContentVersion_t()
                .title('OLD_' + RETRIEVED_DATA_FILE_NAME)
                .pathOnClient('OLD_' + RETRIEVED_DATA_FILE_NAME)
                .versionData(Blob.valueOf('Test Content'))
                .firstPublishLocationId(userStoryId)
                .persist();

            Test.startTest();
            UserStoryDataDevops.deleteOldFiles(userStoryId);
            Test.stopTest();

            List<ContentDocumentLink> remainingLinks = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :userStoryId
            ];

            Assert.areEqual(1, remainingLinks.size(), 'All files should be deleted');
        }
    }

    @IsTest
    private static void getMasterListFromDocumentTestSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            String userStoryId = getUserStory().Id;

            Test.startTest();
            String result = UserStoryDataDevops.getMasterListFromDocument(userStoryId);
            Test.stopTest();

            String masterListContent = '{"sObjects":[{"sobject":"Account","displayLabel":"Account","externalIdField":"Id"}]}';
            Assert.areEqual(masterListContent, result, 'Master list content should match');
        }
    }

    @SuppressWarnings('PMD.AvoidHardcodingId')
    @IsTest
    private static void getMasterListFromDocumentTestFailure() {
        System.runAs(TestUtilities.getRunAsUser()) {
            String invalidId = '001000000000000AAA';

            Test.startTest();
            String result = UserStoryDataDevops.getMasterListFromDocument(invalidId);
            Test.stopTest();

            Assert.areEqual(null, result, 'Result should be null for invalid ID');
        }
    }

    @IsTest
    private static void testGetMasterListFromBackendSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__User_Story__c userStory = getUserStory();
            Id pipelineId = getPipelineObj().Id;

            // Execute
            Test.startTest();
            UserStoryDataDevops.Response result = UserStoryDataDevops.getMasterListFromBackend(userStory.copado__Org_Credential__c, pipelineId);
            Test.stopTest();

            Assert.isNotNull(result.copadoJobId, 'Job Id should be returned');
        }
    }

    @IsTest
    private static void testGetMasterListFromBackendInvalidCredential() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c userStory = getUserStory();
            Id pipelineId = getPipelineObj().Id;

            Test.startTest();
            try {
                UserStoryDataDevops.getMasterListFromBackend(userStory.copado__Org_Credential__c, pipelineId);
            } catch (AuraHandledException e) {
                Assert.areEqual(e.getMessage(), 'Script-thrown exception', 'Should throw job failure error');
            }
            Test.stopTest();
        }
    }
    @IsTest
    private static void testGetMasterListFromBackendJobFailure() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c userStory = getUserStory();
            Id pipelineId = getPipelineObj().Id;

            Test.startTest();
            try {
                UserStoryDataDevops.getMasterListFromBackend(userStory.Id, pipelineId);
            } catch (AuraHandledException e) {
                Assert.areEqual(e.getMessage(), 'Script-thrown exception', 'Should throw job failure error');
            }
            Test.stopTest();
        }
    }

    // HELPERS

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Credential source = new Credential(new Environment().name('Dev1').platform('SFDX').type('Production/Developer'))
                .type('Production/Developer');

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(new Project().add(new UserStory().credential(source)))
                .persist();

            new JobTemplate()
                .name(DATA_RETRIEVE_TEMPLATE)
                .apiName(DATA_RETRIEVE_TEMPLATE)
                .add(new JobStep().name('step1').type('Function').order(1))
                .persist();

            new JobTemplate()
                .name(MASTERLIST_RETRIEVE_TEMPLATE)
                .apiName(MASTERLIST_RETRIEVE_TEMPLATE)
                .add(new JobStep().name('step1').type('Function').order(1))
                .persist();

            new copado.GlobalAPI()
                .upsertCopadoLicense(new copado.GlobalAPI.UserLicense(UserInfo.getUserId(), false, false, false, false, false, true));

            // Setup
            String userStoryId = getUserStory().Id;
            String masterListContent = '{"sObjects":[{"sobject":"Account","displayLabel":"Account","externalIdField":"Id"}]}';

            // Create the config file
            new ContentVersion_t()
                .title(DATA_CONFIG_FILE)
                .pathOnClient(DATA_CONFIG_FILE)
                .versionData(Blob.valueOf(masterListContent))
                .firstPublishLocationId(userStoryId)
                .persist();
        }
    }

    private static SystemProperty createSystemProperties(Pipeline pipeline, String value, String apiName) {
        return new SystemProperty(pipeline).apiName(apiName).value(value);
    }

    private static void assignPermissionSet() {
        insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = getPermissionSet().Id);
    }

    private static PermissionSet getPermissionSet() {
        return [SELECT Id FROM PermissionSet WHERE NAME = :DATA_DEVOPS_PERMISSION_SET LIMIT 1];
    }

    private static copado__User_Story__c getUserStory() {
        return [SELECT Id, copado__Org_Credential__c FROM copado__User_Story__c LIMIT 1];
    }

    private static copado__Deployment_Flow__c getPipeline() {
        return [
            SELECT Id, copado__Git_Repository__r.Name
            FROM copado__Deployment_Flow__c
            LIMIT 1
        ];
    }

    private static Pipeline getPipelineObj() {
        return new Pipeline().recordId(getPipeline().Id);
    }

    private static copado__JobTemplate__c getTemplate() {
        return [SELECT Id FROM copado__JobTemplate__c LIMIT 1];
    }

    public static JobTemplate getTemplateObj() {
        return new JobTemplate().recordId(getTemplate().Id);
    }
}