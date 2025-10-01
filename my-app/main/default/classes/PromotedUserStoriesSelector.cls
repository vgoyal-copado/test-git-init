public with sharing class PromotedUserStoriesSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public PromotedUserStoriesSelector() {
        this(true, true);
    }

    public PromotedUserStoriesSelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS, false);
    }

    // PUBLIC

    public SObjectType getSObjectType() {
        return copado__Promoted_User_Story__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
            copado__Promoted_User_Story__c.Name,
            copado__Promoted_User_Story__c.copado__User_Story__c
        };
    }

    public List<copado__Promoted_User_Story__c> byPromotionIds(Set<Id> ids) {
        return Database.query(
            newQueryFactory().setCondition(copado__Promoted_User_Story__c.copado__Promotion__c + ' IN :ids').toSOQL()
        );
    }

    public List<copado__Promoted_User_Story__c> promotionsForBackPromotionMergeOrder(Set<Id> userStoryIds, Id destinationEnvironment) {
        return Database.query(
            newQueryFactory()
            .selectField('copado__Promotion__c')
            .setCondition('copado__Status__c = \'Active\' AND copado__Promotion__r.copado__Status__c = \'Completed\' AND copado__Promotion__r.copado__Last_Deployment_Execution_Id__c != NULL AND copado__User_Story__c IN :userStoryIds AND copado__Promotion__r.copado__Platform__c = \'SFDX\' AND copado__Promotion__r.copado__Destination_Environment__c = :destinationEnvironment').toSOQL());
    }
}