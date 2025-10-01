@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.CognitiveComplexity')
global class GetUserStoryBranchesInOrder implements copado.ParameterExpressionCallable {
    private static final String PROMOTION_US_MERGE_ORDER = 'promotion_us_merge_order.json';

    private static final String PROMOTION_METHOD_ENVIRONMENT_SYNC = 'Environment Sync';

    // GLOBAL

    global String execute(Id contextId) {
        String result = '';
        Response response = new Response();
        try {
            copado__JobStep__c jobStep = getJobStep(contextId);
            copado__Promotion__c promotion = getPromotion(jobStep.copado__JobExecution__r.copado__Promotion__c);
            List<String> userStoryBranches = userStoryBranches(jobStep);
            if (promotion.copado__Back_Promotion__c == false) {
                response.userStoryBranches = userStoryBranches;
                return JSON.serialize(response);
            }

            Set<Id> userStoryIds = getPromotedUserStories(promotion);

            if (promotion.copado__Promotion_Method__c == PROMOTION_METHOD_ENVIRONMENT_SYNC && promotion.copado__Back_Promotion__c == true) {
                response.userStoryBranches = getEnvironmentSyncOrderedBranches(userStoryIds, userStoryBranches, promotion);
                response.shallowSinceDate = getShallowSinceDate(response.userStoryBranches);
            } else {
                Set<Id> promotionIdsForMergeOrder = getPromotionsToDefineMergeOrder(userStoryIds, promotion.copado__Source_Environment__c);
                response = getUserStoriesInOrder(userStoryBranches, promotionIdsForMergeOrder, response);
            }
            result = JSON.serialize(response);
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
        return result;
    }

    private List<String> getEnvironmentSyncOrderedBranches(Set<Id> userStoryIds, List<String> userStoryBranches, copado__Promotion__c promotion) {
        // Get extended data for sorting
        Map<Id, Map<String, Object>> userStoryExtendedData = PromotionsServiceCtrl.getEnvironmentSyncUserStoriesExtendedData(
            new List<Id>(userStoryIds),
            promotion.copado__Source_Environment__c
        );

        // Sort user stories: older lastPromotionDateTime first, then lower mergeOrder, then original order
        List<Id> sortedUserStoryIds = sortUserStoriesByPromotionDateAndMergeOrder(new List<Id>(userStoryIds), userStoryExtendedData);

        // Extract user story names from branch names
        List<String> userStoryNames = extractUserStoryNamesFromBranches(userStoryBranches);

        // Query user story names and create ID to name mapping
        Map<Id, String> userStoryIdToName = queryUserStoryByName(userStoryNames);

        // Map sorted IDs to user story names and return as branch names
        List<String> sortedUserStoryBranches = getBranchesSorted(sortedUserStoryIds, userStoryIdToName);

        return sortedUserStoryBranches;
    }

    private copado__JobStep__c getJobStep(Id jobStepId) {
        List<copado__JobStep__c> jobSteps = new JobStepsSelector().byIds(new Set<Id>{ jobStepId });
        return jobSteps.isEmpty() ? null : jobSteps[0];
    }

    private copado__Promotion__c getPromotion(Id promotionId) {
        List<copado__Promotion__c> promotions = new PromotionsSelector().byIds(new Set<Id>{ promotionId });
        return promotions.isEmpty() ? null : promotions[0];
    }

    private List<String> userStoryBranches(copado__JobStep__c jobStep) {
        String dataJson = jobStep.copado__JobExecution__r.copado__DataJson__c;
        if (String.isBlank(dataJson)) {
            throw new ApplicationException(Label.UserStoryBranches_Not_Found);
        }
        return ((DataJson) JSON.deserialize(dataJson, DataJson.class)).userStoryBranches;
    }

    private static Set<Id> getPromotedUserStories(copado__Promotion__c promotion) {
        Set<Id> result = new Set<Id>();
        List<copado__Promoted_User_Story__c> promotedUserStories = new PromotedUserStoriesSelector().byPromotionIds(new Set<Id>{ promotion.Id });
        if (promotedUserStories.isEmpty()) {
            throw new ApplicationException(Label.Promoted_User_Stories_Not_Found);
        }
        for (copado__Promoted_User_Story__c promotedUserStory : promotedUserStories) {
            result.add(promotedUserStory.copado__User_Story__c);
        }
        return result;
    }

    private static Set<Id> getPromotionsToDefineMergeOrder(Set<Id> userStoryIds, Id destinationEnvironment) {
        Set<Id> result = new Set<Id>();

        for (
            copado__Promoted_User_Story__c promotedUserStory : new PromotedUserStoriesSelector()
                .promotionsForBackPromotionMergeOrder(userStoryIds, destinationEnvironment)
        ) {
            result.add(promotedUserStory.copado__Promotion__c);
        }
        return result;
    }

    @SuppressWarnings('PMD.AvoidDebugStatements')
    private static Response getUserStoriesInOrder(List<String> userStoryBranches, Set<Id> promotionIds, Response response) {
        try {
            List<ContentVersion> mergeOrderFilesOnPromotion = new ContentVersionsSelector()
                .byFirstPublishLocationIdAndTitleAndIsLatest(promotionIds, new List<String>{ PROMOTION_US_MERGE_ORDER });

            /* If the merge order file is not found on any one of the promotions, we keep the current order
                since, when this feature would be released, the users would have some promotions already present
                without any merge order file. So in such cases, we don't run our logic and we return the same userStoryBranches order that the Platform provides us with.
            */
            if (mergeOrderFilesOnPromotion.isEmpty() || mergeOrderFilesOnPromotion.size() < promotionIds.size()) {
                response.userStoryBranches = userStoryBranches;
                response.logError = Label.BackPromotionOrderFileNotFound;
                return response;
            }

            Map<Datetime, List<String>> userStoriesByDeploymentDate = new Map<Datetime, List<String>>();
            for (ContentVersion mergeOrderFileOnPromotion : mergeOrderFilesOnPromotion) {
                PromotionUSMergeOrder fileContent = getFileContent(mergeOrderFileOnPromotion);
                userStoriesByDeploymentDate.put(fileContent.deploymentDate, fileContent.usMergeOrder);
            }
            // Sort the deployment dates in ascending order
            List<Datetime> deploymentDates = new List<Datetime>(userStoriesByDeploymentDate.keySet());
            deploymentDates.sort();

            List<String> userStoryBranchesInPromotions = new List<String>();
            for (Datetime deploymentDate : deploymentDates) {
                userStoryBranchesInPromotions.addAll(userStoriesByDeploymentDate.get(deploymentDate));
            }
            response.userStoryBranches = getSelectedUserStoryBranches(userStoryBranches, userStoryBranchesInPromotions);
        } catch (Exception ex) {
            response.userStoryBranches = userStoryBranches;
            response.logError = ex.getMessage();
            // Populate error to be shown in the function logs and fail silently if there is any exception when calculating the merge order of user stories and save the original list of user story branches.
            System.debug(LoggingLevel.ERROR, ex.getMessage() + ' ' + ex.getStackTraceString());
        }
        return response;
    }

    private static PromotionUSMergeOrder getFileContent(ContentVersion mergeOrderFileOnPromotion) {
        return (PromotionUSMergeOrder) (JSON.deserialize(mergeOrderFileOnPromotion.VersionData.toString(), PromotionUSMergeOrder.class));
    }

    private static List<String> getSelectedUserStoryBranches(List<String> userStoryBranches, List<String> userStoryBranchesInPromotions) {
        List<String> result = new List<String>();
        Set<String> uniqueBranches = new Set<String>();
        for (String branch : userStoryBranchesInPromotions) {
            if (userStoryBranches.contains(branch)) {
                Integer originalSize = uniqueBranches.size();
                uniqueBranches.add(branch);
                if (uniqueBranches.size() > originalSize) {
                    result.add(branch);
                }
            }
        }
        return result;
    }

    /**
     * Sorts user stories by the following criteria:
     * 1. First by lastPromotionDateTime (older dates first)
     * 2. Then by mergeOrder (lower numbers first)
     * 3. For items with same date and no mergeOrder, maintains original array ordering
     */
    private static List<Id> sortUserStoriesByPromotionDateAndMergeOrder(List<Id> userStoryIds, Map<Id, Map<String, Object>> extendedData) {
        List<UserStorySortEntry> entries = new List<UserStorySortEntry>();

        for (Integer i = 0; i < userStoryIds.size(); i++) {
            entries.add(new UserStorySortEntry(userStoryIds[i], i, extendedData.get(userStoryIds[i])));
        }

        entries.sort();

        List<Id> sortedIds = new List<Id>();
        for (UserStorySortEntry entry : entries) {
            sortedIds.add(entry.userStoryId);
        }

        return sortedIds;
    }

    private static String getShallowSinceDate(List<String> userStoryBranches) {
        if (userStoryBranches.isEmpty()) {
            return '';
        }

        String userStoryName = userStoryBranches[0]?.split('/')[1];

        List<copado__User_Story_Commit__c> commits = [
            SELECT CreatedDate
            FROM copado__User_Story_Commit__c
            WHERE copado__User_Story__r.Name = :userStoryName AND copado__Status__c = 'Complete'
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (!commits.isEmpty() && commits[0].CreatedDate != null) {
            // Env Sync uses --shallow-since (oldest US commit date - 1 month) as default git depth is insufficient for older commits. This approach ensures adequate commit history is available while maintaining performance by avoiding a full repository clone.
            // One month added to ensure we take the parent commit of the oldest commit for the oldest User Story
            Date shallowSinceDate = commits[0].CreatedDate.date().addMonths(-1);
            return String.valueOf(shallowSinceDate);
        }

        return '';
    }

    @TestVisible
    private class UserStorySortEntry implements Comparable {
        public Id userStoryId;
        public DateTime promotionDate;
        public Integer mergeOrder;
        public Integer originalIndex;

        public UserStorySortEntry(Id id, Integer index, Map<String, Object> data) {
            this.userStoryId = id;
            this.originalIndex = index;

            if (data != null) {
                Object dateObj = data.get('lastPromotionDateTime');
                if (dateObj instanceof String) {
                    try {
                        this.promotionDate = DateTime.valueOf((String) dateObj);
                    } catch (Exception e) {
                        this.promotionDate = null;
                    }
                } else if (dateObj instanceof DateTime) {
                    this.promotionDate = (DateTime) dateObj;
                }

                Object orderObj = data.get('mergeOrder');
                if (orderObj instanceof Integer) {
                    this.mergeOrder = (Integer) orderObj;
                } else if (orderObj instanceof String) {
                    try {
                        this.mergeOrder = Integer.valueOf((String) orderObj);
                    } catch (Exception e) {
                        this.mergeOrder = null;
                    }
                }
            }
        }

        public Integer compareTo(Object other) {
            UserStorySortEntry that = (UserStorySortEntry) other;

            Integer dateComparison = compareDates(this.promotionDate, that.promotionDate);
            if (dateComparison != 0) {
                return dateComparison;
            }

            Integer orderComparison = compareOrders(this.mergeOrder, that.mergeOrder);
            if (orderComparison != 0) {
                return orderComparison;
            }

            return this.originalIndex < that.originalIndex ? -1 : 1;
        }

        private Integer compareDates(DateTime date1, DateTime date2) {
            if (date1 == date2) {
                return 0;
            }
            if (date1 == null) {
                return 1;
            }
            if (date2 == null) {
                return -1;
            }
            return date1 < date2 ? -1 : 1;
        }

        private Integer compareOrders(Integer order1, Integer order2) {
            if (order1 == order2) {
                return 0;
            }
            if (order1 == null) {
                return 1;
            }
            if (order2 == null) {
                return -1;
            }
            return order1 < order2 ? -1 : 1;
        }
    }

    @TestVisible
    private class DataJson {
        public List<String> userStoryBranches;
        public List<Id> userStoryIds;
    }

    @TestVisible
    private class PromotionUSMergeOrder {
        public List<String> usMergeOrder;
        public Datetime deploymentDate;
    }

    @TestVisible
    private class Response {
        public List<String> userStoryBranches;
        public String logError;
        public String shallowSinceDate;

        public Response() {
            logError = '';
            userStoryBranches = new List<String>();
            shallowSinceDate = '';
        }
    }

    /**
     * Extracts user story names from branch names by splitting on '/' and taking the second part
     */
    private static List<String> extractUserStoryNamesFromBranches(List<String> userStoryBranches) {
        List<String> userStoryNames = new List<String>();
        for (String branch : userStoryBranches) {
            userStoryNames.add(branch.split('/')[1]);
        }
        return userStoryNames;
    }

    /**
     * Queries user stories by their names and returns a map of ID to Name
     */
    private static Map<Id, String> queryUserStoryByName(List<String> userStoryNames) {
        Map<Id, String> userStoryIdToName = new Map<Id, String>();
        for (copado__User_Story__c userStory : [SELECT Id, Name FROM copado__User_Story__c WHERE Name IN :userStoryNames WITH USER_MODE]) {
            userStoryIdToName.put(userStory.Id, userStory.Name);
        }
        return userStoryIdToName;
    }

    /**
     * Maps sorted user story IDs to branch names using the ID to name mapping
     */
    private static List<String> getBranchesSorted(List<Id> sortedUserStoryIds, Map<Id, String> userStoryIdToName) {
        List<String> sortedUserStoryBranches = new List<String>();
        for (Id sortedId : sortedUserStoryIds) {
            String userStoryName = userStoryIdToName.get(sortedId);
            if (userStoryName != null) {
                sortedUserStoryBranches.add('feature/' + userStoryName);
            }
        }
        return sortedUserStoryBranches;
    }
}