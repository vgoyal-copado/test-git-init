public with sharing class OverviewLatestPromotionsController {
    private static final String OK = 'ok';
    private static final String KO = 'ko';

    private static final String DESC_ORDER = 'DESC';
    private static final String ASC_ORDER = 'ASC';
    private static final Set<String> ORDERS = new Set<String>{DESC_ORDER, ASC_ORDER};
    private static final Integer DEFAULT_QUERY_LIMIT = 7;
    private static final String DEFAULT_QUERY_ORDER_BY = 'CreatedDate';
    private static final String DEFAULT_QUERY_ORDER_DIRECTION = DESC_ORDER;
    private static final Set<String> JOB_STEP_ACCEPTABLE_STATUSES = new Set<String>{'In Progress', 'Success', 'Failed'};
    private static final String SUCCESSFUL = 'Successful';
    private static final String COMPLETED = 'Completed';
    private static final String SFDX_DEPLOY = 'SFDX Deploy';
    private static final String SFDX_VLOCITY_DEPLOY = 'SFDX Vlocity Deploy';
    private static final Set<String> DEPLOY_TEMPLATE_NAMES = new Set<String>{SFDX_DEPLOY, SFDX_VLOCITY_DEPLOY};
    private static Set<Id> deployTemplateIds = new Set<Id>();
    private static final Map<String,String> FIELD_APIS_BY_COLUMN_NAMES = new Map<String,String>{
        'promotionUrl' => 'Name',
        'sourceEnvironmentUrl' => 'copado__Source_Environment__r.Name',
        'destinationEnvironmentUrl' => 'copado__Destination_Environment__r.Name',
        'status' => 'copado__Status__c',
        'createdDate' => 'CreatedDate',
        'lastModifiedDate' => 'LastModifiedDate'
    };
    
    private static final String BASE_FIELDS = String.join(new List<String>{
        'Id', 
        'Name',
        'copado__Source_Environment__r.Name', 
        'copado__Source_Environment__c',
        'copado__Destination_Environment__r.Name', 
        'copado__Destination_Environment__c',
        'copado__Status__c', 
        'copado__Back_Promotion__c', 
        'CreatedDate', 
        'LastModifiedDate'
    }, ', ');

    @AuraEnabled(cacheable=true)
    public static Integer getLatestPromotionsTotalRecords(String params){
        OverviewPipelineTablesHelper.LwcParams lwcParams =
            (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

        if (lwcParams == null || lwcParams.selectedPipelineId == null) {
            return 0;
        }

        try {
            return Database.countQuery(getLatestPromotionsQuery(new QueryParams(
                lwcParams.selectedPipelineId,
                lwcParams.selectedProjectId,
                lwcParams.selectedReleaseId,
                lwcParams.promotionStatus,
                lwcParams.promotionType,
                lwcParams.timePeriod,
                null, null, true, null, null, null
            )));
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PromotionWrapper> getLatestPromotions(String params) {
        OverviewPipelineTablesHelper.LwcParams lwcParams =
            (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

        if (lwcParams == null || lwcParams.selectedPipelineId == null) {
            return new List<PromotionWrapper>();
        }

        try {
            List<copado__Promotion__c> promotions = Database.query(
                getLatestPromotionsQuery(
                    new QueryParams(
                        lwcParams.selectedPipelineId,
                        lwcParams.selectedProjectId,
                        lwcParams.selectedReleaseId,
                        lwcParams.promotionStatus,
                        lwcParams.promotionType,
                        lwcParams.timePeriod,
                        lwcParams.queryLimit,
                        lwcParams.offset,
                        false,
                        lwcParams.searchTerm,
                        lwcParams.orderBy,
                        lwcParams.orderDirection
                    )
                )
            );

            Map<Id, List<LatestTestsRunsController.TestWrapper>> testsByPromotion = LatestTestsRunsController.getTests(
                new List<Id>(new Map<Id, copado__Promotion__c>(promotions).keySet())
            );

            setTemplates(lwcParams.selectedPipelineId);
            return wrapPromotions(promotions, testsByPromotion);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    private static String getLatestPromotionsQuery(QueryParams params) {
        String queryString = 'SELECT ' + (params.isCount ? 'COUNT()' : getQueryFields());
        queryString += ' FROM copado__Promotion__c';

        OverviewPipelineTablesHelper.BaseConditionsParams baseConditionsParams =
            new OverviewPipelineTablesHelper.BaseConditionsParams();
        baseConditionsParams.selectedPipelineId = params.pipelineId;
        baseConditionsParams.selectedProjectId = params.projectId;
        baseConditionsParams.selectedReleaseId = params.releaseId;
        baseConditionsParams.promotionType = params.type;
        baseConditionsParams.timePeriod = params.timePeriod;
        baseConditionsParams.status = params.status;

        List<String> conditions = OverviewPipelineTablesHelper.buildBaseConditions(
            baseConditionsParams
        );

        if (!params.isCount && String.isNotBlank(params.searchTerm)) {
            String searchValue = '%' + String.escapeSingleQuotes(params.searchTerm) + '%';
            conditions.add('(Name LIKE \'' + searchValue + '\' ' +
                         'OR copado__Source_Environment__r.Name LIKE \'' + searchValue + '\' ' +
                         'OR copado__Destination_Environment__r.Name LIKE \'' + searchValue + '\' ' +
                         'OR copado__Status__c LIKE \'' + searchValue + '\')');
        }

        if (!conditions.isEmpty()) {
            queryString += ' WHERE ' + String.join(conditions, ' AND ');
        }

        queryString += ' WITH USER_MODE';

        if (!params.isCount) {
            queryString += ' ORDER BY ' + params.orderBy + ' ' + params.orderDirection + ' LIMIT ' + params.limitNum + ' OFFSET ' + params.offsetNum;
        }

        return queryString;
    }

    private static String getQueryFields() {
        String jobExecutionsSubquery =
            '(SELECT Id, copado__Status__c, copado__Template__r.Name, copado__ErrorMessage__c, CreatedDate, ' +
                '(SELECT Id, Name, copado__Status__c, copado__Order__c, LastModifiedDate, ' +
                    '(SELECT Id, Name, copado__Progress_Status__c, copado__Duration__c ' +
                    'FROM copado__Results__r ORDER BY CreatedDate DESC LIMIT 1) ' +
                'FROM copado__JobSteps__r WHERE copado__Status__c IN :JOB_STEP_ACCEPTABLE_STATUSES ' +
                'ORDER BY copado__Order__c DESC) ' +
            'FROM copado__JobExecutions__r ORDER BY CreatedDate DESC)';

        String deploymentsSubquery = '(SELECT Id, ' + jobExecutionsSubquery + ' FROM copado__Deployments__r' +
            ' ORDER BY CreatedDate DESC)';

        return BASE_FIELDS + ', ' + jobExecutionsSubquery + ', ' + deploymentsSubquery;
    }

    private static List<PromotionWrapper> wrapPromotions(
        List<copado__Promotion__c> promotions,
        Map<Id, List<LatestTestsRunsController.TestWrapper>> testsByPromotion
    ) {
        List<PromotionWrapper> wrappedPromotions = new List<PromotionWrapper>();
        
        for(copado__Promotion__c promotion : promotions) {
            wrappedPromotions.add(new PromotionWrapper(promotion, testsByPromotion.get(promotion.Id)));
        }
        
        return wrappedPromotions;
    }

    private static void setTemplates(Id pipelineId) {
        List<copado__Pipeline_Action__c> pipelineActions = [
            SELECT copado__Job_Template__c
            FROM copado__Pipeline_Action__c
            WHERE copado__Pipeline__c = :pipelineId
            AND copado__Job_Template__r.Name = :DEPLOY_TEMPLATE_NAMES
            WITH USER_MODE
        ];

        for (copado__Pipeline_Action__c pipelineAction : pipelineActions) {
            deployTemplateIds.add(pipelineAction.copado__Job_Template__c);
        }
    }

    private static copado__JobExecution__c getLatestJobExecution(copado__Promotion__c promotion) {
        copado__JobExecution__c deploymentJobExecution = getDeploymentJobExecution(promotion);
        copado__JobExecution__c directJobExecution = getDirectJobExecution(promotion);
        
        if (deploymentJobExecution != null && directJobExecution != null) {
            return deploymentJobExecution.CreatedDate > directJobExecution.CreatedDate ? 
                deploymentJobExecution : directJobExecution;
        }
        
        return deploymentJobExecution != null ? deploymentJobExecution : directJobExecution;
    }
    
    private static copado__JobExecution__c getDeploymentJobExecution(copado__Promotion__c promotion) {
        if (!promotion?.copado__Deployments__r?.isEmpty() && 
            !promotion.copado__Deployments__r[0]?.copado__JobExecutions__r?.isEmpty()) {
            return promotion.copado__Deployments__r[0].copado__JobExecutions__r[0];
        }
        return null;
    }
    
    private static copado__JobExecution__c getDirectJobExecution(copado__Promotion__c promotion) {
        if (!promotion?.copado__JobExecutions__r?.isEmpty()) {
            return promotion.copado__JobExecutions__r[0];
        }
        return null;
    }

    private static copado__JobStep__c getLatestJobStep(copado__Promotion__c promotion) {
        copado__JobStep__c deploymentJobStep = getDeploymentJobStep(promotion);
        copado__JobStep__c directJobStep = getDirectJobStep(promotion);
        
        if (deploymentJobStep != null && directJobStep != null) {
            return deploymentJobStep.LastModifiedDate > directJobStep.LastModifiedDate ? 
                deploymentJobStep : directJobStep;
        }
        
        return deploymentJobStep != null ? deploymentJobStep : directJobStep;
    }

    private static copado__JobStep__c getDeploymentJobStep(copado__Promotion__c promotion) {
        if (!promotion?.copado__Deployments__r?.isEmpty() && 
            !promotion.copado__Deployments__r[0]?.copado__JobExecutions__r?.isEmpty() &&
            !promotion.copado__Deployments__r[0].copado__JobExecutions__r[0]?.copado__JobSteps__r?.isEmpty()) {
            return promotion.copado__Deployments__r[0].copado__JobExecutions__r[0].copado__JobSteps__r[0];
        }
        return null;
    }

    private static copado__JobStep__c getDirectJobStep(copado__Promotion__c promotion) {
        if (
            !promotion.copado__JobExecutions__r?.isEmpty() &&
            !promotion.copado__JobExecutions__r[0].copado__JobSteps__r?.isEmpty()
        ) {
            return promotion.copado__JobExecutions__r[0].copado__JobSteps__r[0];
        }
        return null;
    }

    private class QueryParams {
        Id pipelineId;
        Id projectId;
        Id releaseId;
        String status;
        String type;
        String timePeriod;
        String searchTerm;
        String orderBy;
        String orderDirection;
        Integer limitNum;
        Integer offsetNum;
        Boolean isCount;
        
        QueryParams(Id pipelinedId, Id projectId, Id releaseId, String status, String type, String timeperiod, 
                   Integer queryLimit, Integer offset, Boolean isCount, String searchTerm, String orderBy,
                   String orderDirection) {
            this.pipelineId = pipelinedId;
            this.projectId = projectId;
            this.releaseId = releaseId;
            this.status = status;
            this.type = type;
            this.timePeriod = timeperiod;
            this.limitNum = queryLimit != null ? queryLimit : DEFAULT_QUERY_LIMIT;
            this.offsetNum = offset != null ? offset : 0;
            this.isCount = isCount;
            this.searchTerm = searchTerm;
            this.setOrderFields(orderBy, orderDirection);
        }

        private void setOrderFields(String orderBy, String orderDirection) {
            setOrderBy(orderBy);
            this.orderDirection = String.isBlank(orderDirection) || !ORDERS.contains(orderDirection.toUpperCase()) ?
                DEFAULT_QUERY_ORDER_DIRECTION : orderDirection;
        }

        private void setOrderBy(string orderBy) {
            if (String.isBlank(orderBy)) {
                this.orderBy = DEFAULT_QUERY_ORDER_BY;
            }

            String fieldApiName = FIELD_APIS_BY_COLUMN_NAMES.get(orderBy);
            this.orderBy = String.isBlank(fieldApiName) ? DEFAULT_QUERY_ORDER_BY : fieldApiName;
        }
    }

    public class PromotionWrapper {
        @AuraEnabled public String id { get; private set; }
        @AuraEnabled public String name { get; private set; }
        @AuraEnabled public String status { get; private set; }
        @AuraEnabled public Datetime createdDate { get; private set; }
        @AuraEnabled public Datetime lastModifiedDate { get; private set; }
        @AuraEnabled public String promotionUrl { get; private set; }
        @AuraEnabled public String sourceEnvironmentUrl { get; private set; }
        @AuraEnabled public String sourceEnvironmentName { get; private set; }
        @AuraEnabled public String destinationEnvironmentUrl { get; private set; }
        @AuraEnabled public String destinationEnvironmentName { get; private set; }
        @AuraEnabled public String latestJobStepUrl { get; private set; }
        @AuraEnabled public String latestJobStepName { get; private set; }
        @AuraEnabled public String latestMsg { get; private set; }
        @AuraEnabled public String isDeployed { get; private set; }
        @AuraEnabled public String qualityResult { get; private set; }

        public PromotionWrapper(copado__Promotion__c promotion, List<LatestTestsRunsController.TestWrapper> tests) {
            this.initializeBasicFields(promotion);
            this.initializeUrlFields(promotion);
            this.initializeJobInformation(promotion);
            this.setQualityResult(tests);
        }

        private void initializeBasicFields(copado__Promotion__c promotion) {
            this.id = promotion.Id;
            this.name = promotion.Name;
            this.status = promotion.copado__Status__c;
            this.createdDate = promotion.CreatedDate;
            this.lastModifiedDate = promotion.LastModifiedDate;
            this.isDeployed = checkIsDeployed(promotion);
        }

        private String checkIsDeployed(copado__Promotion__c promotion) {
            List<copado__Deployment__c> deployments = promotion.copado__Deployments__r;

            if (
                deployments != null &&
                !deployments.isEmpty() &&
                deployments[0].copado__JobExecutions__r != null &&
                !deployments[0].copado__JobExecutions__r.isEmpty() &&
                deployments[0].copado__JobExecutions__r[0].copado__Status__c?.equals(SUCCESSFUL) &&
                promotion.copado__Status__c?.equals(COMPLETED)
            ) {
                return Label.Yes;
            }

            return Label.No;
        }

        private void initializeUrlFields(copado__Promotion__c promotion) {
            this.promotionUrl = '/' + promotion.Id;
            this.sourceEnvironmentUrl = promotion.copado__Source_Environment__c != null ? 
                '/' + promotion.copado__Source_Environment__c : '';
            this.sourceEnvironmentName = promotion.copado__Source_Environment__r?.Name;
            this.destinationEnvironmentUrl = promotion.copado__Destination_Environment__c != null ? 
                '/' + promotion.copado__Destination_Environment__c : '';
            this.destinationEnvironmentName = promotion.copado__Destination_Environment__r?.Name;
        }

        private void initializeJobInformation(copado__Promotion__c promotion) {
            if(!promotion.copado__JobExecutions__r?.isEmpty()) {
                copado__JobExecution__c latestExecution = getLatestJobExecution(promotion);
                this.latestMsg = latestExecution.copado__ErrorMessage__c;

                copado__JobStep__c latestStep = getLatestJobStep(promotion);
                this.latestJobStepUrl = '/' + latestStep?.Id;
                this.latestJobStepName = latestStep?.Name;
                
                if(latestStep != null && !latestStep?.copado__Results__r?.isEmpty()) {
                    this.qualityResult = latestStep?.copado__Results__r[0].copado__Progress_Status__c;
                }
            }

            this.latestJobStepName = this.latestJobStepName ?? Label.NA;
            this.latestMsg = this.latestMsg ?? Label.NA;
            this.qualityResult = this.qualityResult ?? Label.NA;
        }

        private void setQualityResult(List<LatestTestsRunsController.TestWrapper> tests) {
            if(tests == null || tests.isEmpty()) {
                this.qualityResult = Label.None;
                return;
            }
        
            Boolean hasFailedTests = false;
            Boolean hasInProgressTests = false;
            Boolean hasNotStartedTests = false;
            Boolean hasSuccessfulTests = false;
        
            for(LatestTestsRunsController.TestWrapper test : tests) {
                switch on test.status {
                    when 'Failed', 'Cancelled' {
                        hasFailedTests = true;
                    }
                    when 'In Progress' {
                        hasInProgressTests = true;
                    }
                    when 'Not Started' {
                        hasNotStartedTests = true;
                    }
                    when 'Success' {
                        hasSuccessfulTests = true;
                    }
                }
            }
        
            if(hasFailedTests) {
                this.qualityResult = KO;
            } else if(hasInProgressTests || hasNotStartedTests) {
                this.qualityResult = Label.Unknown;
            } else if(hasSuccessfulTests) {
                this.qualityResult = OK;
            } else {
                this.qualityResult = Label.None;
            }
        }
    }
}