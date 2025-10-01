@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class GetMainDataTemplateInfo implements copado.ParameterExpressionCallable {
    @TestVisible
    private static final String DATA_TEMPLATE = 'dataTemplate';

    // GLOBAL
    global String execute(Id contextId) {
        JobStepDataDeployController.DataTemplate dataTemplate = getDataTemplateFromConfigJson(contextId);
        return JSON.serialize(getMainDataTemplate(dataTemplate));
    }

    // PRIVATE
    private JobStepDataDeployController.DataTemplate getMainDataTemplate(JobStepDataDeployController.DataTemplate dataTemplate) {
        if (String.isBlank(dataTemplate?.templateId)) {
            throw new ApplicationException(Label.Data_Template_Id_Missing);
        }
        JobStepDataDeployController.DataTemplate mainTemplateInfo = JobStepDataDeployController.loadDataTemplateById(new List<Id>{dataTemplate.templateId}).get(dataTemplate.templateId);
        if (mainTemplateInfo == null) {
            throw new ApplicationException(Label.Data_Template_Missing);
        }
        mainTemplateInfo.queryFilterList = dataTemplate.queryFilterList;
        mainTemplateInfo.filterLogic = dataTemplate.filterLogic;
        return mainTemplateInfo;
    }

    private JobStepDataDeployController.DataTemplate getDataTemplateFromConfigJson(Id jobStepId) {
        JobStepDataDeployController.DataTemplate result;
        List<copado__JobStep__c> jobSteps = new JobStepsSelector().byIds(new Set<Id>{ jobStepId });
        if (!jobSteps.isEmpty() && String.isNotBlank(jobSteps[0].copado__ConfigJson__c)) {
            StepConfig stepConfig = (StepConfig) JSON.deserialize(jobSteps[0].copado__ConfigJson__c, StepConfig.class);
            for (Copado.CopadoFunctions.FunctionParameter functionParameter : stepConfig.parameters) {
                if (functionParameter.name == DATA_TEMPLATE) {
                    result = (JobStepDataDeployController.DataTemplate) JSON.deserialize(
                        functionParameter.value,
                        JobStepDataDeployController.DataTemplate.class
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