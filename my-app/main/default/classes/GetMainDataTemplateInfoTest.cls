@IsTest
private class GetMainDataTemplateInfoTest {
    private final static String TASK_TEMPLATE = 'Task Template';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }


    @IsTest
    private static void getDataTemplateInfoWithInvalidInput() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id randomId = fflib_IdGenerator.generate(SObjectType.copado__JobStep__c.getKeyPrefix());
            String exceptionMessage;

            // EXERCISE
            try {
                new GetMainDataTemplateInfo().execute(randomId);
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }
            
            // VERIFY
            Assert.isTrue(
                exceptionMessage.contains(Label.Data_Template_Id_Missing),
                'The exception message should be ' + Label.Data_Template_Id_Missing
            );
        }
    }

    @IsTest 
    private static void getDataTemplateInfoWithValidInput() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__JobStep__c jobStep = getJobStep();
            copado__Data_Template__c taskDataTemplate = getDataTemplate(TASK_TEMPLATE);

            // EXERCISE
            String result = new GetMainDataTemplateInfo().execute(jobStep.Id);
            JobStepDataDeployController.DataTemplate dataTemplateInfo = (JobStepDataDeployController.DataTemplate) JSON.deserialize(result, JobStepDataDeployController.DataTemplate.class);

            // VERIFY
            Assert.areEqual(taskDataTemplate.Id, dataTemplateInfo.templateId, 'The main template id should be ' + taskDataTemplate.Id);
            Assert.areEqual(TASK_TEMPLATE, dataTemplateInfo.name, 'Data template name should be ' + TASK_TEMPLATE);
        }
    }
    

    private static void createData() {
        new Credential(new Environment().name('dev1').platform('SFDX').type('Production/Developer')).type('Production/Developer').devhub(false).oauthSignature('signature').validatedDate(System.Now()).persist();
        new Credential(new Environment().name('dev2').platform('SFDX').type('Production/Developer')).type('Production/Developer').devhub(false).oauthSignature('signature').validatedDate(System.Now()).sfdcOrgId(UserInfo.getOrganizationId() + '_' + UserInfo.getUserId()).persist();
        copado__Org__c sourceOrg = getOrg('dev1');

        new DataTemplate().name(TASK_TEMPLATE).activate().persist();
        copado__Data_Template__c taskDataTemplate = getDataTemplate(TASK_TEMPLATE);
        new Attachment_t()
        .name(DataTemplateDetail.ATTACHMENT_NAME)
        .body(Blob.valueOf(getTaskDataTemplateDetail(taskDataTemplate, sourceOrg)))
        .parent(taskDataTemplate.Id).persist();

        JobStepDataDeployController.DataTemplate template = new JobStepDataDeployController.DataTemplate(
            taskDataTemplate.Id,
            TASK_TEMPLATE,
            sourceOrg.Id,
            10.0
        );

        List<Copado.CopadoFunctions.FunctionParameter> functionParameters = new List<Copado.CopadoFunctions.FunctionParameter>();
        Copado.CopadoFunctions.FunctionParameter functionParameter = new Copado.CopadoFunctions.FunctionParameter(
            GetMainDataTemplateInfo.DATA_TEMPLATE,
            JSON.serialize(template)
        );
        functionParameters.add(functionParameter);

        GetDataTemplatePayload.StepConfig stepConfig = new GetDataTemplatePayload.StepConfig();
        stepConfig.functionName = 'SFDX Data Deploy';
        stepConfig.parameters = functionParameters;

        JobTemplate jobTemplate = new JobTemplate().name('SFDX Data Deploy').type('Custom');
        new JobStep(jobTemplate).name('SFDX Data Deploy').type('Function').configJson(JSON.serialize(stepConfig)).persist();
    }

    private static copado__Org__c getOrg(String name) {
        return [SELECT Id FROM copado__Org__c WHERE Name = :name LIMIT 1];
    }

    private static copado__Data_Template__c getDataTemplate(String name) {
        return [SELECT Id FROM copado__Data_Template__c WHERE Name = :name];
    }

    private static copado__JobStep__c getJobStep() {
        return [SELECT Id FROM copado__JobStep__c];
    }

    private static String getTaskDataTemplateDetail(copado__Data_Template__c taskDataTemplate, copado__Org__c sourceOrg) {
        return '{' +
            '"selectableFieldsMap": {' +
            '"ReminderDateTime": {' +
            '"useAsExternalId": false,' +
            '"replaceValueNumber": null,' +
            '"replaceValueDatetime": null,' +
            '"replaceValueDate": null,' +
            '"replaceValue": null,' +
            '"parentObjectApiNameMap": {},' +
            '"name": "ReminderDateTime",' +
            '"label": "Reminder Date/Time",' +
            '"isSelected": true,' +
            '"fieldType": "datetime",' +
            '"fieldContentUpdate": "none",' +
            '"externalId": false,' +
            '"deploymentTemplateNameMap": null,' +
            '"deploymentTemplate": null,' +
            '"contentValueUpdateValues": {' +
            '"Replace Value": "replace"' +
            '}' +
            '},' +
            '"Id": {' +
            '"useAsExternalId": false,' +
            '"replaceValueNumber": null,' +
            '"replaceValueDatetime": null,' +
            '"replaceValueDate": null,' +
            '"replaceValue": null,' +
            '"parentObjectApiNameMap": {},' +
            '"name": "Id",' +
            '"label": "Activity ID",' +
            '"isSelected": true,' +
            '"fieldType": "id",' +
            '"fieldContentUpdate": "none",' +
            '"externalId": false,' +
            '"deploymentTemplateNameMap": null,' +
            '"deploymentTemplate": null,' +
            '"contentValueUpdateValues": {' +
            '"Replace Value": "replace"' +
            '}' +
            '}' +
            '},' +
            '"selectableChildRelationsMap": {' +
            '"RecurrenceActivityId-RecurringTasks": {' +
            '"relationshipName": "RecurringTasks",' +
            '"objectApiNameMap": {' +
            '"Task": "Task"' +
            '},' +
            '"isSelected": false,' +
            '"field": "RecurrenceActivityId",' +
            '"deploymentTemplateNameMap": {},' +
            '"deploymentTemplate": null,' +
            '"childSObject": "Task"' +
            '}' +
            '},' +
            '"queryFilterList": [],' +
            '"parentObjectsReferenceList": [],' +
            '"dataTemplate": {' +
            '"templateSourceOrg": "' +
            sourceOrg.Id +
            '",' +
            '"templateSelectedAttachmentType": "files",' +
            '"templateQueryLimit": null,' +
            '"templateName": "' +
            TASK_TEMPLATE +
            '",' +
            '"templateMatchRecordTypes": true,' +
            '"templateMatchOwners": true,' +
            '"templateMainObject": "' +
            TASK_TEMPLATE +
            '",' +
            '"templateId": "' +
            taskDataTemplate.Id +
            '",' +
            '"templateFilterLogic": "1",' +
            '"templateDescription": null,' +
            '"templateContinueOnError": "Continue deployment until blocker issue",' +
            '"templateBatchSize": 200,' +
            '"templateAttachmentOption": "No Attachments",' +
            '"templateActive": true' +
            '},' +
            '"childrenObjectsReferenceList": []' +
            '}';
    }
   
}