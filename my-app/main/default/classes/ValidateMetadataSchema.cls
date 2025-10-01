public with sharing class ValidateMetadataSchema {
    private static final String SFDX_VALIDATE_METADATA_SCHEMA = 'sfdx_validate_metadata_schema';

    @TestVisible
    private static Result mockResult;

    // PUBLIC

    @AuraEnabled
    public static Id execute(String metadataFileId, String metadataType) {
        try {
            Id resultId;

            copado.RunCopadoFunction.InvocableVariables request = new copado.RunCopadoFunction.InvocableVariables();
            request.functionApiName = SFDX_VALIDATE_METADATA_SCHEMA;
            request.parameters = getParameters(metadataFileId, metadataType);
            request.showValidationErrors = true;

            if (Test.isRunningTest()) {
                resultId = mockResult.Id;
            } else {
                resultId = copado.RunCopadoFunction.execute(new List<copado.RunCopadoFunction.InvocableVariables>{ request })[0];
            }
            return resultId;
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled
    public static ResultData getResultInfo(Id resultId){
        try {
            copado__Result__c result = new ResultsSelector().byId(resultId);
            return new ResultData(result.copado__Status__c, result.copado__Error_Message__c);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    //PRIVATE

    private static List<copado.Parameter> getParameters(String metadataFileId, String metadataType) {
        List<copado.Parameter> result = new List<copado.Parameter>();

        result.add(new copado.Parameter('metadataFileId', metadataFileId));
        result.add(new copado.Parameter('metadataType', metadataType));

        return result;
    }

    @TestVisible
    private class ResultData {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String errorMessage;

        ResultData(String status, String errorMessage) {
            this.status = status;
            this.errorMessage = errorMessage;
        }
    }
}