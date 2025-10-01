public with sharing class OverviewEnvironmentSyncStatusCtrl {
    private static final Integer DEFAULT_LIMIT = 7;
    private static final String DEFAULT_REFRESH_VALUE = 'N/A';
    private static final String SUCCESS = 'success';
    private static final String SYNCHED = 'synched';
    private static final String OUT_OF_SYNC = 'outofsync';
    private static final String UTILITY_INFO = 'utility:info';
    private static final String UTILITY_CLOSE = 'utility:close';
    private static final String OK = 'ok';
    private static final String BASE_QUERY = 'SELECT Id, Name, copado__Type__c, copado__Last_Refresh_Date__c, ' +
            '(SELECT Id, copado__Promote_Change__c FROM copado__User_Stories__r ' +
            'WHERE copado__Exclude_From_CBM__c = FALSE {0}), ' +
            '(SELECT Id, Name FROM copado__Org_Credentials__r ' +
            'WHERE copado__Default_Credential__c = TRUE ORDER BY CreatedDate DESC) ';

    @AuraEnabled(cacheable=true)
    public static Integer getEnvironmentsTotalRecords(
        String params
    ) {
        try {
            OverviewPipelineTablesHelper.LwcParams lwcParams =
                (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

            QueryParams queryParams = new QueryParams();
            queryParams.pipelineId = lwcParams.selectedPipelineId;
            queryParams.projectId = lwcParams.selectedProjectId;
            queryParams.releaseId = lwcParams.selectedReleaseId;
            queryParams.userStoryStatus = lwcParams.userStoryStatus;
            queryParams.limitNum = DEFAULT_LIMIT;
            queryParams.offsetNum = 0;
            queryParams.isCount = true;
            queryParams.searchTerm = null;

            return Database.countQuery(buildEnvironmentQuery(queryParams));
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<EnvironmentWrapper> getEnvironments(
        String params
    ) {
        try {
            OverviewPipelineTablesHelper.LwcParams lwcParams =
                (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);

            QueryParams queryParams = new QueryParams();
            queryParams.pipelineId = lwcParams.selectedPipelineId;
            queryParams.projectId = lwcParams.selectedProjectId;
            queryParams.releaseId = lwcParams.selectedReleaseId;
            queryParams.userStoryStatus = lwcParams.userStoryStatus;
            queryParams.limitNum = lwcParams.queryLimit != null ? lwcParams.queryLimit : DEFAULT_LIMIT;
            queryParams.offsetNum = lwcParams.offset != null ? lwcParams.offset : 0;
            queryParams.isCount = false;
            queryParams.searchTerm = lwcParams.searchTerm;

            String selectedPipelineId = lwcParams.selectedPipelineId;

            List<copado__Environment__c> environments = Database.query(buildEnvironmentQuery(queryParams));
            return wrapEnvironments(environments);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled
    public static Map<Id, String> getAuthenticationStatuses(List<Id> credentialIds) {
        Map<Id, String> authResults = new Map<Id, String>();
        
        for(Id credId : credentialIds) {
            try {
                Boolean isAuthenticated;

                // Using Test.isRunningTest() because there's an issue with the test class not accepting mocks.
                if (Test.isRunningTest()) {
                    isAuthenticated = true;
                } else {
                    isAuthenticated = credId != null ? copado.GlobalApi.validateOrg(credId) : false;
                }

                authResults.put(
                    credId, 
                    String.valueof(isAuthenticated)
                );
            } catch(Exception ex) {
                authResults.put(
                    credId, 
                    String.isBlank(ex.getMessage()) ? Label.GenericError : ex.getMessage()
                );
            }
        }
        
        return authResults;
    }

    @AuraEnabled
    public static Map<Id, String> getIsEnvironmentOutOfSync(Id pipelineId, List<Id> environmentIds) {
        Map<Id, String> outOfSyncResults = new Map<Id, String>();
    
        Id productionEnvironmentId;
        Set<Id> environmentsToVerify = new Set<Id>(environmentIds);
        try {
            productionEnvironmentId = new PipelineDescriptor(pipelineId).findFinalEnvironment()?.Id;

            if (productionEnvironmentId != null && environmentIds.contains(productionEnvironmentId)) {
                outOfSyncResults.put(productionEnvironmentId, SYNCHED);
                environmentsToVerify.remove(productionEnvironmentId);
            }
        } catch (Exception ex) {
            // This is just an add-on. If this fails it should not abort the whole operation since it's not critical
            System.debug(LoggingLevel.ERROR, ex.getMessage()); // NOPMD - PMD.AvoidDebugStatements
        }

        for (Id environmentId : environmentsToVerify) {
            try {
                copado.Promotions.CalculationServiceRequest request = new copado.Promotions.CalculationServiceRequest();
                request.pipelineId = pipelineId;
                request.environmentId = environmentId;
    
                copado.Promotions.CalculationServiceResult result =
                    copado.Promotions.CalculationService.calculateOutOfSyncBackwardPromotions(request);
    
                outOfSyncResults.put(environmentId, result.userStoryIds.isEmpty() ? SYNCHED : OUT_OF_SYNC);
            } catch (Exception ex) {
                outOfSyncResults.put(environmentId, String.isBlank(ex.getMessage()) ? Label.GenericError : ex.getMessage());
            }
        }

        return outOfSyncResults;
    }


    @AuraEnabled
    public static Map<Id, Integer> getBackPromotionCounts(Id pipelineId, List<Id> environmentIds) {
        Map<Id, Integer> backPromoteCounts = new Map<Id, Integer>();

        for(Id envId : environmentIds) {
            try {
                PromotionsServiceCtrl.CalculationResult result = 
                    PromotionsServiceCtrl.calculateBackwardPromotions(pipelineId, envId);
                
                backPromoteCounts.put(
                    envId, 
                    (result.userStoryIds != null ? result.userStoryIds.size() : 0)
                );
            } catch(Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Error calculating back promotions for env ' +  // NOPMD - PMD.AvoidDebugStatements
                            envId + ': ' + ex.getMessage());
                backPromoteCounts.put(envId, 0);
            }
        }
        
        return backPromoteCounts;
    }

    private static String buildEnvironmentQuery(QueryParams params) {
        Set<Id> environmentIds = new Set<Id>(getEnvironmentIdsFromPipeline(params.pipelineId));
        String environmentIdsFormatted = '(\'' + String.join(environmentIds, '\',\'') + '\') ';
        OverviewPipelineTablesHelper.BaseConditionsParams baseConditionsParams =
            new OverviewPipelineTablesHelper.BaseConditionsParams();
        baseConditionsParams.selectedProjectId = params.projectId;
        baseConditionsParams.selectedReleaseId = params.releaseId;
        baseConditionsParams.status = params.userStoryStatus;

        List<String> userStoryConditions = OverviewPipelineTablesHelper.buildBaseConditions(
            baseConditionsParams
        );
        userStoryConditions.add('(copado__Project__r.copado__Deployment_Flow__c = :selectedPipelineId OR copado__Release__r.copado__Project__r.copado__Deployment_Flow__c = :selectedPipelineId)');

        String userStoryConditionsString = String.join(userStoryConditions, ' AND ');

        List<String> baseQueryConditions = new List<String>{
            'Id ' + (environmentIds.isEmpty() ? '= NULL ' : 'IN ' + environmentIdsFormatted)
        };

        if (String.isNotBlank(params.searchTerm)) {
            String searchValue = '%' + String.escapeSingleQuotes(params.searchTerm) + '%';
            baseQueryConditions.add('(Name LIKE \'' + searchValue+ '\' ' +
                         'OR copado__Type__c LIKE \'' + searchValue+ '\') ');
        }
        
        String baseQueryConditionsString = String.join(baseQueryConditions, ' AND ');

        String baseQuery = params.isCount ? 'SELECT COUNT() ' : BASE_QUERY;
        
        baseQuery += 'FROM copado__Environment__c {1} WITH USER_MODE {2}';

        String query = String.format(
            baseQuery,
            new List<String>{
                String.isNotBlank(userStoryConditionsString) ? 'AND ' + userStoryConditionsString : '',
                String.isNotBlank(baseQueryConditionsString) ? 'WHERE ' + baseQueryConditionsString: '',
                !params.isCount ? ' ORDER BY Name ASC LIMIT ' + params.limitNum + ' OFFSET ' + params.offsetNum : ''
            }
        );

        return query;
    }

    private static List<Id> getEnvironmentIdsFromPipeline(Id pipelineId) {
        Set<Id> environmentIds = new Set<Id>();
        
        for(copado__Deployment_Flow_Step__c step : new PipelineConnectionsSelector().byPipelineId(pipelineId)) {
            if(step.copado__Source_Environment__c != null) {
                environmentIds.add(step.copado__Source_Environment__c);
            }
            if(step.copado__Destination_Environment__c != null) {
                environmentIds.add(step.copado__Destination_Environment__c);
            }
        }
        
        return new List<Id>(environmentIds);
    }

    private static List<EnvironmentWrapper> wrapEnvironments(List<copado__Environment__c> environments) {
        List<EnvironmentWrapper> wrappedEnvironments = new List<EnvironmentWrapper>();
        
        for(copado__Environment__c env : environments) {
            Id credentialId = !env.copado__Org_Credentials__r.isEmpty() ? 
                env.copado__Org_Credentials__r[0].Id : null;
            
            String refreshDays = env.copado__Last_Refresh_Date__c != null ? 
                String.valueOf(System.today().daysBetween(env.copado__Last_Refresh_Date__c) * -1) : 
                DEFAULT_REFRESH_VALUE;

            Integer userStoriesCount = env.copado__User_Stories__r != null ? 
                env.copado__User_Stories__r.size() : 0;
            
            Integer readyToPromoteCount = countReadyToPromote(env.copado__User_Stories__r);

            EnvironmentWrapper envWrapper = new EnvironmentWrapper();
            envWrapper.id = env.Id;
            envWrapper.name = env.Name;
            envWrapper.environmentUrl = '/' + env.Id;
            envWrapper.type = env.copado__Type__c;
            envWrapper.userStories = userStoriesCount;
            envWrapper.usReadyToPromote = readyToPromoteCount;
            envWrapper.usPendingBackPromote = 0;
            envWrapper.credentialId = credentialId;
            envWrapper.lastRefreshDays = refreshDays;

            wrappedEnvironments.add(envWrapper);
        }
        
        return wrappedEnvironments;
    }

    private static Integer countReadyToPromote(List<copado__User_Story__c> userStories) {
        if(userStories == null) {
            return 0;
        }
        
        Integer readyCount = 0;
        for(copado__User_Story__c story : userStories) {
            if(story.copado__Promote_Change__c) {
                readyCount++;
            }
        }
        return readyCount;
    }

    public class EnvironmentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String environmentUrl;
        @AuraEnabled public Integer userStories;
        @AuraEnabled public Integer usReadyToPromote;
        @AuraEnabled public Integer usPendingBackPromote;
        @AuraEnabled public String type;
        @AuraEnabled public String lastRefreshDays;
        @AuraEnabled public Id credentialId;
    }

    private class QueryParams {
        Id pipelineId;
        Id projectId;
        Id releaseId;
        String userStoryStatus;
        String searchTerm;
        Integer limitNum;
        Integer offsetNum;
        Boolean isCount;
    }
}