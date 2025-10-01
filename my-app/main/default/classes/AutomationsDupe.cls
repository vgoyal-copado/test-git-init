/*
**************************************************************************************************
DO NOT DEPLOY OR DELETE THIS CLASS. THIS IS NEEDED FOR TESTING
**************************************************************************************************
*/
@SuppressWarnings('PMD.VariableNamingConventions,PMD.PropertyNamingConventions')
public with sharing class AutomationsDupe {
    //SKELETON Attribute
    public static ConvertService ConvertService {
        get {
            if (ConvertService == null) {
                ConvertService = new ConvertService();
            }
            return ConvertService;
        }
        set;
    }

    public inherited sharing class ConvertService implements CopadoService {
        public ConvertResult convert(ConvertRequest request) {
            Savepoint sp = Database.setSavepoint();
            try {
                return ConvertServiceImplDupe.execute(request);
            } catch (Exception ex) {
                Database.rollback(sp);
                throw new ApplicationException(ex.getMessage());
            }
        }
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class ConvertRequest implements CopadoServiceRequest {
        public List<copado__Automation_Rule__c> automationRules;
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class ConvertResult implements CopadoServiceResult {
        public String configurationJson;
    }

    // Inner classes for JSON structure
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