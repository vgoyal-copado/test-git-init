public with sharing class RepositoryAuthenticationCtrl {

    @TestVisible
    private static Boolean testAuthenticationResult = true;

    @AuraEnabled(cacheable=false)
    public static Boolean isAuthenticated(Id repositoryId) {
        try {
            if (Test.isRunningTest()) {
                return testAuthenticationResult;
            }
            return copado.RepositoryOAuth.isAuthenticated(repositoryId);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }
}