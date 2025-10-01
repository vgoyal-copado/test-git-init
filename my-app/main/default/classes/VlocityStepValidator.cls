@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class VlocityStepValidator implements copado.ParameterExpressionCallable{
    
    // GLOBAL
    global String execute(Id contextId) {
        try{
            Boolean skipVlocityStep = false;

            String jobExecutionDataJson = getJobExecutionData(contextId)?.copado__JobExecution__r?.copado__DataJson__c;
            JobExecutionData jobExecutionData = (JobExecutionData) JSON.deserialize(jobExecutionDataJson, JobExecutionData.class);

            String isValidationRunning = jobExecutionData.deploymentDryRun;
            if(isValidationRunning == 'true') {
                skipVlocityStep = true;
                return String.valueOf(skipVlocityStep);
            }

            String changesFileId = jobExecutionData.fileWithSelectedChanges;
            String hasVlocityChanges = HasVlocityChanges.hasVlocityChangesInFile((Id) changesFileId);
            if(hasVlocityChanges == 'false') {
                skipVlocityStep = true;
            }

            return String.valueOf(skipVlocityStep);
        } catch (Exception ex) {
             throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // PRIVATE

    private copado__JobStep__c getJobExecutionData(Id stepId) {
        List<copado__JobStep__c> result = new JobStepsSelector().jobExecutionbyStepIds(new Set<Id>{ stepId });
        return result.isEmpty() ? new copado__JobStep__c() : result[0];
    }

    @TestVisible
    private class JobExecutionData {
        public String fileWithSelectedChanges;
        public String deploymentDryRun;
    }
}