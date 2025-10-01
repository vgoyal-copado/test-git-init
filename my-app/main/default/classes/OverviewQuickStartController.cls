public with sharing class OverviewQuickStartController {
    @AuraEnabled
    public static Boolean isQuickStartInProgress () {
        return QuickStartCtrl.getInProgressPipeline() != null;
    }
}