/*
**************************************************************************************************
DO NOT DEPLOY OR DELETE THIS CLASS. THIS IS NEEDED FOR TESTING
**************************************************************************************************
*/
public with sharing class ConvertServiceImplDupe {
     //============================================================
    // CONSTANTS
    //============================================================
    private static final String CONNECTOR_FORWARD = 'ACPromotionDeploymentToPromotion';
    private static final String CONNECTOR_BACK = 'ACPromotionDeploymentToBackPromotion';
    private static final String SUBMIT = 'Submit';

    //============================================================
    // PRIVATE PROPERTIES
    //============================================================
    private static List<copado__Deployment_Flow_Step__c> flowSteps;

    //============================================================
    // PUBLIC API METHODS
    //============================================================
    public static AutomationsDupe.ConvertResult execute(AutomationsDupe.ConvertRequest request) {
        validateRequest(request);
        loadFlowSteps(request.automationRules);
        return buildConvertResult(request.automationRules);
    }

    //============================================================
    // VALIDATION METHODS
    //============================================================
    private static void validateRequest(AutomationsDupe.ConvertRequest request) {
        if (request.automationRules == null || request.automationRules.isEmpty()) {
            throw new AutomationException('Automation rules cannot be null or empty');
        }
    }

    //============================================================
    // DATA LOADING METHODS
    //============================================================
    private static void loadFlowSteps(List<copado__Automation_Rule__c> rules) {
        Set<Id> pipelineIds = new Set<Id>();
        for (copado__Automation_Rule__c rule : rules) {
            pipelineIds.add(rule.copado__Pipeline__c);
        }

        flowSteps = [
            SELECT Id, copado__Stage_Connection__r.copado__Stage__c, copado__Source_Environment__c, copado__Destination_Environment__c, copado__Deployment_Flow__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Deployment_Flow__c IN :pipelineIds
            WITH USER_MODE
        ];
    }

    //============================================================
    // RESULT BUILDING METHODS
    //============================================================
    private static AutomationsDupe.ConvertResult buildConvertResult(List<copado__Automation_Rule__c> rules) {
        AutomationsDupe.ConvertResult result = new AutomationsDupe.ConvertResult();
        AutomationConfigWrapper wrapper = new AutomationConfigWrapper();
        wrapper.automations = processAutomationRules(rules);
        result.configurationJson = JSON.serialize(wrapper, true);
        return result;
    }

    //============================================================
    // AUTOMATION RULE PROCESSING METHODS
    //============================================================
    private static List<AutomationsDupe.AutomationConfig> processAutomationRules(List<copado__Automation_Rule__c> rules) {
        List<AutomationsDupe.AutomationConfig> configs = new List<AutomationsDupe.AutomationConfig>();

        for (copado__Automation_Rule__c rule : rules) {
            AutomationsDupe.AutomationConfig config = initializeAutomationConfig(rule);
            processRuleFormat(rule, config);
            configs.add(config);
        }

        return configs;
    }

    private static void processRuleFormat(copado__Automation_Rule__c rule, AutomationsDupe.AutomationConfig config) {
        if (isOldDataFormat(rule)) {
            config.stages = new List<AutomationsDupe.StageConfig>();
            processOldFormatRule(rule, config);
        } else {
            processNewFormatRule(rule, config);
        }
    }

    //============================================================
    // FORMAT DETECTION METHODS
    //============================================================
    private static Boolean isOldDataFormat(copado__Automation_Rule__c rule) {
        Boolean hasOldFields = hasOldFormatFields(rule);
        if (!String.isBlank(rule.copado__Config_Json__c)) {
            return isOldConfigJson(rule.copado__Config_Json__c);
        }
        return hasOldFields;
    }

    private static Boolean hasOldFormatFields(copado__Automation_Rule__c rule) {
        return String.isNotBlank(rule.copado__Environment__c) || String.isNotBlank(rule.copado__Stage__c) || String.isNotBlank(rule.copado__Excluded_Environments__c);
    }

    private static Boolean isOldConfigJson(String configJson) {
        try {
            Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(configJson);
            return configMap.containsKey('excludedEnvironmentsForBackPromotion');
        } catch (Exception e) {
            return false;
        }
    }

    //============================================================
    // CONFIGURATION INITIALIZATION METHODS
    //============================================================
    private static AutomationsDupe.AutomationConfig initializeAutomationConfig(copado__Automation_Rule__c rule) {
        AutomationsDupe.AutomationConfig config = new AutomationsDupe.AutomationConfig();

        String ruleId = '';

        if (String.isNotBlank(rule.Id)) {
            ruleId = rule.Id;
        }

        config.ruleId = ruleId;
        config.ruleName = rule.Name != null ? rule.Name : '';
        config.automationConnector = rule.copado__Automation_Connector__c != null ? rule.copado__Automation_Connector__c : '';
        config.sourceAction = rule.copado__Source_Action__c != null ? rule.copado__Source_Action__c : '';
        config.automatedAction = rule.copado__Automated_Action__c != null ? rule.copado__Automated_Action__c : '';
        config.active = rule.copado__Active__c != null ? rule.copado__Active__c : false;
        config.scope = '';
        config.isAppliedToPipeline = !isOldDataFormat(rule);
        config.environments = new List<String>();
        config.environmentsForBackPromotion = new List<String>();
        config.stages = initializeStages(rule);

        return config;
    }

    private static List<AutomationsDupe.StageConfig> initializeStages(copado__Automation_Rule__c rule) {
        List<AutomationsDupe.StageConfig> stages = new List<AutomationsDupe.StageConfig>();

        if (String.isNotBlank(rule.copado__Stage__c)) {
            List<String> stageIds = rule.copado__Stage__c.split(',');
            for (String stageId : stageIds) {
                stages.add(initializeStageConfig(stageId.trim()));
            }
        }

        if (stages.isEmpty()) {
            stages.add(initializeStageConfig(''));
        }

        return stages;
    }

    private static AutomationsDupe.StageConfig initializeStageConfig(String stageId) {
        AutomationsDupe.StageConfig stageConfig = new AutomationsDupe.StageConfig();

        stageConfig.id = stageId;
        stageConfig.isAppliedToStage = false;
        stageConfig.environments = new List<String>();
        stageConfig.environmentsForBackPromotion = new List<String>();

        return stageConfig;
    }

    //============================================================
    // RULE PROCESSING METHODS
    //============================================================
    private static void processOldFormatRule(copado__Automation_Rule__c rule, AutomationsDupe.AutomationConfig config) {
        RuleProcessor processor = new RuleProcessor(rule, config);
        processor.process();
    }

    private static void processNewFormatRule(copado__Automation_Rule__c rule, AutomationsDupe.AutomationConfig config) {
        if (String.isBlank(rule.copado__Config_Json__c)) {
            return;
        }

        try {
            updateConfigFromJson(rule.copado__Config_Json__c, config);
            initializeNullCollections(config);
        } catch (JSONException e) {
            throw new AutomationException('Invalid JSON format in copado__Config_Json__c: ' + e.getMessage());
        }
    }

    private static void updateConfigFromJson(String configJson, AutomationsDupe.AutomationConfig config) {
        AutomationsDupe.AutomationConfig newConfig = (AutomationsDupe.AutomationConfig) JSON.deserialize(configJson, AutomationsDupe.AutomationConfig.class);

        config.stages = !newConfig.stages.isEmpty() ? newConfig.stages : new List<AutomationsDupe.StageConfig>();
        config.environments = !newConfig.environments.isEmpty() ? newConfig.environments : new List<String>();
        config.scope = newConfig.scope;
        config.environmentsForBackPromotion = !newConfig.environmentsForBackPromotion.isEmpty()
            ? newConfig.environmentsForBackPromotion
            : new List<String>();
        config.active = newConfig.active;
        config.automatedAction = newConfig.automatedAction;
        config.automationConnector = newConfig.automationConnector;
        config.isAppliedToPipeline = newConfig.isAppliedToPipeline;
        config.ruleName = newConfig.ruleName;
        config.sourceAction = newConfig.sourceAction;
    }

    //============================================================
    // UTILITY METHODS
    //============================================================
    private static void initializeNullCollections(AutomationsDupe.AutomationConfig config) {
        if (config.scope == null) {
            config.scope = '';
        }

        if (config.environments == null) {
            config.environments = new List<String>();
        }
        if (config.environmentsForBackPromotion == null) {
            config.environmentsForBackPromotion = new List<String>();
        }
        if (config.stages == null) {
            config.stages = new List<AutomationsDupe.StageConfig>();
        }

        for (AutomationsDupe.StageConfig stage : config.stages) {
            if (stage.environments == null) {
                stage.environments = new List<String>();
            }
            if (stage.environmentsForBackPromotion == null) {
                stage.environmentsForBackPromotion = new List<String>();
            }
        }
    }

    private static String determineScope(String connector) {
        String scope;
        if (connector.contains(CONNECTOR_FORWARD) || connector.contains(SUBMIT)) {
            scope = 'forward';
        } else if (connector.contains(CONNECTOR_BACK)) {
            scope = 'back';
        } else {
            scope = 'advanced';
        }
        return scope;
    }

    //============================================================
    // INNER CLASSES
    //============================================================
    private class EnvironmentData {
        private Map<String, List<String>> stageToEnvironmentsMap;
        private List<String> backPromotionEnvironments;
        private Set<String> excludedEnvs;
        private Set<String> excludedBackPromotionEnvs;

        public EnvironmentData(copado__Automation_Rule__c rule) {
            initializeCollections();
            processExcludedEnvironments(rule);
            processConnections(rule);
        }

        private void initializeCollections() {
            stageToEnvironmentsMap = new Map<String, List<String>>();
            backPromotionEnvironments = new List<String>();
            excludedEnvs = new Set<String>();
            excludedBackPromotionEnvs = new Set<String>();
        }

        private void processExcludedEnvironments(copado__Automation_Rule__c rule) {
            processStandardExclusions(rule);
            processJsonExclusions(rule);
        }

        private void processStandardExclusions(copado__Automation_Rule__c rule) {
            if (String.isNotBlank(rule.copado__Excluded_Environments__c)) {
                excludedEnvs.addAll(rule.copado__Excluded_Environments__c.split(','));
            }
        }

        private void processJsonExclusions(copado__Automation_Rule__c rule) {
            if (String.isBlank(rule.copado__Config_Json__c)) {
                return;
            }

            try {
                ConfigJsonData configData = (ConfigJsonData) JSON.deserialize(rule.copado__Config_Json__c, ConfigJsonData.class);
                if (configData.excludedEnvironmentsForBackPromotion != null) {
                    excludedBackPromotionEnvs.addAll(configData.excludedEnvironmentsForBackPromotion);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error parsing config JSON: ' + e.getMessage());
            }
        }

        private void processConnections(copado__Automation_Rule__c rule) {
            processStageConnections(rule);
            processBackPromotionConnections(rule);
        }

        private void processStageConnections(copado__Automation_Rule__c rule) {
            for (copado__Deployment_Flow_Step__c conn : flowSteps) {
                if (canEnvironmentAddedToStage(conn, rule)) {
                    addEnvironmentToStage(conn.copado__Stage_Connection__r.copado__Stage__c, conn.copado__Source_Environment__c);
                }
            }
        }

        private Boolean canEnvironmentAddedToStage(copado__Deployment_Flow_Step__c conn, copado__Automation_Rule__c rule) {
            Set<String> excludedEnvSet = new Set<String>();
            if (String.isNotBlank(rule.copado__Excluded_Environments__c)) {
                excludedEnvSet.addAll(rule.copado__Excluded_Environments__c.split(','));
            }

            return conn.copado__Deployment_Flow__c == rule.copado__Pipeline__c &&
                String.isNotBlank(rule.copado__Stage__c) &&
                String.isNotBlank(conn.copado__Stage_Connection__r.copado__Stage__c) &&
                String.isNotBlank(conn.copado__Source_Environment__c) &&
                !excludedEnvSet.isEmpty() &&
                !excludedEnvSet.contains(conn.copado__Source_Environment__c);
        }

        private void addEnvironmentToStage(String stageId, String environmentId) {
            if (!stageToEnvironmentsMap.containsKey(stageId)) {
                stageToEnvironmentsMap.put(stageId, new List<String>());
            }
            if (!stageToEnvironmentsMap.get(stageId).contains(environmentId)) {
                stageToEnvironmentsMap.get(stageId).add(environmentId);
            }
        }

        private void processBackPromotionConnections(copado__Automation_Rule__c rule) {
            for (copado__Deployment_Flow_Step__c conn : flowSteps) {
                if (isValidBackPromotionConnection(conn, rule)) {
                    addBackPromotionEnvironments(conn, rule);
                }
            }
        }

        private Boolean isValidBackPromotionConnection(copado__Deployment_Flow_Step__c conn, copado__Automation_Rule__c rule) {
            // First check the basic conditions as before
            Boolean basicConditions = conn.copado__Deployment_Flow__c == rule.copado__Pipeline__c && !excludedBackPromotionEnvs.contains(conn.copado__Source_Environment__c);

            // If basic conditions are met, check if destination environment is valid
            if (basicConditions && String.isNotBlank(conn.copado__Destination_Environment__c)) {
                // For old format rules
                if (String.isNotBlank(rule.copado__Environment__c) || String.isNotBlank(rule.copado__Stage__c)) {
                    // If environments are directly specified
                    if (String.isNotBlank(rule.copado__Environment__c)) {
                        List<String> configEnvironments = new List<String>();
                        if (String.isNotBlank(rule.copado__Environment__c) && rule.copado__Environment__c.contains(',')) {
                            configEnvironments = rule.copado__Environment__c.split(',');
                        } else {
                            configEnvironments.add(rule.copado__Environment__c);
                        }
                        return configEnvironments.contains(conn.copado__Destination_Environment__c);
                    }
                    // If stages are specified
                    else if (String.isNotBlank(rule.copado__Stage__c)) {
                        // For stages, we check if the destination is NOT in the excluded environments
                        List<String> configEnvironments = new List<String>();
                        if (String.isNotBlank(rule.copado__Excluded_Environments__c) && rule.copado__Excluded_Environments__c.contains(',')) {
                            configEnvironments = rule.copado__Excluded_Environments__c.split(',');
                        } else {
                            configEnvironments.add(rule.copado__Excluded_Environments__c);
                        }
                        return !configEnvironments.contains(conn.copado__Destination_Environment__c);
                    }
                }

                // For new format rules, check if the destination is in config.environments
                if (!String.isBlank(rule.copado__Config_Json__c)) {
                    try {
                        Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(rule.copado__Config_Json__c);
                        List<Object> environments = (List<Object>) configMap.get('environments');
                        if (environments != null) {
                            return environments.contains(conn.copado__Destination_Environment__c);
                        }
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Error checking destination environment in config: ' + e.getMessage());
                    }
                }
            }

            return basicConditions;
        }

        private void addBackPromotionEnvironments(copado__Deployment_Flow_Step__c conn, copado__Automation_Rule__c rule) {
            if (String.isNotBlank(rule.copado__Stage__c) && String.isNotBlank(conn.copado__Stage_Connection__r.copado__Stage__c)) {
                addStageBackPromotionEnvironments(conn);
            } else {
                addSingleBackPromotionEnvironment(conn.copado__Source_Environment__c);
            }
        }

        private void addStageBackPromotionEnvironments(copado__Deployment_Flow_Step__c conn) {
            String stageId = conn.copado__Stage_Connection__r.copado__Stage__c;
            if (stageToEnvironmentsMap.containsKey(stageId)) {
                for (String envId : stageToEnvironmentsMap.get(stageId)) {
                    addSingleBackPromotionEnvironment(envId);
                }
            }
        }

        private void addSingleBackPromotionEnvironment(String environmentId) {
            if (!backPromotionEnvironments.contains(environmentId)) {
                backPromotionEnvironments.add(environmentId);
            }
        }

        public List<String> getEnvironmentsForStage(String stageId) {
            return stageToEnvironmentsMap.containsKey(stageId) ? stageToEnvironmentsMap.get(stageId) : new List<String>();
        }

        public List<String> getBackPromotionEnvironments() {
            return backPromotionEnvironments;
        }
    }

    private class RuleProcessor {
        private final copado__Automation_Rule__c rule;
        private final AutomationsDupe.AutomationConfig config;
        private final EnvironmentData envData;

        public RuleProcessor(copado__Automation_Rule__c rule, AutomationsDupe.AutomationConfig config) {
            this.rule = rule;
            this.config = config;
            this.envData = new EnvironmentData(rule);
        }

        public void process() {
            setScope();
            setPipelineApplication();
            processStages();
            processEnvironments();
            processBackPromotionEnvironments();
            initializeNullCollections(config);
        }

        private void setScope() {
            config.scope = determineScope(rule.copado__Automation_Connector__c);
        }

        private void setPipelineApplication() {
            config.isAppliedToPipeline =
                String.isBlank(rule.copado__Environment__c) &&
                String.isBlank(rule.copado__Stage__c) &&
                String.isBlank(rule.copado__Excluded_Environments__c);
        }

        private void processStages() {
            if (String.isNotBlank(rule.copado__Stage__c)) {
                Set<String> processedStageIds = new Set<String>();
                for (String stageId : rule.copado__Stage__c.split(',')) {
                    processStage(stageId.trim(), processedStageIds);
                }
            }
        }

        private void processStage(String stageId, Set<String> processedStageIds) {
            if (String.isNotBlank(stageId) && !processedStageIds.contains(stageId)) {
                processedStageIds.add(stageId);
                addStageConfig(stageId);
            }
        }

        private void addStageConfig(String stageId) {
            AutomationsDupe.StageConfig stageConfig = initializeStageConfig(stageId);
            stageConfig.isAppliedToStage = envData.getEnvironmentsForStage(stageId).isEmpty();
            stageConfig.environments = envData.getEnvironmentsForStage(stageId);
            stageConfig.environmentsForBackPromotion = config.scope == 'back' ? envData.getBackPromotionEnvironments() : new List<String>();
            config.stages.add(stageConfig);
        }

        private void processEnvironments() {
            if (String.isNotBlank(rule.copado__Environment__c)) {
                config.environments = rule.copado__Environment__c.split(',');
            }
        }

        private void processBackPromotionEnvironments() {
            if (String.isBlank(rule.copado__Stage__c) && config.scope == 'back') {
                config.environmentsForBackPromotion = envData.getBackPromotionEnvironments();
            }
        }
    }

    public class AutomationConfigWrapper {
        public List<AutomationsDupe.AutomationConfig> automations;
    }

    public class AutomationException extends Exception {
    }

    private class ConfigJsonData {
        public List<String> excludedEnvironmentsForBackPromotion;
    }

    public class AutomationConfig {
        public String ruleId;
        public String ruleName;
        public String automationConnector;
        public String sourceAction;
        public String automatedAction;
        public Boolean active;
        public String scope;
        public Boolean isAppliedToPipeline;
        public List<String> environments;
        public List<String> environmentsForBackPromotion;
        public List<StageConfig> stages;
    }

    public class StageConfig {
        public String id;
        public Boolean isAppliedToStage;
        public List<String> environments;
        public List<String> environmentsForBackPromotion;
    }
}