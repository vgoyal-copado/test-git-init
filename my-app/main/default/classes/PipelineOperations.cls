public inherited sharing class PipelineOperations implements CopadoDomain {
    /************ PIPELINE OPERATIONS ***********************/

    //SKELETON Attribute
    public static PipelineOperationsService PipelineOperationsService {
        get {
            if (PipelineOperationsService == null) {
                PipelineOperationsService = new PipelineOperationsService();
            }
            return PipelineOperationsService;
        }
        set;
    }

    public inherited sharing class PipelineOperationsService implements CopadoService {
        /*public PipelineResult getActivePipelines() {
            try {
                return PipelineOperationsServiceImpl.getActivePipelines();
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public CredentialDetailsResult getCredentialDetails(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.getCredentialDetails(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public JobExecutionsResult getJobExecutions(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.getJobExecutions(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public UserStoriesResult getUserStories(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.getUserStories(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public SystemPropertiesResult getSystemProperties(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.getSystemProperties(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }*/

        public QualityGatesRuleConditionResult hasQualityGateRuleCondition(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.hasQualityGateRuleCondition(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public QualityGatesResult getQualityGates(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.getQualityGateRules(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public AutomationRulesResult getAutomationRules(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.getAutomationRules(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public AutomationRulesConditionResult hasAutomationRule(Id environmentId) {
            try {
                return PipelineOperationsServiceImpl.hasAutomationRule(environmentId);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        /*public JobQueueResult getJobQueue() {
            try {
                return PipelineOperationsServiceImpl.getJobQueue();
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }*/
    }

    /*@JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class PipelineResult implements CopadoServiceResult {
        public List<copado__Deployment_Flow__c> activePipelines;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class CredentialDetailsResult implements CopadoServiceResult {
        public copado__Org__c credential;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class JobExecutionsResult implements CopadoServiceResult {
        public List<copado__JobExecution__c> jobExecutions;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class UserStoriesResult implements CopadoServiceResult {
        public List<copado__User_Story__c> userStories;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class SystemPropertiesResult implements CopadoServiceResult {
        public List<copado__System_Property__c> systemProperties;
    }
        
    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class JobQueueResult implements CopadoServiceResult {
        public Integer queuedJobsCount;
        public List<copado__JobExecution__c> queuedJobs;
    }*/

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class QualityGatesResult implements CopadoServiceResult {
        public List<QualityGateWrapper> qualityGates;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class QualityGatesRuleConditionResult implements CopadoServiceResult {
        public Boolean hasQualityGate;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class AutomationRulesResult implements CopadoServiceResult {
        public List<AutomationRuleWrapper> automationRules;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class AutomationRulesConditionResult implements CopadoServiceResult {
        public Boolean hasAutomationRule;
    }

    // WRAPPER

    public class QualityGateWrapper {
        @AuraEnabled
        public Id ruleId { get; set; }
        @AuraEnabled
        public Id conditionId { get; set; }
        @AuraEnabled
        public String ruleName { get; set; }
        @AuraEnabled
        public String tool { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String executionSequence { get; set; }
        @AuraEnabled
        public String actions { get; set; }
        @AuraEnabled
        public String testsFrom { get; set; }
        @AuraEnabled
        public Id environmentId { get; set; }
        @AuraEnabled
        public Id stageId { get; set; }
        @AuraEnabled
        public Id pipelineId { get; set; }
        //@AuraEnabled
        // public String acceptanceCriteria { get; set; }
        @AuraEnabled
        public String matchType { get; set; } // 'Environment', 'Stage', or 'Pipeline'

        public QualityGateWrapper(copado__Quality_Gate_Rule__c rule, copado__Quality_Gate_Rule_Condition__c condition) {
            // Rule details
            this.ruleId = rule.Id;
            this.ruleName = rule.Name;
            this.tool = rule.copado__Tool__c;
            this.status = rule.copado__Status__c;
            this.executionSequence = rule.copado__Execution_sequence__c;
            this.actions = rule.copado__Actions__c;

            // Condition details
            if (condition != null) {
                this.conditionId = condition.Id;
                this.testsFrom = condition.copado__Tests_From__c;
                //this.acceptanceCriteria = condition.copado__Acceptance_Criteria__c;

                // Environment details
                this.environmentId = condition.copado__Environment__c;

                // Stage details
                this.stageId = condition.copado__Stage__c;

                // Pipeline details
                this.pipelineId = condition.copado__Pipeline__c;

                // Determine match type
                if (condition.copado__Environment__c != null) {
                    this.matchType = 'Environment';
                } else if (condition.copado__Stage__c != null) {
                    this.matchType = 'Stage';
                } else if (condition.copado__Pipeline__c != null) {
                    this.matchType = 'Pipeline';
                }
            }
        }
    }

    public class AutomationRuleWrapper {
        @AuraEnabled
        public Id ruleId { get; set; }
        @AuraEnabled
        public String ruleName { get; set; }
        @AuraEnabled
        public List<String> environmentIds { get; set; }
        @AuraEnabled
        public List<String> stageIds { get; set; }
        @AuraEnabled
        public Id pipelineId { get; set; }

        public AutomationRuleWrapper(copado__Automation_Rule__c rule) {
            this.ruleId = rule.Id;
            this.ruleName = rule.Name;

            // Handle Environment IDs (comma-separated string to List)
            this.environmentIds = new List<String>();
            if (String.isNotBlank(rule.copado__Environment__c)) {
                this.environmentIds = rule.copado__Environment__c.split(',');
            }

            // Handle Stage IDs (comma-separated string to List)
            this.stageIds = new List<String>();
            if (String.isNotBlank(rule.copado__Stage__c)) {
                this.stageIds = rule.copado__Stage__c.split(',');
            }

            // Pipeline details (lookup field)
            this.pipelineId = rule.copado__Pipeline__c;
        }
    }
}