public with sharing class PipelineQualityGatesCtrl {
    private static final Set<String> QUALITY_PERMISSIONS = new Set<String>{
        'Configure_AQF',
        'Configure_Automations'
    };

    @AuraEnabled(cacheable=true)
    public static List<copado__TestTool__mdt> getAllQualityGateTestFrom() {
        if (Test.isRunningTest()) {
            return null;
        } else {
            return [SELECT DeveloperName, Label,
                        (SELECT copado__Is_Visible__c, copado__Test_Tool__r.DeveloperName, copado__Test_Tool__r.Label
                        FROM copado__Quality_Gate_Test_From__r)
                    FROM copado__TestTool__mdt
                    WITH USER_MODE];
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<copado__ExtensionConfiguration__c> getAllExtensionConfigurations() {
        return new ExtensionConfigurationsSelector().selectAll();
    }

    @AuraEnabled(cacheable=true)
    public static Boolean hasPermission() {
        try {
            return Utilities.checkPermissions(new List<String>(QUALITY_PERMISSIONS), new Set<Id>{ UserInfo.getUserId() });
        } catch (Exception e) {
            return false;
        }
    }
}