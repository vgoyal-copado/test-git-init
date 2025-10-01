@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class DeploymentExtraFlags implements copado.ParameterExpressionCallable {
    private static final String EXTRA_FLAGS = '--ignore-warnings';
    // GLOBAL
    global String execute(Id contextId) {
        try {
            String jobExecutionDataJson = getJobExecutionData(contextId)?.copado__JobExecution__r?.copado__DataJson__c;
            JobExecutionData jobExecutionData = (JobExecutionData) JSON.deserialize(jobExecutionDataJson, JobExecutionData.class);
            copado__Promotion__c promotion = getPromotion(jobExecutionData.promotionId);
            String changesFileId = jobExecutionData.fileWithSelectedChanges;
            String fileData = getFileData(changesFileId);
            Boolean containsDestructiveChanges = containsDestructiveChanges(fileData);

            return containsDestructiveChanges ? '' : promotion.Ignore_Deployment_Warnings__c ? EXTRA_FLAGS : '';
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // PRIVATE
    private copado__JobStep__c getJobExecutionData(Id stepId) {
        List<copado__JobStep__c> result = new JobStepsSelector().jobExecutionbyStepIds(new Set<Id>{ stepId });
        return result.isEmpty() ? new copado__JobStep__c() : result[0];
    }

    private copado__Promotion__c getPromotion(Id promotionId) {
        List<copado__Promotion__c> result = new PromotionsSelector().byIds(new Set<Id>{ promotionId });
        return result.isEmpty() ? new copado__Promotion__c() : result[0];
    }

    private String getFileData(Id changesFileId) {
        return new ContentVersionsSelector().byIds(new Set<Id>{ changesFileId })[0]?.VersionData?.toString();
    }

    private Boolean containsDestructiveChanges(String fileData) {
        Boolean result = false;
        for (FileData data : (List<FileData>) JSON.deserialize(fileData, List<FileData>.class)) {
            if (data.a == 'Delete') {
                result = true;
                break;
            }
        }
        return result;
    }

    @TestVisible
    private class JobExecutionData {
        public String promotionId;
        public String fileWithSelectedChanges;
    }

    @TestVisible
    private class FileData {
        public String a;
    }
}