public class PipelineOperationsServiceImpl {
    /*public static PipelineOperations.PipelineResult getActivePipelines() {
        // This probably will be an wire method in thge LWC
        PipelineOperations.PipelineResult result = new PipelineOperations.PipelineResult();
        result.activePipelines = [
            SELECT Id, Name, copado__Platform__c, copado__Main_Branch__c
            FROM copado__Deployment_Flow__c
            WHERE copado__Active__c = TRUE AND copado__Platform__c = 'SFDX'
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
        ];
        return result;
    }

    public static PipelineOperations.CredentialDetailsResult getCredentialDetails(Id environmentId) {
        PipelineOperations.CredentialDetailsResult result = new PipelineOperations.CredentialDetailsResult();
        result.credential = [
            SELECT Id, Name, copado__Org_Type__c, copado__Username__c
            FROM copado__Org__c
            WHERE copado__Environment__c = :environmentId
            LIMIT 1
        ];
        return result;
    }

    public static PipelineOperations.JobExecutionsResult getJobExecutions(Id environmentId) {
        PipelineOperations.JobExecutionsResult result = new PipelineOperations.JobExecutionsResult();
        result.jobExecutions = [
            SELECT Id, Name, copado__Status__c, copado__Promotion__c, copado__Deployment__c
            FROM copado__JobExecution__c
            WHERE
                copado__Destination_Org__c = :environmentId
                AND (copado__JobStep__r.copado__Type__c = 'Promotion'
                OR copado__JobStep__r.copado__Type__c = 'Deployment')
            ORDER BY CreatedDate DESC
        ];
        return result;
    }

    public static PipelineOperations.UserStoriesResult getUserStories(Id environmentId) {
        PipelineOperations.UserStoriesResult result = new PipelineOperations.UserStoriesResult();
        result.userStories = [
            SELECT Id, Name, copado__Status__c, copado__User_Story_Title__c
            FROM copado__User_Story__c
            WHERE copado__Environment__c = :environmentId
        ];
        return result;
    }

    public static PipelineOperations.SystemPropertiesResult getSystemProperties(Id environmentId) {
        PipelineOperations.SystemPropertiesResult result = new PipelineOperations.SystemPropertiesResult();
        result.systemProperties = [
            SELECT Id, Name, copado__Value__c
            FROM copado__System_Property__c
            WHERE copado__Environment__c = :environmentId
        ];
        return result;
    }
        
    public static PipelineOperations.JobQueueResult getJobQueue() {
        PipelineOperations.JobQueueResult result = new PipelineOperations.JobQueueResult();
        result.queuedJobs = [
            SELECT Id, Name, copado__Status__c, copado__Promotion__c, copado__Deployment__c
            FROM copado__JobExecution__c
            WHERE copado__Status__c = 'Queued'
            ORDER BY CreatedDate ASC
        ];
        result.queuedJobsCount = result.queuedJobs.size();
        return result;
    }*/

    public static PipelineOperations.QualityGatesResult getQualityGateRules(Id environmentId) {
        PipelineOperations.QualityGatesResult result = new PipelineOperations.QualityGatesResult();
        if (environmentId == null) {
            result.qualityGates = new List<PipelineOperations.QualityGateWrapper>();
            return result;
        }

        try {
            Map<String, Set<Id>> relationships = getEnvironmentRelationships(environmentId);

            // Query for quality gate rules and conditions based on all three scenarios
            List<copado__Quality_Gate_Rule_Condition__c> conditions = [
                SELECT
                    Id,
                    copado__Environment__c,
                    copado__Pipeline__c,
                    copado__Stage__c,
                    copado__Tests_From__c,
                    copado__Quality_Gate_Rule__c,
                    copado__Quality_Gate_Rule__r.Name,
                    copado__Quality_Gate_Rule__r.copado__Tool__c,
                    copado__Quality_Gate_Rule__r.copado__Status__c,
                    copado__Quality_Gate_Rule__r.copado__Execution_sequence__c,
                    copado__Quality_Gate_Rule__r.copado__Actions__c
                FROM copado__Quality_Gate_Rule_Condition__c
                WHERE
                    (copado__Environment__c = :environmentId
                    OR (copado__Stage__c IN :relationships.get('stages')
                    AND copado__Environment__c = NULL)
                    OR (copado__Pipeline__c IN :relationships.get('pipelines')
                    AND copado__Environment__c = NULL
                    AND copado__Stage__c = NULL))
                    AND copado__Quality_Gate_Rule__r.copado__Status__c = 'Active'
                WITH USER_MODE
                ORDER BY copado__Quality_Gate_Rule__r.Name
            ];

            // Create wrapper objects
            List<PipelineOperations.QualityGateWrapper> wrappers = new List<PipelineOperations.QualityGateWrapper>();
            for (copado__Quality_Gate_Rule_Condition__c condition : conditions) {
                wrappers.add(new PipelineOperations.QualityGateWrapper(condition.copado__Quality_Gate_Rule__r, condition));
            }

            result.qualityGates = wrappers;
            return result;
        } catch (Exception e) {
            throw new ApplicationException('Error retrieving quality gate rules: ' + e.getMessage());
        }
    }

    public static PipelineOperations.QualityGatesRuleConditionResult hasQualityGateRuleCondition(Id environmentId) {
        PipelineOperations.QualityGatesRuleConditionResult result = new PipelineOperations.QualityGatesRuleConditionResult();
        if (environmentId == null) {
            result.hasQualityGate = false;
            return result;
        }

        try {
            Map<String, Set<Id>> relationships = getEnvironmentRelationships(environmentId);

            // Query for quality gate conditions based on all three scenarios
            List<copado__Quality_Gate_Rule_Condition__c> conditions = [
                SELECT Id
                FROM copado__Quality_Gate_Rule_Condition__c
                WHERE
                    (copado__Environment__c = :environmentId
                    OR (copado__Stage__c IN :relationships.get('stages')
                    AND copado__Environment__c = NULL)
                    OR (copado__Pipeline__c IN :relationships.get('pipelines')
                    AND copado__Environment__c = NULL
                    AND copado__Stage__c = NULL))
                    AND copado__Quality_Gate_Rule__r.copado__Status__c = 'Active'
                WITH USER_MODE
            ];
            result.hasQualityGate = !conditions.isEmpty();
            return result;
        } catch (Exception e) {
            throw new ApplicationException('Error checking quality gate conditions: ' + e.getMessage());
        }
    }

    public static PipelineOperations.AutomationRulesResult getAutomationRules(Id environmentId) {
        PipelineOperations.AutomationRulesResult result = new PipelineOperations.AutomationRulesResult();
        if (environmentId == null) {
            result.automationRules = new List<PipelineOperations.AutomationRuleWrapper>();
            return result;
        }

        try {
            // Get environment relationships
            Map<String, Set<Id>> relationships = getEnvironmentRelationships(environmentId);
            System.debug('**F**relationships : ' + relationships);
            Set<Id> pipelineIds = relationships.get('pipelines');
            Set<Id> stageIds = relationships.get('stages');
            System.debug('**F**pipelineIds : ' + pipelineIds);
            System.debug('**F**stageIds : ' + stageIds);

            // Query for automation rules
            List<copado__Automation_Rule__c> rules = [
                SELECT
                    Id,
                    Name,
                    copado__Environment__c,
                    copado__Stage__c,
                    copado__Pipeline__c,
                    copado__Pipeline__r.Name,
                    copado__Automation_Connector__c,
                    copado__Config_Json__c
                FROM copado__Automation_Rule__c
                WHERE
                    copado__Active__c = TRUE
                    AND (copado__Environment__c != NULL
                    OR (copado__Environment__c = NULL
                    AND copado__Stage__c != NULL)
                    OR (copado__Environment__c = NULL
                    AND copado__Stage__c = NULL
                    AND copado__Pipeline__c IN :pipelineIds))
                WITH USER_MODE
                ORDER BY Name
            ];
            System.debug('**F**rules : ' + rules.size());

            // Create wrapper objects
            List<PipelineOperations.AutomationRuleWrapper> wrappers = new List<PipelineOperations.AutomationRuleWrapper>();
            for (copado__Automation_Rule__c rule : rules) {
                System.debug('**F**rule : ' + rule);
                Boolean isApplicable = false;

                PipelineOperations.AutomationRuleWrapper wrapper = new PipelineOperations.AutomationRuleWrapper(rule);
                System.debug('**F**wrapper : ' + wrapper);

                System.debug('**F**rule.copado__Automation_Connector__c : ' + rule.copado__Automation_Connector__c);

                // Handle back promotion rules
                if (rule.copado__Automation_Connector__c.contains('ACPromotionDeploymentToBackPromotion')) {
                    isApplicable = isEnvironmentIncludedInBackPromotion(environmentId, rule.copado__Config_Json__c);
                }
                // Handle other automation rules
                else {
                    // Check environment level rules
                    System.debug('**F**rule.copado__Environment__c : ' + rule.copado__Environment__c);
                    System.debug('**F**rule.copado__Stage__c : ' + rule.copado__Stage__c);
                    if (String.isNotBlank(rule.copado__Environment__c)) {
                        Set<String> envIds = new Set<String>(rule.copado__Environment__c.split(','));
                        System.debug('**F**envIds : ' + envIds + ' - ' + environmentId);
                        isApplicable = envIds.contains(environmentId);
                    }
                    // Check stage level rules if no environment match
                    else if (String.isNotBlank(rule.copado__Stage__c)) {
                        Set<String> ruleStageIds = new Set<String>(rule.copado__Stage__c.split(','));
                        System.debug('**F**ruleStageIds : ' + ruleStageIds + ' - ' + stageIds);
                        isApplicable = !stageIds.isEmpty() && hasMatchingStage(ruleStageIds, stageIds);
                    }
                    // Check pipeline level rules if no environment or stage match
                    else {
                        isApplicable = true; // Rule applies to entire pipeline
                    }
                }

                System.debug('**F**isApplicable : ' + isApplicable);
                if (isApplicable) {
                    wrappers.add(wrapper);
                }
            }

            result.automationRules = wrappers;
            return result;
        } catch (Exception e) {
            throw new ApplicationException('Error retrieving automation rules: ' + e.getMessage());
        }
    }

    public static PipelineOperations.AutomationRulesConditionResult hasAutomationRule(Id environmentId) {
        PipelineOperations.AutomationRulesConditionResult result = new PipelineOperations.AutomationRulesConditionResult();
        if (environmentId == null) {
            result.hasAutomationRule = false;
            return result;
        }

        try {
            // Get environment relationships
            Map<String, Set<Id>> relationships = getEnvironmentRelationships(environmentId);
            Set<Id> pipelineIds = relationships.get('pipelines');
            Set<Id> stageIds = relationships.get('stages');

            // Query for automation rules
            List<copado__Automation_Rule__c> rules = [
                SELECT Id
                FROM copado__Automation_Rule__c
                WHERE
                    copado__Active__c = TRUE
                    AND (copado__Environment__c LIKE :'%' + environmentId + '%'
                    OR (copado__Environment__c = NULL
                    AND copado__Stage__c != NULL
                    AND copado__Stage__c IN :stageIds)
                    OR (copado__Environment__c = NULL
                    AND copado__Stage__c = NULL
                    AND copado__Pipeline__c IN :pipelineIds))
                WITH USER_MODE
                LIMIT 1
            ];

            result.hasAutomationRule = !rules.isEmpty();
            return result;
        } catch (Exception e) {
            throw new ApplicationException('Error checking automation rules: ' + e.getMessage());
        }
    }

    // PRIVATE

    private static Map<String, Set<Id>> getEnvironmentRelationships(Id environmentId) {
        Map<String, Set<Id>> relationships = new Map<String, Set<Id>>{ 'stages' => new Set<Id>(), 'pipelines' => new Set<Id>() };

        for (copado__Deployment_Flow_Step__c step : [
            SELECT copado__Deployment_Flow__c, copado__Source_Environment__c, copado__Stage_Connection__r.copado__Stage__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Source_Environment__c = :environmentId OR copado__Destination_Environment__c = :environmentId
            WITH USER_MODE
        ]) {
            relationships.get('pipelines').add(step.copado__Deployment_Flow__c);
            if (step.copado__Source_Environment__c == environmentId && step.copado__Stage_Connection__r?.copado__Stage__c != null) {
                relationships.get('stages').add(step.copado__Stage_Connection__r.copado__Stage__c);
            }
        }

        return relationships;
    }

    private static Boolean isEnvironmentIncludedInBackPromotion(Id environmentId, String configJson) {
        if (String.isBlank(configJson)) {
            return true; // If no config JSON, environment is included
        }

        try {
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(configJson);
            List<Object> excludedEnvs = (List<Object>) configMap.get('excludedEnvironmentsForBackPromotion');
            System.debug('**F**excludedEnvs : ' + excludedEnvs);
            System.debug('**F**environmentId : ' + environmentId);
            if (excludedEnvs == null || excludedEnvs.isEmpty()) {
                return true;
            }

            // Check if environment is not in excluded list
            return !excludedEnvs.contains(environmentId);
        } catch (Exception e) {
            // If there's an error parsing JSON, log it and return true to be safe
            System.debug('Error parsing configJson: ' + e.getMessage());
            return true;
        }
    }

    private static Boolean hasMatchingStage(Set<String> ruleStageIds, Set<Id> environmentStageIds) {
        for (String ruleStageId : ruleStageIds) {
            System.debug('**F**ruleStageId : ' + ruleStageId);
            System.debug('**F**environmentStageIds : ' + environmentStageIds);
            if (environmentStageIds.contains(Id.valueOf(ruleStageId))) {
                return true;
            }
        }
        return false;
    }
}