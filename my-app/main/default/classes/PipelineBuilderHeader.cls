@SuppressWarnings('PMD.FieldDeclarationsShouldBeAtStart')
public with sharing class PipelineBuilderHeader {

    public static final String NAMESPACE = PipelineBuilderHeader.class
                                            .getName()
                                            .substringBefore('PipelineBuilderHeader')
                                            .removeEnd('.');

    public static final String COPADO_NAMESPACE = copado.GlobalAPI.class
                                            .getName()
                                            .substringBefore('GlobalAPI')
                                            .removeEnd('.');

    // Note: Namespace with __ appended
    public static final String ns {
        get {
            return String.isBlank(NAMESPACE) ? '' : (NAMESPACE + '__');
        }
        private set;
    }

    public static final String copadoNs {
        get {
            return String.isBlank(COPADO_NAMESPACE) ? '' : (COPADO_NAMESPACE + '__');
        }
        private set;
    }

    private static final String COMPARE_BRANCHES_FUNCTION_API_NAME = ns + 'Compare_Branches'; 
    private static final String BRANCHES_TO_CHECK_PARAMETER = 'branches_to_check';

    @TestVisible
    private static Result mockResult;

    // PUBLIC

    @AuraEnabled
    public static List<copado__Deployment_Flow__c> getPipelines() {
        return new PipelinesSelector().byPlatform(PipelineBuilderConstants.SFDX);
    }

    @AuraEnabled
    public static Boolean hasPipelineEditPermission(String selectedPipelineId) {
       
        if (String.isNotBlank(selectedPipelineId) && Schema.sObjectType.copado__Deployment_Flow__c.isUpdateable()) {
            List<UserRecordAccess> usersRecordAccess = [
                    SELECT RecordId, HasEditAccess
                    FROM UserRecordAccess
                    WHERE UserId = :UserInfo.getUserId() AND RecordId = :selectedPipelineId 
                    WITH SYSTEM_MODE];
            return !usersRecordAccess.isEmpty() && usersRecordAccess[0].HasEditAccess;
        } 
        return false;
    }

    @AuraEnabled
    public static List<EnvironmentDetail> validateEnvironments(List<Id> environmentIds) { 
        List<EnvironmentDetail> environmentDetails = new List<EnvironmentDetail>();
        Map<Id, copado__Org__c> credentialByEnvironment = new Map<Id, copado__Org__c>();
        
        for(copado__Org__c credential : new CredentialsSelector().byEnvironmentIdAndValidationCheck(new Set<Id>(environmentIds))){
            credentialByEnvironment.put(credential.copado__Environment__c, credential);
        }

        for (Id environmentId : environmentIds){
            if (!credentialByEnvironment.containsKey(environmentId)){
                environmentDetails.add(new EnvironmentDetail(environmentId, 'None', ''));
            }
        }
        return environmentDetails;
    }

    @AuraEnabled
    public static String validateBranches(String pipelineId, List<String> branchNames) { 
        copado.RunCopadoFunction.InvocableVariables request = new copado.RunCopadoFunction.InvocableVariables();
        request.functionApiName = COMPARE_BRANCHES_FUNCTION_API_NAME;
        request.contextId = pipelineId;

        List<copado.Parameter> parameterList = new List<copado.Parameter>();
        copado.Parameter parameter = new copado.Parameter();
        parameter.name = BRANCHES_TO_CHECK_PARAMETER;
        parameter.value = String.join(branchNames,',');
        parameterList.add(parameter);
        request.parameters = parameterList;

        if (Test.isRunningTest()){
            return mockResult.Id;
        } else {
            List<String> result = copado.RunCopadoFunction.execute(new List<copado.RunCopadoFunction.InvocableVariables> { request });
            return result[0];
        }
    }

    @AuraEnabled
    public static copado__Result__c getResult(String resultId) {
        return new ResultsSelector().byIds(new Set<Id>{ resultId })[0];
    }

    @AuraEnabled
    public static Boolean isFunctionRunning(String resultId) {
        return [SELECT COUNT() FROM copado__Result__c WHERE Id =: resultId AND copado__Status__c != 'Success' AND copado__Status__c != 'Failed'
        WITH USER_MODE] > 0;
    }

    // WRAPPER

    public with sharing class EnvironmentDetail {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String userName;

        public EnvironmentDetail(String id, String status, String userName) {
            this.id = id;
            this.status = status;
            this.userName = userName;
        } 
    }
}