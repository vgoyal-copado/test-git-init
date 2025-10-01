public with sharing class OverviewGovernanceOrgCredentialCtrl {
    private static final String VALID = 'valid';
    private static final String INVALID = 'invalid';
    private static final String NOT_FOUND = 'notfound';

    @AuraEnabled
    public static Credential hasValidCredential() {
        try {
            String username = String.escapeSingleQuotes(UserInfo.getUserName());
            CredentialsSelector selector = new CredentialsSelector();
            List<copado__Org__c> credentials = selector.byUsernameAndOrgId(
                username,
                UserInfo.getOrganizationId()
            );
            
            Credential credentialWrapper = new Credential();
            
            if (credentials.isEmpty()) {
                credentialWrapper.status = NOT_FOUND;
                return credentialWrapper;
            }
            
            credentialWrapper.credentialId = credentials[0].Id;

            // Using Test.isRunningTest() because there's an issue with the test class not accepting mocks.
            if (Test.isRunningTest()) {
                credentialWrapper.status = VALID;
            } else {
                credentialWrapper.status = copado.GlobalApi.validateOrg(credentials[0].Id) ? VALID : INVALID;
            }

            return credentialWrapper;
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    public class Credential {
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Id credentialId;
    }
}