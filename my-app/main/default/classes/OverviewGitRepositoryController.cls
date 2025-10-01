public with sharing class OverviewGitRepositoryController {
    private static final String SUCCESS = 'success';
    private static final String MOCK_AUTH_RESPONSE = '{"success":true}';

    @AuraEnabled(cacheable=true)
    public static GitRepositoryWrapper getGitRepository(String selectedPipelineId) {
        try {
            if (String.isBlank(selectedPipelineId)) {
                return null;
            }
            
            List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byId(new Set<Id>{selectedPipelineId});
            
            if (pipelines.isEmpty() || pipelines[0].copado__Git_Repository__c == null) {
                return null;
            }
    
            return new GitRepositoryWrapper(
                pipelines[0].copado__Git_Repository__r?.Id,
                pipelines[0].copado__Git_Repository__r?.copado__Pull_Request_Base_URL__c,
                pipelines[0].copado__Git_Repository__r?.Name
            );
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }
    
    public class GitRepositoryWrapper {
        @AuraEnabled public final Id id; 
        @AuraEnabled public final String url;
        @AuraEnabled public Boolean isAuthenticated;
        @AuraEnabled public String name;

        public GitRepositoryWrapper (Id id, String url, String name) {
            this.id = id;
            this.url = url;
            this.name = name;
            this.setAuthentication();
        }

        private void setAuthentication() {
            if (this.id == null) {
                return;
            }

            String response;
            if (Test.isRunningTest()) {
                response = MOCK_AUTH_RESPONSE;
            } else {
                response = copado.RepositoryOAuth.validateGitConnection(this.id);
            }

            if (!String.isEmpty(response)) {
                Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(response);
                this.isAuthenticated = (Boolean) jsonData.get(SUCCESS);
            }
        }
    }
}