public with sharing class OverviewPromotionExecutionStatsCtrl {
    private static final String PROMOTE = 'PROMOTE';
    private static final String DEPLOY = 'DEPLOY';
    private static final String SFDX_PROMOTE = 'SFDX Promote';
    private static final String SFDX_VLOCITY_PROMOTE = 'SFDX Vlocity Promote';
    private static final String SFDX_DEPLOY = 'SFDX Deploy';
    private static final String SFDX_VLOCITY_DEPLOY = 'SFDX Vlocity Deploy';
    private static final Map<String, Set<String>> TEMPLATES_BY_TYPE = new Map<String, Set<String>>{
        PROMOTE => new Set<String>{SFDX_PROMOTE, SFDX_VLOCITY_PROMOTE},
        DEPLOY => new Set<String>{SFDX_DEPLOY, SFDX_VLOCITY_DEPLOY}
    };
    private static final Set<String> TEMPLATES_TO_QUERY = new Set<String>{
        SFDX_PROMOTE, SFDX_VLOCITY_PROMOTE, SFDX_DEPLOY, SFDX_VLOCITY_DEPLOY
    };
    private static Set<Id> TEMPLATE_IDS = new Set<Id>();
    private static final String MANUAL = 'Manual';
    private static final String ERROR = 'Error';
    private static final String SUCCESSFUL = 'Successful';
    private static final Set<String> STATUS_VALUES = new Set<String>{ERROR, SUCCESSFUL};
    private static final String BACK = 'back';
    private static final String NAME = 'Name';
    private static final String ID_FIELD = 'Id';
    private static final Integer DEFAULT_DAYS = 30;
    private static final String PATH_SEPARATOR = '<--sourceDestination-->'; // To avoid coincidences with customers' environment names
    private static final Integer DEFAULT_QUERY_LIMIT = 7;
    private static final Integer DEFAULT_QUERY_OFFSET = 0;
    private static final String DEPLOYMENT_DETAILS_BASE_QUERY = 'SELECT Id, Name, copado__source_environment__c, copado__destination_environment__c, (SELECT Id, ' +
            '(SELECT Id, Name, CreatedById, CreatedBy.Name, copado__ErrorMessage__c, ' +
                'copado__Template__r.Name, copado__Status__c, copado__DataJson__c, ' +
                '(SELECT Id, Name, copado__Status__c, copado__Type__c, ' +
                    '(SELECT Id, copado__Start_Time__c, copado__End_Time__c, copado__Duration__c ' +
                    'FROM copado__Results__r ' +
                    'ORDER BY CreatedDate DESC) ' +
                'FROM copado__JobSteps__r) ' +
            'FROM copado__JobExecutions__r ' +
            'WHERE copado__Template__r.Name IN :deployTemplateNames {0} AND {1} ' +
            'AND copado__Status__c IN :STATUS_VALUES) FROM copado__Deployments__r) ' +
            'FROM copado__Promotion__c ';
    
    private static final String MERGE_DETAILS_BASE_QUERY = 'SELECT Id, Name, copado__source_environment__c, ' +
            '(SELECT Id, Name, CreatedById, CreatedBy.Name, ' +
                'copado__Template__r.Name, copado__Status__c, ' +
                '(SELECT Id, Name, copado__Status__c, ' +
                    '(SELECT Id, copado__Start_Time__c, copado__End_Time__c, copado__Error_Message__c ' +
                    'FROM copado__Results__r ' +
                    'ORDER BY CreatedDate DESC) ' +
                'FROM copado__JobSteps__r ' +
                'ORDER BY CreatedDate DESC LIMIT 1) ' +
            'FROM copado__JobExecutions__r ' +
            'WHERE copado__Status__c IN :STATUS_VALUES ' +
            'AND copado__Template__c IN ' +
                '(SELECT copado__Job_Template__c ' +
                'FROM copado__Pipeline_Action__c ' +
                'WHERE copado__Pipeline__c = :selectedPipelineId ' +
                'AND copado__Job_Template__r.Name = :promoteTemplateNames) {0} ORDER BY CreatedDate DESC) ' +
            'FROM copado__Promotion__c ';
    private enum OrderTypes { ALL, SORTED }

    @AuraEnabled
    @SuppressWarnings('PMD.UnusedLocalVariable')
    public static List<DeploymentDetailWrapper> getDeploymentDetails(String params) {
        try {
            OverviewPipelineTablesHelper.LwcParams lwcParams =
                (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

            if (validateMergeDetailsParams(lwcParams)) {
                return new List<DeploymentDetailWrapper>();
            }

            setBackPromotionEnvironments(lwcParams);

            QueryBuilder builder = getDeploymentsDetailsQuery(lwcParams);

            Id sourceEnvId = lwcParams.sourceEnvId;
            Id destEnvId = lwcParams.destEnvId;
            Id selectedPipelineId = lwcParams.selectedPipelineId;
            Set<String> deployTemplateNames = TEMPLATES_BY_TYPE.get(DEPLOY);

            List<copado__Promotion__c> promotions = Database.query(builder.build());
            return wrapDeploymentDetails(promotions, lwcParams.includeValidations);
        } catch(Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled
    @SuppressWarnings('PMD.UnusedLocalVariable')
    public static List<MergeDetailWrapper> getMergeDetails(String params) {
        try {
            OverviewPipelineTablesHelper.LwcParams lwcParams =
                (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

            if (validateMergeDetailsParams(lwcParams)) {
                return new List<MergeDetailWrapper>();
            }

            setBackPromotionEnvironments(lwcParams);

            QueryBuilder builder = getMergeDetailsQuery(lwcParams);

            Id sourceEnvId = lwcParams.sourceEnvId;
            Id destEnvId = lwcParams.destEnvId;
            Id selectedPipelineId = lwcParams.selectedPipelineId;
            Set<String> promoteTemplateNames = TEMPLATES_BY_TYPE.get(PROMOTE);

            List<copado__Promotion__c> promotions = Database.query(builder.build());
            return wrapMergeDetails(promotions);
        } catch(Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    private static QueryBuilder getDeploymentsDetailsQuery(OverviewPipelineTablesHelper.LwcParams lwcParams) {
        String baseQuery = String.format(
            DEPLOYMENT_DETAILS_BASE_QUERY, new List<String>{
                getJobExecutionConditionErrorsOnly(lwcParams.retrieveFailedOnly),
                getJobExecutionTemplateCondition(lwcParams.selectedPipelineId, false)
            }
        );

        QueryBuilder builder = new QueryBuilder(baseQuery)
            .addCondition('copado__Source_Environment__c = :sourceEnvId')
            .addCondition('copado__Destination_Environment__c = :destEnvId')
            .addCondition(getTimePeriodCondition(lwcParams.timePeriod));

        OverviewPipelineTablesHelper.BaseConditionsParams baseConditionsParams =
            new OverviewPipelineTablesHelper.BaseConditionsParams();
        baseConditionsParams.selectedPipelineId = lwcParams.selectedPipelineId;
        baseConditionsParams.promotionType = lwcParams.promotionType;

        for (String condition : OverviewPipelineTablesHelper.buildBaseConditions(baseConditionsParams)) {
            builder.addCondition(condition);
        }

        return builder;
    }

    private static QueryBuilder getMergeDetailsQuery(OverviewPipelineTablesHelper.LwcParams lwcParams) {
        String baseQuery = String.format(MERGE_DETAILS_BASE_QUERY, new List<String>{
                getJobExecutionConditionErrorsOnly(lwcParams.retrieveFailedOnly)
        });

        QueryBuilder builder = new QueryBuilder(baseQuery)
            .addCondition('copado__Source_Environment__c = :sourceEnvId')
            .addCondition('copado__Destination_Environment__c = :destEnvId')
            .addCondition(getTimePeriodCondition(lwcParams.timePeriod))
            .setLimit(lwcParams.queryLimit)
            .setOffset(lwcParams.offset);

        OverviewPipelineTablesHelper.BaseConditionsParams baseConditionsParams =
            new OverviewPipelineTablesHelper.BaseConditionsParams();
        baseConditionsParams.selectedPipelineId = lwcParams.selectedPipelineId;
        baseConditionsParams.promotionType = lwcParams.promotionType;

        for (String condition : OverviewPipelineTablesHelper.buildBaseConditions(baseConditionsParams)) {
            builder.addCondition(condition);
        }

        return builder;
    }

    private static String getJobExecutionConditionErrorsOnly(Boolean retrieveFailedOnly) {
        return retrieveFailedOnly ? 'AND copado__Status__c = :ERROR' : '';
    }

    @AuraEnabled(cacheable=true)
    public static Integer getExecutionStatsTotalRecords(String params) {
        try {
            OverviewPipelineTablesHelper.LwcParams lwcParams =
                (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

            if (lwcParams == null || lwcParams.selectedPipelineId == null) {
                return 0;
            }

            QueryParams queryParams = new QueryParams();
            queryParams.pipelineId = lwcParams.selectedPipelineId;
            queryParams.queryLimit = 50000;
            queryParams.offset = 0;
            return getPipelineConnections(queryParams).size();
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ExecutionStatWrapper> getExecutionStats(String params) {
        try {
            OverviewPipelineTablesHelper.LwcParams lwcParams =
                (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

            if (lwcParams == null || lwcParams.selectedPipelineId == null) {
                return new List<ExecutionStatWrapper>();
            }

            QueryParams pipelineConnectionsParams = new QueryParams();
            pipelineConnectionsParams.pipelineId = lwcParams.selectedPipelineId;
            pipelineConnectionsParams.queryLimit = lwcParams.queryLimit == null ? DEFAULT_QUERY_LIMIT : lwcParams.queryLimit;
            pipelineConnectionsParams.offset = lwcParams.offset == null ? DEFAULT_QUERY_OFFSET : lwcParams.offset;
            pipelineConnectionsParams.searchTerm = lwcParams.searchTerm;

            List<copado__Deployment_Flow_Step__c> pipelineConnections = getPipelineConnections(pipelineConnectionsParams);

            QueryParams queryParams = new QueryParams();
            queryParams.pipelineId = lwcParams.selectedPipelineId;
            queryParams.projectId = lwcParams.selectedProjectId;
            queryParams.releaseId = lwcParams.selectedReleaseId;
            queryParams.promotionType = lwcParams.promotionType;
            queryParams.timePeriod = lwcParams.timePeriod;
            queryParams.includeValidations = lwcParams.includeValidations;
            queryParams.queryLimit = 50000;
            queryParams.offset = 0;
            queryParams.isCount = false;
            queryParams.pipelineConnections = pipelineConnections;

            List<copado__Promotion__c> promotions = Database.query(getExecutionStatsQuery(queryParams));

            QueryParams calculationParams = new QueryParams();
            calculationParams.includeValidations = lwcParams.includeValidations;
            calculationParams.isBackPromotion = getIsBackPromotion(lwcParams.promotionType);

            return calculateExecutionStats(promotions, pipelineConnections, calculationParams);
        } catch(Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    private static List<copado__Deployment_Flow_Step__c> getPipelineConnections(QueryParams params) {
        List<copado__Deployment_Flow_Step__c> orderedConnections = getOrderedPipelineConnections(
            params.pipelineId, params.searchTerm
        );

        return paginateResults(orderedConnections, params.offset, params.queryLimit);
    }

    private static List<copado__Deployment_Flow_Step__c> getOrderedPipelineConnections(
        Id pipelineId, String searchTerm
    ) {
        List<copado__Deployment_Flow_Step__c> allConnections = 
            new PipelineConnectionsSelector().byPipelineIdAndSearchTerm(
                pipelineId, String.isBlank(searchTerm) ? '' : searchTerm
            );

        Id prodEnvId = new PipelineDescriptor(pipelineId).findFinalEnvironment()?.Id;
        if (prodEnvId == null) {
            return allConnections;
        }

        return orderConnectionsByDestination(allConnections, prodEnvId);
    }

    private static List<copado__Deployment_Flow_Step__c> orderConnectionsByDestination(
        List<copado__Deployment_Flow_Step__c> connections, Id startingDestination
    ) {
        List<copado__Deployment_Flow_Step__c> orderedConnections = new List<copado__Deployment_Flow_Step__c>();
        Set<Id> processedConnections = new Set<Id>();
        Set<Id> currentDestinations = new Set<Id>{startingDestination};

        Map<OrderTypes,List<copado__Deployment_Flow_Step__c>> connectionsByOrderType =
            new Map<OrderTypes,List<copado__Deployment_Flow_Step__c>>{
                OrderTypes.ALL => connections,
                OrderTypes.SORTED => orderedConnections
            };

        while(!currentDestinations.isEmpty()) {
            Set<Id> nextSourceEnvs = processCurrentDestinations(
                currentDestinations, processedConnections, connectionsByOrderType
            );
            currentDestinations = nextSourceEnvs;
        }

        addRemainingConnections(connections, processedConnections, orderedConnections);

        return orderedConnections;
    }

    private static Set<Id> processCurrentDestinations(
        Set<Id> currentDestinations,
        Set<Id> processedConnections,
        Map<OrderTypes,List<copado__Deployment_Flow_Step__c>> connectionsByOrderType
    ) {
        Set<Id> nextSourceEnvs = new Set<Id>();
        
        for(copado__Deployment_Flow_Step__c conn : connectionsByOrderType.get(OrderTypes.ALL)) {
            if(currentDestinations.contains(conn.copado__Destination_Environment__c) 
                && !processedConnections.contains(conn.Id)) {
                connectionsByOrderType.get(OrderTypes.SORTED).add(conn);
                processedConnections.add(conn.Id);
                nextSourceEnvs.add(conn.copado__Source_Environment__c);
            }
        }
        
        return nextSourceEnvs;
    }

    private static void addRemainingConnections(
        List<copado__Deployment_Flow_Step__c> connections,
        Set<Id> processedConnections,
        List<copado__Deployment_Flow_Step__c> orderedConnections
    ) {
        for(copado__Deployment_Flow_Step__c conn : connections) {
            if(!processedConnections.contains(conn.Id)) {
                orderedConnections.add(conn);
                processedConnections.add(conn.Id);
            }
        }
    }

    private static List<copado__Deployment_Flow_Step__c> paginateResults(
        List<copado__Deployment_Flow_Step__c> connections, Integer offset, Integer queryLimit
    ) {
        List<copado__Deployment_Flow_Step__c> paginatedResults = new List<copado__Deployment_Flow_Step__c>();
        Integer endIndex = Math.min(offset + queryLimit, connections.size());
        
        for (Integer i = offset; i < endIndex; i++) {
            paginatedResults.add(connections[i]);
        }
        
        return paginatedResults;
    }

    private static String getExecutionStatsQuery(QueryParams params) {
        String baseQuery = buildBaseQuery(params);

        String jobExecutionCondition = 'Id IN (SELECT copado__Promotion__c ' +
            'FROM copado__JobExecution__c ' +
            'WHERE copado__Status__c IN :STATUS_VALUES ' +
            'AND ' + getJobExecutionTemplateCondition(params.pipelineId, params.isCount) + ')';
        
        QueryBuilder queryBuilder = new QueryBuilder(baseQuery)
            .addCondition(buildBaseConditionsClause(params))
            .addCondition(jobExecutionCondition)
            .addCondition(buildSearchCondition(params.searchTerm))
            .addCondition(buildPipelineConnectionCondition(params));
            
        if (!params.isCount) {
            queryBuilder
                .setLimit(params.queryLimit)
                .setOffset(params.offset);
        }
        
        return params.isCount ? 
            addGroupByClause(queryBuilder.build()) : 
            queryBuilder.build();
    }
    
    private static String buildBaseQuery(QueryParams params) {
        return 'SELECT ' + 
            (params.isCount ? 'COUNT(Id)' : getQueryFields(params.pipelineId, params.isCount)) + 
            ' FROM copado__Promotion__c';
    }
    
    private static String buildBaseConditionsClause(QueryParams params) {
        OverviewPipelineTablesHelper.BaseConditionsParams baseConditionsParams =
            new OverviewPipelineTablesHelper.BaseConditionsParams();
        baseConditionsParams.selectedPipelineId = params.pipelineId;
        baseConditionsParams.selectedProjectId = params.projectId;
        baseConditionsParams.selectedReleaseId = params.releaseId;
        baseConditionsParams.promotionType = params.promotionType;
        baseConditionsParams.timePeriod = params.timePeriod;

        List<String> baseConditions = OverviewPipelineTablesHelper.buildBaseConditions(baseConditionsParams);
        
        return baseConditions.isEmpty() ? '' : '(' + String.join(baseConditions, ' AND ') + ')';
    }
    
    private static String buildSearchCondition(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return '';
        }
        
        String searchValue = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return '(Name LIKE \'' + searchValue + '\' ' +
               'OR copado__Source_Environment__r.Name LIKE \'' + searchValue + '\' ' +
               'OR copado__Destination_Environment__r.Name LIKE \'' + searchValue + '\')';
    }
    
    private static String buildPipelineConnectionCondition(QueryParams params) {
        return getFiltersByPipelineConnection(
            params.pipelineConnections, 
            getIsBackPromotion(params.promotionType)
        );
    }
    
    private static String addGroupByClause(String query) {
        return query + ' GROUP BY copado__Source_Environment__c, copado__Destination_Environment__c';
    }

    private static String getFiltersByPipelineConnection(
        List<copado__Deployment_Flow_Step__c> pipelineConnections, Boolean isBackPromotion
    ) {
        List<String> conditions = new List<String>();

        for (copado__Deployment_Flow_Step__c pipelineConnection : pipelineConnections) {
            Id sourceEnvironmentId;
            Id destinationEnvironmentId;
            if (isBackPromotion) {
                sourceEnvironmentId = pipelineConnection.copado__Destination_Environment__c;
                destinationEnvironmentId = pipelineConnection.copado__Source_Environment__c;
            } else {
                sourceEnvironmentId = pipelineConnection.copado__Source_Environment__c;
                destinationEnvironmentId = pipelineConnection.copado__Destination_Environment__c;
            }

            conditions.add(
                '(copado__Source_Environment__c = \'' + sourceEnvironmentId + '\' AND ' +
                'copado__Destination_Environment__c = \'' + destinationEnvironmentId + '\')');
        }

        return conditions.isEmpty() ? '' : '( ' + String.join(conditions, ' OR ') + ' )';
    }

    private static String getJobExecutionTemplateCondition(Id selectedPipelineId, Boolean isCount) {
        String templateIn = 'copado__Template__c IN ({0})';
        String pipelineActionQuery = 'SELECT copado__Job_Template__c ' +
                    'FROM copado__Pipeline_Action__c ' +
                    'WHERE copado__Pipeline__c = :selectedPipelineId ' +
                    'AND copado__Job_Template__r.Name = :TEMPLATES_TO_QUERY';
        pipelineActionQuery += ' WITH USER_MODE';

        if (TEMPLATE_IDS.isEmpty()) {
            for (copado__Pipeline_Action__c pipelineAction : Database.query(pipelineActionQuery)) { // NOPMD - PMD.ApexSOQLInjection
                TEMPLATE_IDS.add(pipelineAction.copado__Job_Template__c);
            }
        }

        return String.format(templateIn, new List<String>{'\'' + String.join(TEMPLATE_IDS, '\', \'') + '\''});
    }

    private static String getQueryFields(Id selectedPipelineId, Boolean isCount) {
        String jobExecutionsSubquery = '(SELECT Id, copado__Template__r.Name, copado__Status__c, copado__DataJson__c, ' +
                '(SELECT Id, Name, copado__Status__c, copado__Type__c, ' +
                    '(SELECT Id, copado__Start_Time__c, copado__End_Time__c, copado__Duration__c, copado__Progress_Status__c ' +
                    'FROM copado__Results__r ORDER BY CreatedDate DESC) ' +
                'FROM copado__JobSteps__r ORDER BY CreatedDate DESC) ' +
            'FROM copado__JobExecutions__r ' +
            'WHERE copado__Status__c IN :STATUS_VALUES ' +
            'AND ' + getJobExecutionTemplateCondition(selectedPipelineId, isCount) + ')';

        String deploymentsSubquery = '(SELECT Id, ' + jobExecutionsSubquery + ' FROM copado__Deployments__r' +
            ' ORDER BY CreatedDate DESC)';

        return 'Id, Name, ' +
            'copado__Source_Environment__c, ' +
            'copado__Source_Environment__r.Name, ' +
            'copado__Destination_Environment__c, ' +
            'copado__Destination_Environment__r.Name, ' +
            'copado__Status__c, ' +
            'copado__Back_Promotion__c, ' +
            'CreatedDate, ' + jobExecutionsSubquery + ', ' +
            deploymentsSubquery;
    }

    private static List<DeploymentDetailWrapper> wrapDeploymentDetails(
        List<copado__Promotion__c> promotions,
        Boolean includeValidations
    ) {
        List<DeploymentDetailWrapper> details = new List<DeploymentDetailWrapper>();

        for(copado__Promotion__c promotion : promotions) {
            for (copado__Deployment__c deployment : promotion.copado__Deployments__r) {
                for(copado__JobExecution__c job : deployment.copado__JobExecutions__r) {
                    if(shouldProcessJob(job, includeValidations)) {
                        details.add(new DeploymentDetailWrapper(promotion, job));
                    }
                }
            }
        }
        return details;
    }

    private static List<MergeDetailWrapper> wrapMergeDetails(List<copado__Promotion__c> promotions) {
        List<MergeDetailWrapper> details = new List<MergeDetailWrapper>();
        
        for(copado__Promotion__c promotion : promotions) {
            for(copado__JobExecution__c job : promotion.copado__JobExecutions__r) {
                if(!job.copado__JobSteps__r.isEmpty()) {
                    details.add(new MergeDetailWrapper(promotion, job, job.copado__JobSteps__r[0]));
                }
            }
        }
        return details;
    }

    private static List<ExecutionStatWrapper> calculateExecutionStats(
        List<copado__Promotion__c> promotions,
        List<copado__Deployment_Flow_Step__c> pipelineConnections,
        QueryParams params
    ) {
        Map<String, List<copado__Promotion__c>> promotionsByPath = new Map<String, List<copado__Promotion__c>>();
        
        for(copado__Promotion__c promotion : promotions) {
            String key = promotion.copado__Source_Environment__r.Name + PATH_SEPARATOR +
                promotion.copado__Destination_Environment__r.Name;

            if(!promotionsByPath.containsKey(key)) {
                promotionsByPath.put(key, new List<copado__Promotion__c>());
            }

            promotionsByPath.get(key).add(promotion);
        }

        List<ExecutionStatWrapper> stats = new List<ExecutionStatWrapper>();

        for (copado__Deployment_Flow_Step__c pipelineConnection : pipelineConnections) {
            List<String> environmentNames = getEnvironmentNames(pipelineConnection, params.isBackPromotion);
            String path = environmentNames[0] + PATH_SEPARATOR + environmentNames[1];

            QueryParams generateWrapperParams = new QueryParams();
            generateWrapperParams.includeValidations = params.includeValidations;
            generateWrapperParams.isBackPromotion = params.isBackPromotion;
            generateWrapperParams.pipelineConnections = new List<copado__Deployment_Flow_Step__c>{pipelineConnection};

            stats.add(generateStatWrapper(
                path,
                promotionsByPath.get(path),
                generateWrapperParams
            ));
        }
        return stats;
    }

    private static Boolean getIsBackPromotion(String promotionType) {
        return promotionType == BACK;
    }

    private static List<String> getEnvironmentNames (
        copado__Deployment_Flow_Step__c pipelineConnection, Boolean isBackPromotion
    ) {
        List<String> environmentNames = new List<String>();
        
        if (isBackPromotion) {
            environmentNames.add(pipelineConnection.copado__Destination_Environment__r.Name);
            environmentNames.add(pipelineConnection.copado__Source_Environment__r.Name);
        } else {
            environmentNames.add(pipelineConnection.copado__Source_Environment__r.Name);
            environmentNames.add(pipelineConnection.copado__Destination_Environment__r.Name);
        }

        return environmentNames;
    }

    private static ExecutionStatWrapper generateStatWrapper(
        String path, List<copado__Promotion__c> promotions, QueryParams params
    ) {
        ExecutionStatWrapper statWrapper = new ExecutionStatWrapper(path, promotions, params);

        if(promotions == null || promotions.isEmpty()) {
            statWrapper.setEmptyState(
                path,
                params.pipelineConnections != null && !params.pipelineConnections.isEmpty() ?
                    params.pipelineConnections[0] :
                    null
            );
        }

        return statWrapper;
    }

    private static String getPromotionTypeCondition(String promotionType) {
        if(String.isBlank(promotionType)) {
            return null;
        }

        return 'copado__Back_Promotion__c = ' + getIsBackPromotion(promotionType);
    }

    private static String getTimePeriodCondition(String timePeriod) {
        if(String.isBlank(timePeriod)) {
            return 'CreatedDate = LAST_N_DAYS:' + DEFAULT_DAYS;
        }
        return OverviewPipelineTablesHelper.getDateCondition(timePeriod);
    }

    private static Boolean validateMergeDetailsParams(OverviewPipelineTablesHelper.LwcParams lwcParams) {
        return lwcParams == null || lwcParams.selectedPipelineId == null|| lwcParams.sourceEnvId == null|| lwcParams.destEnvId == null;
    }

    private static void setBackPromotionEnvironments(OverviewPipelineTablesHelper.LwcParams lwcParams) {
        if (getIsBackPromotion(lwcParams.promotionType)) {
            Id tempId = lwcParams.sourceEnvId;
            lwcParams.sourceEnvId = lwcParams.destEnvId;
            lwcParams.destEnvId = tempId;
        }
    }

    private static Boolean shouldProcessJob(copado__JobExecution__c job, Boolean includeValidations) {
        if(String.isBlank(job.copado__DataJson__c) || !STATUS_VALUES.contains(job.copado__Status__c) || !TEMPLATE_IDS.contains(job.copado__Template__c)) {
            return false;
        }

        Boolean isValidation = OverviewPipelineTablesHelper.getIsValidation(job.copado__DataJson__c);
        return !isValidation || (includeValidations && isValidation);
    }

    private static Decimal calculateDuration(copado__JobStep__c jobStep) {
        if(jobStep == null || jobStep.copado__Results__r.isEmpty()) {
            return 0;
        }

        Decimal startTime = jobStep.copado__Results__r[jobStep.copado__Results__r.size() - 1]
            .copado__Start_Time__c?.getTime();
        Decimal endTime = jobStep.copado__Results__r[0].copado__End_Time__c?.getTime();
        return startTime != null ? ((endTime == null ? Datetime.now().getTime() : endTime) - startTime) / 1000 : 0;
    }

    private static Decimal calculateDurationFromExecution(copado__JobExecution__c jobExecution) {
        Decimal duration = 0;

        try {
            if (jobExecution != null) {
                for (copado__JobStep__c jobStep : jobExecution.copado__JobSteps__r) {
                    duration += calculateDuration(jobStep);
                }
            }
        } catch (System.NullPointerException npe) { // NOPMD - PMD.EmptyCatchBlock
            // Not a real error: The error occurs because the list is null (can't verify whether it's null before due to
            // "ExecutionException: Aggregate query has too many rows for direct assignment, use FOR loop")
        }

        return duration;
    }

    private static String formatTime(Decimal seconds) {
        if(seconds == null || seconds == 0) {
            return '0s';
        }
        
        Integer totalSeconds = (Integer)seconds;
        Integer days = totalSeconds / 86400;
        Integer hours = Math.mod(totalSeconds, 86400) / 3600;
        Integer mins = Math.mod(totalSeconds, 3600) / 60;
        Integer secs = Math.mod(totalSeconds, 60);
        
        List<String> parts = new List<String>();
        if(days > 0) {
            parts.add(days + 'd');
        }
        if(hours > 0) {
            parts.add(hours + 'h');
        }
        if(mins > 0) {
            parts.add(mins + 'm');
        }
        if(secs > 0 || parts.isEmpty()) {
            parts.add(secs + 's');
        }
        
        return String.join(parts, '');
    }

    private static String formatFailureRate(Integer failed, Integer total) {
        if(total == 0) {
            return '0 (0%)';
        }
        Decimal percentage = ((Decimal)failed/total * 100).setScale(0);
        return String.format('{0} ({1}%)', new List<String>{
            String.valueOf(failed),
            String.valueOf(percentage)
        });
    }

    private class QueryParams {
        Id pipelineId;
        Id projectId;
        Id releaseId;
        String promotionType;
        String timePeriod;
        String searchTerm;
        Integer queryLimit;
        Integer offset;
        Boolean includeValidations;
        Boolean isCount;
        Boolean isBackPromotion;
        List<copado__Deployment_Flow_Step__c> pipelineConnections;
    }   

    private class QueryBuilder {
        private String baseQuery;
        private List<String> conditions = new List<String>();
        private Integer queryLimit;
        private Integer queryOffset;
        
        public QueryBuilder(String baseQuery) {
            this.baseQuery = baseQuery;
        }
        
        public QueryBuilder addCondition(String condition) {
            if(String.isNotBlank(condition)) {
                conditions.add(condition);
            }
            return this;
        }

        public QueryBuilder setLimit(Integer queryLimit) {
            this.queryLimit = queryLimit;
            return this;
        }

        public QueryBuilder setOffset(Integer queryOffset) {
            this.queryOffset = queryOffset;
            return this;
        }
        
        public String build() {
            String query = baseQuery;
            if(!conditions.isEmpty()) {
                query += ' WHERE ' + String.join(conditions, ' AND ');
            }
            query += ' WITH USER_MODE ORDER BY CreatedDate DESC ' +
                (
                    (this.queryLimit != null ? 'LIMIT ' + this.queryLimit + ' ' : '') +
                    (this.queryOffset != null ? 'OFFSET ' + this.queryOffset + ' ' : '')
                );

            return query;
        }
    }
        
    private class JobMetrics {
        Integer failedMerges = 0;
        Integer totalMergeTime = 0;
        Integer failedDeployments = 0;
        Integer totalDeploymentTime = 0;
        Integer mergeCount = 0;
        Integer deployCount = 0;
    }

    public class ExecutionStatWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String sourceEnvironmentName;
        @AuraEnabled public String sourceEnvironmentId;
        @AuraEnabled public String destinationEnvironmentName;
        @AuraEnabled public String destinationEnvironmentId;
        @AuraEnabled public Integer totalMerges;
        @AuraEnabled public String failedMerges;
        @AuraEnabled public String avgMergeTime;
        @AuraEnabled public Integer totalDeployments;
        @AuraEnabled public String failedDeployments;
        @AuraEnabled public String avgDeploymentTime;
        private Boolean isBackPromotion;
        
        public ExecutionStatWrapper(
            String path, List<copado__Promotion__c> promotions, QueryParams params
        ) {
            this.isBackPromotion = params.isBackPromotion;

            if(promotions != null && !promotions.isEmpty()) {
                initializeBasicFields(path, promotions[0]);
                processJobMetrics(promotions, params.includeValidations);
            } 
        }

        public void setEmptyState(String path, copado__Deployment_Flow_Step__c pipelineConnection) {
            this.id = path;
            this.setEnvironmentNames(path);
            this.sourceEnvironmentId = this.getSourceEnvironment(pipelineConnection, ID_FIELD);
            this.destinationEnvironmentId = this.getDestinationEnvironment(pipelineConnection, ID_FIELD);
            this.totalMerges = 0;
            this.failedMerges = formatFailureRate(0, 0);
            this.avgMergeTime = formatTime(null);
            this.totalDeployments = 0;
            this.failedDeployments = formatFailureRate(0, 0);
            this.avgDeploymentTime = formatTime(null);
        }

        private String getSourceEnvironment(SObject environmentsContainer, String value) {
            return this.isBackPromotion ?
                String.valueOf(environmentsContainer.getSObject('copado__Destination_Environment__r').get(value)) :
                String.valueOf(environmentsContainer.getSObject('copado__Source_Environment__r').get(value));
        }

        private String getDestinationEnvironment(SObject environmentsContainer, String value) {
            return this.isBackPromotion ?
                String.valueOf(environmentsContainer.getSObject('copado__Source_Environment__r').get(value)) :
                String.valueOf(environmentsContainer.getSObject('copado__Destination_Environment__r').get(value));
        }
        
        private void initializeBasicFields(String path, copado__Promotion__c firstPromotion) {
            this.id = path;
            setEnvironmentIds(firstPromotion);
            setEnvironmentNames(path);
        }
        
        private void setEnvironmentIds(copado__Promotion__c promotion) {
            this.sourceEnvironmentId = this.getSourceEnvironment(promotion, ID_FIELD);
            this.destinationEnvironmentId = this.getDestinationEnvironment(promotion, ID_FIELD);
        }
        
        private void setEnvironmentNames(String path) {
            List<String> envs = path.split(PATH_SEPARATOR);
            this.sourceEnvironmentName = envs[this.isBackPromotion ? 1 : 0];
            this.destinationEnvironmentName = envs[this.isBackPromotion ? 0 : 1];
        }
        
        private void processJobMetrics(List<copado__Promotion__c> promotions, Boolean includeValidations) {
            JobMetrics metrics = calculateJobMetrics(promotions, includeValidations);
            setMergeMetrics(metrics);
            setDeploymentMetrics(metrics);
        }
        
        private JobMetrics calculateJobMetrics(List<copado__Promotion__c> promotions, Boolean includeValidations) {
            JobMetrics metrics = new JobMetrics();
            
            for(copado__Promotion__c promotion : promotions) {
                processPromotionJobs(promotion, metrics, includeValidations);
            }
            
            return metrics;
        }
        
        private void processPromotionJobs(copado__Promotion__c promotion, JobMetrics metrics, Boolean includeValidations) {
            for(copado__JobExecution__c job : promotion.copado__JobExecutions__r) {
                if(TEMPLATES_BY_TYPE.get(PROMOTE).contains(job.copado__Template__r.Name)) {
                    processMergeJob(job, metrics);
                }
            }

            for (copado__Deployment__c deployment : promotion.copado__Deployments__r) {
                for (copado__JobExecution__c jobExecution : deployment.copado__JobExecutions__r) {
                    if(shouldProcessJob(jobExecution, includeValidations)) {
                        processDeployJob(jobExecution, metrics);
                    }
                }
            }
        }
        
        private void processMergeJob(copado__JobExecution__c job, JobMetrics metrics) {
            metrics.mergeCount++;
            if(job.copado__Status__c == ERROR) {
                metrics.failedMerges++;
            }

            metrics.totalMergeTime += (Integer) calculateDurationFromExecution(job);
        }

        private void processDeployJob(copado__JobExecution__c job, JobMetrics metrics) {
            metrics.deployCount++;
            if(job.copado__Status__c == ERROR) {
                metrics.failedDeployments++;
            }

            metrics.totalDeploymentTime += (Integer) calculateDurationFromExecution(job);
        }
        
        private void setMergeMetrics(JobMetrics metrics) {
            this.totalMerges = metrics.mergeCount;
            this.failedMerges = formatFailureRate(metrics.failedMerges, metrics.mergeCount);
            this.avgMergeTime = formatTime(metrics.mergeCount > 0 ? metrics.totalMergeTime/metrics.mergeCount : 0);
        }
        
        private void setDeploymentMetrics(JobMetrics metrics) {
            this.totalDeployments = metrics.deployCount;
            this.failedDeployments = formatFailureRate(metrics.failedDeployments, metrics.deployCount);
            this.avgDeploymentTime = formatTime(metrics.deployCount > 0 ? 
                metrics.totalDeploymentTime/metrics.deployCount : 0);
        }
    }

    public class MergeDetailWrapper {
        @AuraEnabled public Id promotionId;
        @AuraEnabled public String promotionName;
        @AuraEnabled public Id jobId;
        @AuraEnabled public String jobName;
        @AuraEnabled public String status;
        @AuraEnabled public Id stepId;
        @AuraEnabled public String stepName;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public Datetime startTime;
        @AuraEnabled public String duration;

        public MergeDetailWrapper(copado__Promotion__c promotion, copado__JobExecution__c job, copado__JobStep__c step) {
            this.promotionId = promotion.Id;
            this.promotionName = promotion.Name;
            this.jobId = job.Id;
            this.jobName = job.Name;
            this.status = job.copado__Status__c;
            this.stepId = step.Id;
            this.stepName = step.Name;
            this.userId = job.CreatedById;
            this.userName = job.CreatedBy.Name;
            this.setErrorMessage(step);
            
            if(!step.copado__Results__r.isEmpty()) {
                this.startTime = step.copado__Results__r[0].copado__Start_Time__c;
                this.duration = formatTime(calculateDuration(step));
            }
        }

        private void setErrorMessage(copado__JobStep__c step) {
            String resultErrorMessage = step.copado__Results__r != null && !step.copado__Results__r.isEmpty() ?
                step.copado__Results__r.get(0).copado__Error_Message__c :
                null;
            this.errorMessage = String.isNotBlank(resultErrorMessage) ? resultErrorMessage : System.Label.NA;
        }
    }

    public class DeploymentDetailWrapper {
        @AuraEnabled public Id promotionId;
        @AuraEnabled public String promotionName;
        @AuraEnabled public Id jobId;
        @AuraEnabled public String jobName;
        @AuraEnabled public String status;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public Datetime startTime;
        @AuraEnabled public String duration;
        @AuraEnabled public Integer manualTaskCount;
        @AuraEnabled public String idleTime;
        private Decimal durationSeconds = 0;
        private Integer manualTasks = 0;
        private Integer idleTimeSeconds = 0;

        public DeploymentDetailWrapper(copado__Promotion__c promotion, copado__JobExecution__c job) {
            this.promotionId = promotion.Id;
            this.promotionName = promotion.Name;
            this.jobId = job.Id;
            this.jobName = job.Name;
            this.status = job.copado__Status__c;
            this.userId = job.CreatedById;
            this.userName = job.CreatedBy.Name;
            this.setErroMessage(job);

            for(copado__JobStep__c step : job.copado__JobSteps__r) {
                this.setResultTimeStats(step);
            }

            this.duration = formatTime(this.durationSeconds);
            this.manualTaskCount = this.manualTasks;
            this.idleTime = formatTime(this.idleTimeSeconds);
        }

        private void setResultTimeStats(copado__JobStep__c step) {
            if(step.copado__Type__c == MANUAL) {
                this.manualTasks++;
                for(copado__Result__c result : step.copado__Results__r) {
                    this.idleTimeSeconds += this.getDurationFromResult(result);
                }
            }

            if(!step.copado__Results__r.isEmpty()) {
                this.setStartTime(step);
                this.durationSeconds += calculateDuration(step);
            }
        }

        private void setStartTime(copado__JobStep__c step) {
            this.startTime = this.startTime == null ?
                step.copado__Results__r[0].copado__Start_Time__c :
                this.startTime;
        }

        private Integer getDurationFromResult(copado__Result__c result) {
            return result.copado__Duration__c == null ?
                0 :
                Integer.valueOf(result.copado__Duration__c);
        }

        private void setErroMessage(copado__JobExecution__c jExecution) {
            this.errorMessage = String.isNotBlank(jExecution.copado__ErrorMessage__c) ? jExecution.copado__ErrorMessage__c : System.Label.NA;
        }
    }
}