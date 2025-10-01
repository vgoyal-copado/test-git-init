@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class GetCurrentEnvId implements copado.ParameterExpressionCallable {
    
    // GLOBAL
    global String execute(Id contextId) {
        String sfdcOrgId = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();
        List<copado__Org__c> orgs = new CredentialsSelector().bySFDCOrgId(new Set<String> {sfdcOrgId});
        if (orgs.isEmpty()) {
            throw new ApplicationException(Label.Error_Validate_Current_Org_Credential);
        }
        return orgs[0].copado__Environment__c;
    }
}