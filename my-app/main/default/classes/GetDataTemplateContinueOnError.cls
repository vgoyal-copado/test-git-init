/**
 * Continue On Error defines the way data deployment behaves with failed record deployment found in result files
 * There are 2 options: 'Continue Deployment Until Blocker Issue', and 'Stop Deployment on First Isuse'
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class GetDataTemplateContinueOnError implements copado.ParameterExpressionCallable {
    @TestVisible
    private static final String DATA_SET = 'dataSet';

    // GLOBAL
    global String execute(Id contextId) {
        // only process when contextId is jobstep Id
        JobStepDataSet.DataSet dataSet = getDataSetFromConfigJson(contextId);
        String continueOnError = dataSet != null ? getContinueOnError(dataSet) : '';
        return continueOnError;
    }

    // PRIVATE
    private String getContinueOnError(JobStepDataSet.DataSet dataSet) {
        List<copado__Data_Set__c> dataSetRecords = new DataSetsSelector().byIdsSelectDataTemplateFields(new Set<Id>{dataSet.dataSetId});
        String continueOnError = !dataSetRecords.isEmpty() ? dataSetRecords[0]?.copado__Data_Template__r?.copado__Continue_on_Error__c : '';
        return continueOnError;
    }

    private JobStepDataSet.DataSet getDataSetFromConfigJson(Id jobStepId) {
        JobStepDataSet.DataSet result;
        List<copado__JobStep__c> jobSteps = new JobStepsSelector().byIds(new Set<Id>{ jobStepId });
        if (!jobSteps.isEmpty() && String.isNotBlank(jobSteps[0].copado__ConfigJson__c)) {
            StepConfig stepConfig = (StepConfig) JSON.deserialize(jobSteps[0].copado__ConfigJson__c, StepConfig.class);
            for (Copado.CopadoFunctions.FunctionParameter functionParameter : stepConfig.parameters) {
                if (functionParameter.name == DATA_SET) {
                    result = (JobStepDataSet.DataSet) JSON.deserialize(
                        functionParameter.value,
                        JobStepDataSet.DataSet.class
                    );
                    break;
                }
            }
        }
        return result;
    }

    @TestVisible
    private class StepConfig {
        public String functionName;
        public List<Copado.CopadoFunctions.FunctionParameter> parameters;
    }
}