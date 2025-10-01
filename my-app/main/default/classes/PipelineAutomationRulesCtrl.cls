public with sharing class PipelineAutomationRulesCtrl {

    private static final String CONFIGURE_AUTOMATIONS_PERMISSION_SET = 'Configure_Automations';

    @AuraEnabled(cacheable=true)
    public static PermissionResponse getPermissionResponse() {
        PermissionResponse response = new PermissionResponse();
        
        try {
            List<PermissionSet> permissionSets = [SELECT Id, Label, Name FROM PermissionSet
                                                    WHERE Name = : CONFIGURE_AUTOMATIONS_PERMISSION_SET WITH USER_MODE LIMIT 1];
            if (!permissionSets.isEmpty()) {
                response.permissionSetLabel = permissionSets[0].Label;
                response.hasPermission = Utilities.checkPermission(CONFIGURE_AUTOMATIONS_PERMISSION_SET, new Set<Id>{ UserInfo.getUserId() }, false);
            }
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static MatchingRulesResultWrapper getMatchingRules(Id pipelineId, Id environmentId) {
        if (pipelineId == null || environmentId == null) { return null; }

        MatchingRulesResultWrapper resultWrapper;
        try {
            copado.Automations.FindMatchingRulesRequest request = new copado.Automations.FindMatchingRulesRequest();
            request.pipelineId = pipelineId;
            request.environmentIds = new Set<Id>{environmentId};
            request.automationRuleIds = new Map<Id, Copado__Automation_Rule__c>([SELECT Id FROM Copado__Automation_Rule__c WHERE copado__Pipeline__c = :pipelineId]).keyset();
            
            copado.Automations.FindMatchingRulesResult result;
            if (request.automationRuleIds != null && !request.automationRuleIds.isEmpty()) {
                result = copado.Automations.MatchingService.execute(request);
            }
            resultWrapper = new MatchingRulesResultWrapper(result);     
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return resultWrapper;
    }

    public class MatchingRuleWrapper {
        @AuraEnabled public Id ruleId;
        @AuraEnabled public Boolean isLastEnvironmentInAutomationRule;
        @AuraEnabled public Boolean isLastEnvironmentInStage;

        public MatchingRuleWrapper(copado.Automations.MatchingRule rule) {
            this.ruleId = rule.ruleId;
            this.isLastEnvironmentInAutomationRule = rule.isLastEnvironmentInAutomationRule; 
            this.isLastEnvironmentInStage = rule.isLastEnvironmentInStage; 
        }
    }

    public class MatchingRuleConfigWrapper {
        @AuraEnabled public List<MatchingRuleWrapper> matchingRules;

        public MatchingRuleConfigWrapper(copado.Automations.MatchingRuleConfig config) {
            this.matchingRules = new List<MatchingRuleWrapper>();
            if (config != null && config.matchingRules != null) {
                for (copado.Automations.MatchingRule rule : config.matchingRules) {
                    this.matchingRules.add(new MatchingRuleWrapper(rule));
                }
            }
        }
    }

    public class MatchingRulesResultWrapper {
        @AuraEnabled public MatchingRuleConfigWrapper matchingRuleConfig;

        public MatchingRulesResultWrapper(copado.Automations.FindMatchingRulesResult result) {
            if (result != null && result.matchingRuleConfig != null) {
                this.matchingRuleConfig = new MatchingRuleConfigWrapper(result.matchingRuleConfig);
            }
        }
    }

    public with sharing class PermissionResponse {
        @AuraEnabled
        public Boolean hasPermission;
        @AuraEnabled
        public String permissionSetLabel;
        public PermissionResponse() {
            hasPermission = false;
            permissionSetLabel = '';
        }
        
    }
}