@SuppressWarnings('PMD.CognitiveComplexity, PMD.ExcessiveParameterList, PMD.CyclomaticComplexity, PMD.AvoidNonRestrictiveQueries, PMD.ApexDoc')
public with sharing class PromotionsServiceCtrl {
    private static final String ENABLE_ENV_SYNC_BACK_PROMOTE = '{$Context.Property.Enable_Env_Sync_Back_Promote}';

    // Public Methods
    @AuraEnabled
    public static CalculationResult calculateForwardPromotions(String pipelineId, String environmentId) {
        try {
            copado.Promotions.CalculationServiceRequest request = new copado.Promotions.CalculationServiceRequest();
            request.pipelineId = pipelineId;
            request.environmentId = environmentId;

            copado.Promotions.CalculationServiceResult result = copado.Promotions.CalculationService.calculateForwardPromotions(request);

            return new CalculationResult(new List<Id>(result.userStoryIds), null);
        } catch (Exception ex) {
            return new CalculationResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static CalculationResult calculateBackwardPromotions(String pipelineId, String environmentId) {
        try {
            copado.Promotions.CalculationServiceRequest request = new copado.Promotions.CalculationServiceRequest();
            request.pipelineId = pipelineId;
            request.environmentId = environmentId;

            copado.Promotions.CalculationServiceResult result = copado.Promotions.CalculationService.calculateBackwardPromotions(request);

            return new CalculationResult(new List<Id>(result.userStoryIds), null);
        } catch (Exception ex) {
            return new CalculationResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static CalculationResult calculateOutOfSyncBackwardPromotions(String pipelineId, String environmentId) {
        try {
            copado.Promotions.CalculationServiceRequest request = new copado.Promotions.CalculationServiceRequest();
            request.pipelineId = pipelineId;
            request.environmentId = environmentId;

            copado.Promotions.CalculationServiceResult result = copado.Promotions.CalculationService.calculateOutOfSyncBackwardPromotions(request);

            return new CalculationResult(new List<Id>(result.userStoryIds), null);
        } catch (Exception ex) {
            return new CalculationResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static CalculationResult calculateEnvSyncBackwardPromotions(String pipelineId, String environmentId) {
        try {
            copado.Promotions.CalculationServiceRequest request = new copado.Promotions.CalculationServiceRequest();
            request.pipelineId = pipelineId;
            request.environmentId = environmentId;
            request.filterExcludeFromCbm = false;
            copado.Promotions.CalculationServiceResult result = copado.Promotions.CalculationService.calculateBackwardPromotions(request);
            return new CalculationResult(new List<Id>(result.userStoryIds), null);
        } catch (Exception ex) {
            return new CalculationResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static CalculationResult calculateEnvSyncBackwardPromotionsByDestination(
        String pipelineId,
        String environmentId,
        String destinationEnvironmentId
    ) {
        try {
            copado.Promotions.CalculationServiceRequest request = new copado.Promotions.CalculationServiceRequest();
            request.pipelineId = pipelineId;
            request.environmentId = environmentId;
            request.destinationEnvironmentId = destinationEnvironmentId;
            request.filterExcludeFromCbm = false;
            copado.Promotions.CalculationServiceResult result = copado.Promotions.CalculationService.calculateBackwardPromotions(request);

            return new CalculationResult(new List<Id>(result.userStoryIds), null);
        } catch (Exception ex) {
            return new CalculationResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static CalculationResult calculateOutOfSyncBackwardPromotionsByDestination(
        String pipelineId,
        String environmentId,
        String destinationEnvironmentId
    ) {
        try {
            copado.Promotions.CalculationServiceRequest request = new copado.Promotions.CalculationServiceRequest();
            request.pipelineId = pipelineId;
            request.environmentId = environmentId;
            request.destinationEnvironmentId = destinationEnvironmentId;

            copado.Promotions.CalculationServiceResult result = copado.Promotions.CalculationService.calculateOutOfSyncBackwardPromotions(request);

            return new CalculationResult(new List<Id>(result.userStoryIds), null);
        } catch (Exception ex) {
            return new CalculationResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static MetadataResult retrieveMetadata(List<Id> userStoryIds) {
        try {
            copado.Promotions.MetadataServiceRequest request = new copado.Promotions.MetadataServiceRequest();
            request.userStoryIds = new Set<Id>(userStoryIds);

            copado.Promotions.MetadataServiceResult result = copado.Promotions.MetadataService.retrieve(request);

            return new MetadataResult(result.userStoryMetadatas, null);
        } catch (Exception ex) {
            return new MetadataResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static CommitResult retrieveUserStoryCommits(List<Id> userStoryIds) {
        try {
            copado.Promotions.UserStoryCommitServiceRequest request = new copado.Promotions.UserStoryCommitServiceRequest();
            request.userStoryIds = new Set<Id>(userStoryIds);

            copado.Promotions.UserStoryCommitServiceResult result = copado.Promotions.UserStoryCommitService.retrieve(request);

            return new CommitResult(result.userStoryCommits, null);
        } catch (Exception ex) {
            return new CommitResult(null, ex.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean isCopadoLicenseAssigned() {
        try {
            Id loggedInUserId = UserInfo.getUserId();

            for (copado.GlobalAPI.UserLicense userLicense : new copado.GlobalAPI().listCopadoLicenses()) {
                if (userLicense.userId == loggedInUserId) {
                    return userLicense.isCopadoEnabled;
                }
            }
            return false;
        } catch (Exception ex) {
            return false;
        }
    }

    @AuraEnabled
    public static PromotionActionResult executePromotionAction(
        String actionType,
        String pipelineId,
        String environmentId,
        List<Id> userStoryIds,
        Boolean isBackPromotion
    ) {
        try {
            copado.Actions.PromotionRequest request = new copado.Actions.PromotionRequest();
            request.userStoryIds = userStoryIds;
            request.sourceEnvironmentId = environmentId;
            request.isBackPromotion = isBackPromotion;

            // Set execution flags based on action type
            switch on actionType {
                when 'promote' {
                    request.executePromotion = false;
                    request.executeDeployment = false;
                    request.deploymentDryRun = false;
                }
                when 'deploy' {
                    request.executePromotion = true;
                    request.executeDeployment = true;
                    request.deploymentDryRun = false;
                }
                when 'validate' {
                    request.executePromotion = true;
                    request.executeDeployment = true;
                    request.deploymentDryRun = true;
                }
                when 'environmentSync' {
                    request.executePromotion = true;
                    request.executeDeployment = true;
                    request.deploymentDryRun = false;
                    request.promotionMethod = 'Environment Sync';
                }
            }
            // Execute promotion service
            copado.Actions.PromotionResult result = copado.Actions.PromotionService.execute(request);

            return new PromotionActionResult(result?.promotion?.Id, result?.promotion?.Name, result?.jobExecution?.Id, null);
        } catch (Exception ex) {
            return new PromotionActionResult(null, null, null, ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<copado__Persona_Definition__c> getPersonaDefinitions() {
        try {
            return [SELECT Id, Name, copado__Description__c FROM copado__Persona_Definition__c WITH USER_MODE];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getConfigurationJson(List<Id> automationRuleIds) {
        try {
            copado.Automations.ConvertRequest request = new copado.Automations.ConvertRequest();

            request.automationRules = [
                SELECT
                    Id,
                    Name,
                    copado__Automated_Action__c,
                    copado__Automated_Action_Callback__c,
                    copado__Automation_Connector__c,
                    copado__Cron_Expression__c,
                    copado__Custom_Automation_Connector__c,
                    copado__Environment__c,
                    copado__Execution__c,
                    copado__Excluded_Environments__c,
                    copado__Last_Execution_Date_Time__c,
                    copado__Pipeline__c,
                    copado__Scheduled_Job_Id__c,
                    copado__Source_Action__c,
                    copado__Source_Action_Status__c,
                    copado__Stage__c,
                    copado__Filter_Criteria__c,
                    copado__Config_Json__c,
                    copado__Active__c
                FROM copado__Automation_Rule__c
                WHERE Id IN :automationRuleIds
                WITH USER_MODE
            ];

            copado.Automations.ConvertResult response = copado.Automations.ConvertService.convert(request);

            return response.configurationJson;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, Map<String, Object>> getEnvironmentSyncUserStoriesExtendedData(List<String> userStoryIds, String destinationEnvironmentId) {
        try {
            // Create a map of user story IDs to empty objects
            Map<Id, Map<String, Object>> userStoryValuesById = new Map<Id, Map<String, Object>>();
            for (Id storyId : userStoryIds) {
                userStoryValuesById.put(storyId, new Map<String, Object>());
            }

            // Get promotion end times and merge with the map
            Map<Id, Map<String, Object>> promotionData = getPromotionEndTimes(userStoryIds, destinationEnvironmentId);
            for (Id storyId : userStoryValuesById.keySet()) {
                if (promotionData.containsKey(storyId)) {
                    userStoryValuesById.get(storyId).putAll(promotionData.get(storyId));
                }
            }

            // Get merge order data from promotion attachment promotion_us_merge_order.json
            Map<Id, Map<String, Object>> mergeOrderData = getMergeOrderData(userStoryIds, destinationEnvironmentId);
            for (Id storyId : userStoryValuesById.keySet()) {
                if (mergeOrderData.containsKey(storyId)) {
                    userStoryValuesById.get(storyId).putAll(mergeOrderData.get(storyId));
                }
            }

            return userStoryValuesById;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> isBackPromotionEnvSyncEnabled(Id pipelineId) {
        Map<String, Object> result = new Map<String, Object>{ 'isEnvironmentSyncEnabled' => false };

        try {
            if (!Test.isRunningTest() && !copado.Feature.isBackPromotionEnvSyncEnabled()) {
                return result;
            }

            result.put('isEnvironmentSyncEnabled', evaluateEnvironmentSyncSystemProperty(pipelineId));
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Private Methods
    private static Map<Id, Map<String, Object>> getPromotionEndTimes(List<Id> userStoryIds, Id destinationEnvironmentId) {
        List<UserStoryWrapper> userStories = getUserStoriesWithBestPromotions(userStoryIds, destinationEnvironmentId);

        Map<Id, Map<String, Object>> userStoryValuesById = initializeUserStoryValuesMap(userStories);
        Set<Id> deploymentIds = collectDeploymentIds(userStories);
        Set<Id> commitIds = collectCommitIds(userStories);

        if (deploymentIds.isEmpty() && commitIds.isEmpty()) {
            return userStoryValuesById;
        }

        Map<Id, Datetime> deploymentToEndTimeMap = getDeploymentEndTimes(deploymentIds);
        Map<Id, Datetime> commitToEndTimeMap = getCommitEndTimes(commitIds);
        setPromotionEndTimes(userStories, userStoryValuesById, deploymentToEndTimeMap);
        setCommitEndTimes(userStories, userStoryValuesById, commitToEndTimeMap);

        return userStoryValuesById;
    }

    private static List<UserStoryWrapper> getUserStoriesWithBestPromotions(List<Id> userStoryIds, Id destinationEnvironmentId) {
        // Get original user stories with all their promotions
        List<copado__User_Story__c> originalUserStories = [
            SELECT
                Id,
                CreatedDate,
                (
                    SELECT
                        Id,
                        copado__Promotion__r.copado__Last_Deployment_Execution_Id__c,
                        copado__Promotion__r.copado__Status__c,
                        copado__Promotion__r.copado__Destination_Environment__c,
                        copado__Promotion__r.copado__Source_Environment__c
                    FROM copado__Promoted_User_Stories__r
                    WHERE
                        copado__Status__c = 'Active'
                        AND copado__Promotion__r.copado__Status__c = 'Completed'
                        AND (copado__Promotion__r.copado__Destination_Environment__c = :destinationEnvironmentId
                        OR copado__Promotion__r.copado__Source_Environment__c = :destinationEnvironmentId)
                    ORDER BY CreatedDate DESC
                ),
                (
                    SELECT Id, copado__LastJobExecutionId__c
                    FROM copado__User_Story_Commits__r
                    WHERE copado__Status__c = 'Complete'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                )
            FROM copado__User_Story__c
            WHERE Id IN :userStoryIds AND CreatedDate >= :Date.today().addYears(-1)
            WITH USER_MODE
        ];

        // Create a new list with user stories containing only their best promotion
        List<UserStoryWrapper> processedUserStories = new List<UserStoryWrapper>();

        for (copado__User_Story__c originalUserStory : originalUserStories) {
            //copado__Promoted_User_Story__c selectedPromotion = null;
            BestPromotionWrapper selectedPromotion = null;

            if (!originalUserStory.copado__Promoted_User_Stories__r.isEmpty()) {
                // Select the best promotion for this user story
                selectedPromotion = selectBestPromotion(originalUserStory, destinationEnvironmentId);
            }

            // Create wrapper object with user story and its best promotion
            UserStoryWrapper processedUserStory = new UserStoryWrapper(originalUserStory, selectedPromotion);
            processedUserStories.add(processedUserStory);
        }

        return processedUserStories;
    }

    /**
     * Selects the best promotion from a list, prioritizing promotions that match the destination environment.
     * Falls back to the first promotion if no destination match is found.
     */
    private static BestPromotionWrapper selectBestPromotion(copado__User_Story__c originalUserStory, Id destinationEnvironmentId) {
        // Look for a promotion with matching destination environment (priority)
        for (copado__Promoted_User_Story__c promotion : originalUserStory.copado__Promoted_User_Stories__r) {
            if (promotion.copado__Promotion__r.copado__Destination_Environment__c == destinationEnvironmentId) {
                return new BestPromotionWrapper(originalUserStory, promotion, false);
            }
        }

        // Look for a promotion with matching source environment for user story created in intermediate environments
        for (copado__Promoted_User_Story__c promotion : originalUserStory.copado__Promoted_User_Stories__r) {
            if (promotion.copado__Promotion__r.copado__Source_Environment__c == destinationEnvironmentId) {
                return new BestPromotionWrapper(originalUserStory, promotion, true);
            }
        }

        // Fallback to first promotion if no destination match found
        return new BestPromotionWrapper(originalUserStory, originalUserStory.copado__Promoted_User_Stories__r[0], false);
    }

    private static Map<Id, Map<String, Object>> initializeUserStoryValuesMap(List<UserStoryWrapper> userStories) {
        Map<Id, Map<String, Object>> userStoryValuesById = new Map<Id, Map<String, Object>>();
        for (UserStoryWrapper userStoryWrapper : userStories) {
            userStoryValuesById.put(userStoryWrapper.userStory.Id, new Map<String, Object>());
        }
        return userStoryValuesById;
    }

    private static Set<Id> collectDeploymentIds(List<UserStoryWrapper> userStories) {
        Set<Id> deploymentIds = new Set<Id>();
        for (UserStoryWrapper userStory : userStories) {
            if (userStory.hasPromotion() && !userStory.isIntermediateEnvironmentStory()) {
                Id deploymentId = userStory.getDeploymentId();
                if (deploymentId != null) {
                    deploymentIds.add(deploymentId);
                }
            }
        }
        return deploymentIds;
    }

    private static Set<Id> collectCommitIds(List<UserStoryWrapper> userStories) {
        Set<Id> commitIds = new Set<Id>();
        for (UserStoryWrapper userStory : userStories) {
            if (userStory.hasPromotion() && userStory.isIntermediateEnvironmentStory()) {
                Id commitId = userStory.getCommitId();
                if (commitId != null) {
                    commitIds.add(commitId);
                }
            }
        }
        return commitIds;
    }

    private static Map<Id, Datetime> getDeploymentEndTimes(Set<Id> deploymentIds) {
        Map<Id, Datetime> deploymentToEndTimeMap = new Map<Id, Datetime>();
        for (copado__JobStep__c jobStep : [
            SELECT copado__JobExecution__c, copado__Result__r.copado__End_Time__c
            FROM copado__JobStep__c
            WHERE copado__JobExecution__c IN :deploymentIds AND copado__Result__r.copado__Status__c = 'Success'
            WITH USER_MODE
            ORDER BY copado__Order__c DESC
        ]) {
            if (!deploymentToEndTimeMap.containsKey(jobStep.copado__JobExecution__c)) {
                deploymentToEndTimeMap.put(jobStep.copado__JobExecution__c, jobStep.copado__Result__r.copado__End_Time__c);
            }
        }
        return deploymentToEndTimeMap;
    }

    private static Map<Id, Datetime> getCommitEndTimes(Set<Id> commitIds) {
        Map<Id, Datetime> commitToEndTimeMap = new Map<Id, Datetime>();
        for (copado__JobStep__c jobStep : [
            SELECT Id, copado__JobExecution__c, copado__Result__r.copado__End_Time__c
            FROM copado__JobStep__c
            WHERE copado__JobExecution__c IN :commitIds AND copado__Result__r.copado__Status__c = 'Success'
            WITH USER_MODE
            ORDER BY copado__Order__c ASC
        ]) {
            if (!commitToEndTimeMap.containsKey(jobStep.copado__JobExecution__c)) {
                commitToEndTimeMap.put(jobStep.copado__JobExecution__c, jobStep.copado__Result__r.copado__End_Time__c);
            }
        }
        return commitToEndTimeMap;
    }

    private static void setPromotionEndTimes(
        List<UserStoryWrapper> userStories,
        Map<Id, Map<String, Object>> userStoryValuesById,
        Map<Id, Datetime> deploymentToEndTimeMap
    ) {
        final String lastPromotionDateTimeKey = 'lastPromotionDateTime';
        for (UserStoryWrapper userStoryWrapper : userStories) {
            if (userStoryWrapper.hasPromotion() && !userStoryWrapper.isIntermediateEnvironmentStory()) {
                Id deploymentId = userStoryWrapper.getDeploymentId();
                userStoryValuesById.get(userStoryWrapper.userStory.Id).put(lastPromotionDateTimeKey, deploymentToEndTimeMap.get(deploymentId));
            }
        }
    }

    private static void setCommitEndTimes(
        List<UserStoryWrapper> userStories,
        Map<Id, Map<String, Object>> userStoryValuesById,
        Map<Id, Datetime> commitToEndTimeMap
    ) {
        final String lastPromotionDateTimeKey = 'lastPromotionDateTime';
        for (UserStoryWrapper userStoryWrapper : userStories) {
            if (userStoryWrapper.hasPromotion() && userStoryWrapper.isIntermediateEnvironmentStory()) {
                // may be we need to check if we have commit instead of promotion
                Id commitId = userStoryWrapper.getCommitId();
                userStoryValuesById.get(userStoryWrapper.userStory.Id).put(lastPromotionDateTimeKey, commitToEndTimeMap.get(commitId));
            }
        }
    }

    private static Boolean evaluateEnvironmentSyncSystemProperty(Id pipelineId) {
        copado.Jobs.DynamicExpressionEvaluateRequest request = new copado.Jobs.DynamicExpressionEvaluateRequest(
            pipelineId,
            new List<String>{ ENABLE_ENV_SYNC_BACK_PROMOTE }
        );

        List<copado.Jobs.DynamicExpressionEvaluateResult> responses = copado.Jobs.DynamicExpression.evaluate(request);
        return String.isBlank(responses[0]?.value) ? false : Boolean.valueOf(responses[0]?.value);
    }

    private static Map<Id, Map<String, Object>> getMergeOrderData(List<Id> userStoryIds, Id destinationEnvironmentId) {
        Map<Id, Map<String, Object>> userStoryMergeOrderMap = new Map<Id, Map<String, Object>>();
        Map<String, Id> userStoryIdByNumber = getUserStoryIdByNumber(userStoryIds);
        Map<Id, copado__Promotion__c> promotions = getCompletedPromotions(userStoryIds, destinationEnvironmentId);

        if (!promotions.isEmpty()) {
            Map<Id, Blob> mergeOrderDocumentByPromotion = getPromotionMergeOrderDocuments(promotions.keySet());
            processPromotionMergeOrder(mergeOrderDocumentByPromotion, userStoryIdByNumber, userStoryMergeOrderMap);
        }

        return userStoryMergeOrderMap;
    }

    private static Map<String, Id> getUserStoryIdByNumber(List<Id> userStoryIds) {
        Map<String, Id> userStoryIdByNumber = new Map<String, Id>();
        List<copado__User_Story__c> userStories = new UserStoriesSelector().byIds(new Set<Id>(userStoryIds));
        for (copado__User_Story__c us : userStories) {
            userStoryIdByNumber.put(us.Name, us.Id);
        }
        return userStoryIdByNumber;
    }

    private static Map<Id, copado__Promotion__c> getCompletedPromotions(List<Id> userStoryIds, Id destinationEnvironmentId) {
        return new Map<Id, copado__Promotion__c>(
            new PromotionsSelector().byUserStoryIdsAndDestinationEnvironment(new Set<Id>(userStoryIds), destinationEnvironmentId)
        );
    }

    private static Map<Id, Blob> getPromotionMergeOrderDocuments(Set<Id> promotionIds) {
        Map<Id, Blob> mergeOrderDocumentByPromotion = new Map<Id, Blob>();
        List<ContentDocumentLink> contentDocumentLinks = new ContentDocumentLinksSelector()
            .versionDataByLinkedEntityIdsAndTitles(promotionIds, new Set<String>{ 'promotion_us_merge_order.json' });
        if (!contentDocumentLinks.isEmpty()) {
            for (ContentDocumentLink cdl : contentDocumentLinks) {
                mergeOrderDocumentByPromotion.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersion.VersionData);
            }
        }
        return mergeOrderDocumentByPromotion;
    }

    private static void processPromotionMergeOrder(
        Map<Id, Blob> mergeOrderDocumentByPromotion,
        Map<String, Id> userStoryIdByNumber,
        Map<Id, Map<String, Object>> userStoryMergeOrderMap
    ) {
        for (Id promotionId : mergeOrderDocumentByPromotion.keySet()) {
            Blob versionData = mergeOrderDocumentByPromotion.get(promotionId);
            if (versionData != null) {
                try {
                    MergeOrderData mergeOrderData = (MergeOrderData) JSON.deserialize(versionData.toString(), MergeOrderData.class);
                    if (mergeOrderData != null && mergeOrderData.usMergeOrder != null) {
                        Map<String, Integer> mergeOrderPosition = createMergeOrderPositionMap(mergeOrderData.usMergeOrder);
                        updateUserStoryMergeOrderMap(mergeOrderPosition, userStoryIdByNumber, userStoryMergeOrderMap);
                    }
                } catch (Exception e) {
                    throw new AuraHandledException('Error parsing merge order JSON: ' + e.getMessage());
                }
            }
        }
    }

    private static Map<String, Integer> createMergeOrderPositionMap(List<String> mergeOrder) {
        Map<String, Integer> mergeOrderPosition = new Map<String, Integer>();
        for (Integer i = 0; i < mergeOrder.size(); i++) {
            String branchName = mergeOrder[i];
            String usNumber = branchName.substring(branchName.indexOf('/') + 1);
            mergeOrderPosition.put(usNumber, i);
        }
        return mergeOrderPosition;
    }

    private static void updateUserStoryMergeOrderMap(
        Map<String, Integer> mergeOrderPosition,
        Map<String, Id> userStoryIdByNumber,
        Map<Id, Map<String, Object>> userStoryMergeOrderMap
    ) {
        for (String usNumber : mergeOrderPosition.keySet()) {
            Id userStoryId = userStoryIdByNumber.get(usNumber);
            if (userStoryId != null) {
                if (!userStoryMergeOrderMap.containsKey(userStoryId)) {
                    userStoryMergeOrderMap.put(userStoryId, new Map<String, Object>());
                }
                userStoryMergeOrderMap.get(userStoryId).put('mergeOrder', mergeOrderPosition.get(usNumber));
            }
        }
    }

    // Inner Classes
    public class UserStoryWrapper {
        public copado__User_Story__c userStory;
        public copado__Promoted_User_Story__c selectedPromotion;
        public BestPromotionWrapper bestPromotion;

        public UserStoryWrapper(copado__User_Story__c userStory, copado__Promoted_User_Story__c promotion) {
            this.userStory = userStory;
            this.selectedPromotion = promotion;
        }

        public UserStoryWrapper(copado__User_Story__c userStory, BestPromotionWrapper bestPromotion) {
            this.userStory = userStory;
            this.bestPromotion = bestPromotion;
        }

        public Boolean hasPromotion() {
            //return selectedPromotion != null;
            return bestPromotion != null && bestPromotion.promotion != null;
        }

        public Id getDeploymentId() {
            return bestPromotion?.promotion?.copado__Promotion__r?.copado__Last_Deployment_Execution_Id__c;
        }

        public Id getCommitId() {
            return userStory?.copado__User_Story_Commits__r[0]?.copado__LastJobExecutionId__c;
        }

        public Boolean isIntermediateEnvironmentStory() {
            return bestPromotion?.isIntermediateEnvironmentStory;
        }
    }

    /**
     * Wrapper class to identify if the promotion is for user story created in intermediate environments
     */
    public class BestPromotionWrapper {
        public copado__User_Story__c userStory;
        public copado__Promoted_User_Story__c promotion;
        public Boolean isIntermediateEnvironmentStory;

        public BestPromotionWrapper(
            copado__User_Story__c userStory,
            copado__Promoted_User_Story__c promotion,
            Boolean isIntermediateEnvironmentStory
        ) {
            this.userStory = userStory;
            this.promotion = promotion;
            this.isIntermediateEnvironmentStory = isIntermediateEnvironmentStory;
        }
    }

    public class MergeOrderData {
        @AuraEnabled
        public List<String> usMergeOrder { get; set; }
        @AuraEnabled
        public String deploymentDate { get; set; }

        public MergeOrderData() {
            this.usMergeOrder = new List<String>();
        }

        public MergeOrderData(List<String> usMergeOrder, String deploymentDate) {
            this.usMergeOrder = usMergeOrder;
            this.deploymentDate = deploymentDate;
        }
    }

    public class PromotionActionResult {
        @AuraEnabled
        public String promotionId;
        @AuraEnabled
        public String promotionName;
        @AuraEnabled
        public String jobExecutionId;
        @AuraEnabled
        public String error;

        public PromotionActionResult(String promotionId, String promotionName, String jobExecutionId, String error) {
            this.promotionId = promotionId;
            this.promotionName = promotionName;
            this.jobExecutionId = jobExecutionId;
            this.error = error;
        }
    }

    public class CalculationResult {
        @AuraEnabled
        public List<Id> userStoryIds;
        @AuraEnabled
        public String error;

        public CalculationResult(List<Id> userStoryIds, String error) {
            this.userStoryIds = userStoryIds;
            this.error = error;
        }
    }

    public class MetadataResult {
        @AuraEnabled
        public List<SObject> userStoryMetadatas;
        @AuraEnabled
        public String error;

        public MetadataResult(List<SObject> userStoryMetadatas, String error) {
            this.userStoryMetadatas = userStoryMetadatas;
            this.error = error;
        }
    }

    public class CommitResult {
        @AuraEnabled
        public List<SObject> userStoryCommits;
        @AuraEnabled
        public String error;

        public CommitResult(List<SObject> userStoryCommits, String error) {
            this.userStoryCommits = userStoryCommits;
            this.error = error;
        }
    }
}