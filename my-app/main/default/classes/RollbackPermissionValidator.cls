public with sharing class RollbackPermissionValidator{

    @AuraEnabled
    public static Boolean execute(Id destination, Id pipeline) {
        try {
            
            Boolean isProductionEnvironment = new IdentifyProductionEnvironment().isProductionEnvironment(destination, pipeline);
            Boolean isCopadoAdmin = hasAdminLicense();

            return !isProductionEnvironment || (isProductionEnvironment && isCopadoAdmin);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    // PRIVATE
    private static Boolean hasAdminLicense() {
        CheckLicense userLicense = new CheckLicense(UserInfo.getUserId());
        return userLicense.has('Copado Admin');
    }
}