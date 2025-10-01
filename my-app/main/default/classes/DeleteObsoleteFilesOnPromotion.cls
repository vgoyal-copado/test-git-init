public with sharing class DeleteObsoleteFilesOnPromotion {
    private final static Set<String> FILES_ON_PROMOTION = new Set<String>{
        'Copado Rollback Changes',
        'Copado Vlocity Rollback changes',
        'promotion_us_merge_order.json'
    };

    // PUBLIC
    @InvocableMethod(
        label='Delete Obsolete Files On Promotion'
        description='This method deletes the old files and keeps the latest files on the promotion record'
        category='Deployment'
    )
    public static void execute(List<Request> requests) {
        copado__Result__c result = getResult(requests);
        try {
            if (!isDataValid(result) || isValidation(result)) {
                return;
            }
            Id promotionId = getPromotionId(result);
            DeleteSalesforceFiles.deleteOutdatedContentDocumentsAndReturnLatest(FILES_ON_PROMOTION, promotionId);
        } catch (Exception ex) {
            String exceptionMessage = ex.getMessage() + ' ' + ex.getStackTraceString();
            updateWarningOnJobExecution(result.copado__JobStep__r.copado__JobExecution__c, exceptionMessage);
        }
    }

    private static Boolean isDataValid(copado__Result__c result) {
        return result != null && String.isNotBlank(result.copado__JobStep__r?.copado__JobExecution__c);
    }

    private static copado__Result__c getResult(List<Request> requests) {
        Id resultId = requests != null && !requests.isEmpty() ? requests[0].resultId : null;
        List<copado__Result__c> results = new ResultsSelector().byIds(new Set<Id>{ resultId });
        return !results.isEmpty() ? results[0] : null;
    }

    private static Id getPromotionId(copado__Result__c result) {
        return result.copado__JobStep__r?.copado__JobExecution__r?.copado__Deployment__r?.copado__Promotion__c;
    }

    private static void updateWarningOnJobExecution(Id jobExecutionId, String infoMessage) {
        if (String.isNotBlank(infoMessage) && Schema.sObjectType.copado__JobExecution__c.fields.copado__ErrorMessage__c.isUpdateable()) {
            copado__JobExecution__c jobExecution = new copado__JobExecution__c(Id = jobExecutionId, copado__ErrorMessage__c = infoMessage);
            Utilities.performDML(new List<copado__JobExecution__c>{ jobExecution }, 'update', AccessLevel.USER_MODE);
        }
    }

    private static Boolean isValidation(copado__Result__c result) {
        String dataJson = result.copado__JobStep__r?.copado__JobExecution__r?.copado__DataJson__c;
        return String.isNotBlank(dataJson) ? ((DataJson) JSON.deserialize(dataJson, DataJson.class)).deploymentDryRun : true;
    }

    // INNER
    public class Request {
        @InvocableVariable(label='Result Id' required=true)
        public String resultId;
    }
    private class DataJson {
        public Boolean deploymentDryRun;
    }
}