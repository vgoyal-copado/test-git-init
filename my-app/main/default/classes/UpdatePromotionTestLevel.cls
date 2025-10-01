@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class UpdatePromotionTestLevel {
    public static final String CONTEXT_PROPERTY_SFDX_RUN_SPECIFIED_TEST = '{$Context.Property.sfdx_run_specified_tests}';
    private static final string NO_TEST_RUN = 'No Test Run';
    private static final string RUN_SPECIFIED_TESTS = 'Run Specified Tests';
    private Set<Id> promotionIds;
    private Boolean enforceCRUDFLS = !Trigger.isExecuting;

    @TestVisible
    private static final List<String> TEST_LEVELS_IN_ORDER = Utilities.getPicklistValues(
        SObjectType.copado__Promotion__c.getName(),
        copado__Promotion__c.Apex_Test_Level__c.getDescribe(FieldDescribeOptions.DEFAULT).getName() //NOPMD // PMD is giving a false positive here.
    );

    private Integer lastTestLevelIndex {
        get {
            return TEST_LEVELS_IN_ORDER.size() - 1;
        }
    }

    // CONSTRUCTOR

    public UpdatePromotionTestLevel(List<copado__Promoted_User_Story__c> promotedStories) {
        this.promotionIds = getPromotionIds(promotedStories);
    }

    public UpdatePromotionTestLevel(Set<Id> promotionIds) {
        this.promotionIds = promotionIds;
    }

    // PUBLIC

    public void execute() {
        try {
            List<copado__Promotion__c> promotionsToUpdate = new List<copado__Promotion__c>();

            Boolean isRunSpecifiedTestsEnabled = false;
            Boolean hasApexCode = false;
            Boolean calculateIfRunSpecifiedTestsEnabled = true;

            for (
                copado__Promotion__c promotion : new PromotionsSelector(enforceCRUDFLS, enforceCRUDFLS).byIdsAndActivePromotedStories(promotionIds)
            ) {
                String newTestLevel = calculateTestLevel(promotion);
                if (calculateIfRunSpecifiedTestsEnabled) {
                    isRunSpecifiedTestsEnabled = environmentSystemProperties(promotion) || pipelineSystemProperties(promotion);
                    calculateIfRunSpecifiedTestsEnabled = false;
                }
                hasApexCode = hasApexCode || hasUserStoryApexCode(promotion);

                if (newTestLevel == NO_TEST_RUN && isRunSpecifiedTestsEnabled && hasApexCode) {
                    newTestLevel = RUN_SPECIFIED_TESTS;
                }

                if (newTestLevel != promotion.Apex_Test_Level__c) {
                    promotion.Apex_Test_Level__c = newTestLevel;
                    promotionsToUpdate.add(promotion);
                }
            }

            update Security.stripInaccessible(AccessType.UPDATABLE, promotionsToUpdate, true).getRecords();
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    // PRIVATE

    private Set<Id> getPromotionIds(List<copado__Promoted_User_Story__c> promotedStories) {
        Set<Id> promotionIds = new Set<Id>();

        for (copado__Promoted_User_Story__c ps : promotedStories) {
            promotionIds.add(ps.copado__Promotion__c);
        }

        return promotionIds;
    }

    private String calculateTestLevel(copado__Promotion__c promotion) {
        Integer currIndex = TEST_LEVELS_IN_ORDER.contains(promotion.copado__Destination_Environment__r.Apex_Test_Level__c)
            ? TEST_LEVELS_IN_ORDER.indexOf(promotion.copado__Destination_Environment__r.Apex_Test_Level__c)
            : 0;

        if (!isTestLevelMostRestrictive(currIndex)) {
            for (copado__Promoted_User_Story__c ps : promotion.copado__Promoted_User_Stories__r) {
                Integer newIndex = TEST_LEVELS_IN_ORDER.indexOf(ps.copado__User_Story__r.Apex_Test_Level__c);
                currIndex = (newIndex > currIndex) ? newIndex : currIndex;

                if (isTestLevelMostRestrictive(currIndex)) {
                    break;
                }
            }
        }

        return TEST_LEVELS_IN_ORDER.get(currIndex);
    }

    private Boolean isTestLevelMostRestrictive(Integer currIndex) {
        return currIndex == lastTestLevelIndex;
    }

    private static Boolean environmentSystemProperties(copado__Promotion__c promotion) {
        try {
            Id destinationEnvironment = promotion?.copado__Destination_Environment__c;
            
            return getDynamicExpression(destinationEnvironment, CONTEXT_PROPERTY_SFDX_RUN_SPECIFIED_TEST);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    private static Boolean pipelineSystemProperties(copado__Promotion__c promotion) {
        try {
            Id userStoryId = getUserStoryId(promotion);
            Id pipelineId = getPipelineId(userStoryId);

            return getDynamicExpression(pipelineId, CONTEXT_PROPERTY_SFDX_RUN_SPECIFIED_TEST);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    private static Boolean hasUserStoryApexCode(copado__Promotion__c promotion) {
        for (copado__Promoted_User_Story__c pus : promotion.copado__Promoted_User_Stories__r) {
            if (pus.copado__User_Story__r != null && pus.copado__User_Story__r.copado__Has_Apex_Code__c) {
                return true;
            }
        }
        return false;
    }

    private static Id getUserStoryId(copado__Promotion__c promotion) {
        for (copado__Promoted_User_Story__c pus : promotion.copado__Promoted_User_Stories__r) {
            if (pus.copado__User_Story__c != null) {
                return pus.copado__User_Story__c;
            }
        }
        return null;
    }

    private static Id getPipelineId(Id userStoryId) {
        try {
            Id result;
            List<copado__User_Story__c> userStories = new UserStoriesSelector().byIds(new Set<Id>{ userStoryId });
            result = String.isNotBlank(userStories[0].copado__Project__r.copado__Deployment_Flow__c)
                ? userStories[0].copado__Project__r.copado__Deployment_Flow__c
                : userStories[0].copado__Release__r.copado__Project__r.copado__Deployment_Flow__c;

            return result;
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    public static Boolean getDynamicExpression(Id contextId, String expression) {
        try {
            copado.Jobs.DynamicExpressionEvaluateRequest request = new copado.Jobs.DynamicExpressionEvaluateRequest(
                contextId,
                new List<String>{ expression }
            );
            List<copado.Jobs.DynamicExpressionEvaluateResult> responses = copado.Jobs.DynamicExpression.evaluate(request);
            return String.isBlank(responses[0]?.value) ? false : Boolean.valueOf(responses[0]?.value);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }
}