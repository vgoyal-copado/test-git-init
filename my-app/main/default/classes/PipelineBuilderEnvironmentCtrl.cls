public with sharing class PipelineBuilderEnvironmentCtrl {
    @AuraEnabled(cacheable=true)
    public static EnvironmentData validateEnvironment(String environmentId) {
        EnvironmentData result = new EnvironmentData();
        List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(environmentId);
        copado.ValidateOrgAction.Request request = new copado.ValidateOrgAction.Request();
        result.isValidOrg = false;
        if (!credentials.isEmpty()) {
            request.orgId = credentials[0].Id;
            result.isValidOrg = String.isBlank(credentials[0].copado__SFDC_Org_ID__c)
                ? false
                : copado.ValidateOrgAction.execute(new List<copado.ValidateOrgAction.Request>{ request })?.get(0).isValidOrg;
            
            result.credentialName = credentials[0].copado__Username__c;
            result.credentialId = credentials[0].Id;
        }
        return result;
    }

    public with sharing class EnvironmentData {
        @AuraEnabled
        public Boolean isValidOrg;
        @AuraEnabled
        public String credentialName;
         @AuraEnabled
        public String credentialId;
    }
}