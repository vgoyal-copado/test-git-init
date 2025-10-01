@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class PromoteFunctionCallback implements copado.MCCallback {
    private static final String PROMOTION_US_MERGE_ORDER = 'promotion_us_merge_order.json';

    global void execute(copado__Function__c function, copado__Result__c resultRecord, String status) {
        copado__Result__c result = new ResultsSelector().byIds(new Set<Id>{ resultRecord.Id })[0];
        try {
            Id promotionId = getPromotion(result.Id);
            if (promotionId != null) {
                DeleteSalesforceFiles.deleteOutdatedContentDocumentsAndReturnLatest(new Set<String>{ PROMOTION_US_MERGE_ORDER }, promotionId);
                UpdateConflictResolutionFile.execute(result.Id, promotionId);
            }
        } catch (Exception ex) {
            String exceptionMessage = ex.getMessage() + ' ' + ex.getStackTraceString();
            updateWarningOnJobExecution(resultRecord.copado__JobStep__r.copado__JobExecution__c, exceptionMessage);
        }
    }

    private static Id getPromotion(Id resultId) {
        List<copado__Result__c> result = new ResultsSelector().byIds(new Set<Id>{ resultId });
        return result.isEmpty() ? null : result[0].copado__JobStep__r.copado__JobExecution__r.copado__Promotion__c;
    }

    private static void updateWarningOnJobExecution(Id jobExecutionId, String infoMessage) {
        if (String.isNotBlank(infoMessage)) {
            Utilities.performDML(new List<copado__JobExecution__c>{new copado__JobExecution__c(Id = jobExecutionId, copado__ErrorMessage__c = infoMessage)}, 'update', AccessLevel.USER_MODE);
        }
    }
}