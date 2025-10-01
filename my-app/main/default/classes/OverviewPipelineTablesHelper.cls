public with sharing class OverviewPipelineTablesHelper {
    private static final String DEPLOYMENT_DRY_RUN = 'deploymentDryRun';
    private static final String LAST_MONTH = 'lastMonth';
    private static final String DATE_FORMAT = 'yyyy-MM-dd\'T\'00:00:00\'Z\'';
    private static final String BACK = 'back';

    public static List<String> buildBaseConditions(
        BaseConditionsParams params
    ) {
        List<String> conditions = new List<String>();
        
        // Escaping single quotes instead of variable binding in order to keep this condition generation method, otherwise
        // the caller method will not have visibility to the variables and this logic will have to be repeated in each
        // query method
        if (String.isNotBlank(params.status)) {
            conditions.add('copado__Status__c = \'' + String.escapeSingleQuotes(params.status) + '\'');
        }
        
        if (String.isNotBlank(params.promotionType)) {
            Boolean isBackPromotion = params.promotionType == BACK;
            conditions.add('copado__Back_Promotion__c = ' + isBackPromotion);
        }
        
        if (String.isNotBlank(params.timePeriod)) {
            conditions.add(getDateCondition(params.timePeriod));
        }

        if (String.isNotBlank(params.selectedPipelineId)) {
            conditions.add('(copado__Pipeline__c = \'' + String.escapeSingleQuotes(params.selectedPipelineId) + '\' ' +
                        'OR copado__Project__r.copado__Deployment_Flow__c = \'' + String.escapeSingleQuotes(params.selectedPipelineId) + '\' ' +
                        'OR copado__Release__r.copado__Project__r.copado__Deployment_Flow__c = \'' + String.escapeSingleQuotes(params.selectedPipelineId)  + '\')');
        }

        if (String.isNotBlank(params.selectedProjectId)) {
            conditions.add('(copado__Project__c = \'' + String.escapeSingleQuotes(params.selectedProjectId) + '\'' +
                        'OR copado__Release__r.copado__Project__c = \'' + String.escapeSingleQuotes(params.selectedProjectId) + '\')');
        }

        if (String.isNotBlank(params.selectedReleaseId)) {
            conditions.add('copado__Release__c = \'' + String.escapeSingleQuotes(params.selectedReleaseId) + '\'');
        }

        return conditions;
    }

    public static String getDateCondition(String timePeriod) {
        if (timePeriod == LAST_MONTH) {
            Date startOfLastMonth = Date.today().addMonths(-1).toStartOfMonth();
            Date startOfCurrentMonth = Date.today().toStartOfMonth();

            return 'CreatedDate >= ' + formatDate(startOfLastMonth) + 
                   ' AND CreatedDate < ' + formatDate(startOfCurrentMonth);
        }

        return 'CreatedDate = LAST_N_DAYS:' + getTimePeriodDays(timePeriod);
    }
    
    private static Integer getTimePeriodDays(String timePeriod) {
        switch on timePeriod {
            when '7' { return 7; }
            when '90' { return 90; }
            when '180' { return 180; }
            when 'thisMonth' { 
                return Date.today().toStartOfMonth().daysBetween(Date.today()) + 1;
            }
            when else { return 30; }
        }
    }
    
    private static String formatDate(Date d) {
        return DateTime.newInstance(
            d.year(), 
            d.month(), 
            d.day()
        ).format(DATE_FORMAT);
    }

    public static Boolean getIsValidation(String dataJson) {
        Map<String, Object> payload = (Map<String, Object>)JSON.deserializeUntyped(dataJson);
        return Boolean.valueOf(payload.get(DEPLOYMENT_DRY_RUN));
    }

    public static Object deserializeParams (String serializedParams, System.Type classType) {
        if (String.isBlank(serializedParams)) {
            return null;
        }

        return JSON.deserialize(serializedParams, classType);
    }

    public class LwcParams {
        public Id selectedPipelineId;
        public Id selectedProjectId;
        public Id selectedReleaseId;
        public Id sourceEnvId;
        public Id destEnvId;
        public Boolean retrieveFailedOnly = false;
        public String promotionStatus;
        public String promotionType;
        public String timePeriod;
        public Boolean includeValidations = false;
        public Integer queryLimit;
        public Integer offset;
        public String searchTerm;
        public String userStoryStatus;
        public String orderBy;
        public String orderDirection;
    }

    public class BaseConditionsParams {
        public Id selectedPipelineId;
        public Id selectedProjectId;
        public Id selectedReleaseId;
        public String promotionType;
        public String timePeriod;
        public String status;
    }
}