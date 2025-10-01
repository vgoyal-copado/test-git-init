public with sharing class PermissionChecker {
    private static final String CMC_SFDX_ADMIN = 'CMC_SFDX_Admin';

    @AuraEnabled(cacheable=true)
    public static Boolean hasCmcSfdxAdminPermissionSet () {
        try {
            return hasPermissions( CMC_SFDX_ADMIN );
        } catch ( Exception ex ) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    private static Boolean hasPermissions( String pemissionName ) {
        Boolean hasAccess = Utilities.checkPermission(
            pemissionName,
            new Set<Id>{ UserInfo.getUserId() },
            false
        );

        return hasAccess;
    }
}