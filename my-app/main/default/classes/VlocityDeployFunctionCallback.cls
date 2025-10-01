@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class VlocityDeployFunctionCallback implements copado.MCCallback {

    global void execute(copado__Function__c function, copado__Result__c result, String status) {
        DeleteObsoleteFilesOnPromotion.Request request = new DeleteObsoleteFilesOnPromotion.Request();
        request.resultId = result.Id;
        DeleteObsoleteFilesOnPromotion.execute(new List<DeleteObsoleteFilesOnPromotion.Request>{ request });
    }
}