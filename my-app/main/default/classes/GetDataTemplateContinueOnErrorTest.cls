@IsTest
private class GetDataTemplateContinueOnErrorTest {
    private final static String TASK_TEMPLATE = 'Task Template';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest 
    private static void getContinueOnErrorWithValidInput() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__JobStep__c jobStep = getJobStep();
            copado__Data_Template__c taskDataTemplate = getDataTemplate(TASK_TEMPLATE);

            // EXERCISE
            String result = new GetDataTemplateContinueOnError().execute(jobStep.Id);

            // VERIFY
            Assert.areEqual(result, taskDataTemplate.copado__Continue_on_Error__c, 'Continue_on_Error should be ' + taskDataTemplate.copado__Continue_on_Error__c);
        }
    }



    private static void createData() {
        new Credential(new Environment().name('dev1').platform('SFDX').type('Production/Developer')).type('Production/Developer').devhub(false).oauthSignature('signature').validatedDate(System.Now()).persist();

        new DataTemplate().name(TASK_TEMPLATE).activate().persist();
        copado__Data_Template__c taskDataTemplate = getDataTemplate(TASK_TEMPLATE);

        copado__Data_Set__c dataset = new copado__Data_Set__c(Name = 'dataset1',copado__Data_Template__c = taskDataTemplate.Id);
        insert dataset;

        JobStepDataSet.DataSet dataSetInfo = new JobStepDataSet.DataSet(dataset.Id, dataset.name);

        List<Copado.CopadoFunctions.FunctionParameter> functionParameters = new List<Copado.CopadoFunctions.FunctionParameter>();
        Copado.CopadoFunctions.FunctionParameter functionParameter = new Copado.CopadoFunctions.FunctionParameter(
            GetDataTemplateContinueOnError.DATA_SET,
            JSON.serialize(dataSetInfo)
        );
        functionParameters.add(functionParameter);

        GetDataTemplatePayload.StepConfig stepConfig = new GetDataTemplatePayload.StepConfig();
        stepConfig.functionName = 'SFDX Data Set';
        stepConfig.parameters = functionParameters;

        JobTemplate jobTemplate = new JobTemplate().name('SFDX Data Set').type('Custom');
        new JobStep(jobTemplate).name('SFDX Data Set').type('Function').configJson(JSON.serialize(stepConfig)).persist();
    }

    private static copado__Org__c getOrg(String name) {
        return [SELECT Id FROM copado__Org__c WHERE Name = :name LIMIT 1];
    }

    private static copado__Data_Template__c getDataTemplate(String name) {
        return [SELECT Id, copado__Continue_on_Error__c FROM copado__Data_Template__c WHERE Name = :name];
    }

    private static copado__JobStep__c getJobStep() {
        return [SELECT Id FROM copado__JobStep__c];
    }

}