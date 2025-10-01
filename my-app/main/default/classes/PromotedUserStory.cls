@IsTest
public with sharing class PromotedUserStory extends DomainBuilder {
    public PromotedUserStory() {
        super(copado__Promoted_User_Story__c.SObjectType);
    }

    public PromotedUserStory userStory(Id userStoryId) {
        return (PromotedUserStory) set(copado__Promoted_User_Story__c.copado__User_Story__c, userStoryId);
    }

    public PromotedUserStory promotion(Id promotionId) {
        return (PromotedUserStory) set(copado__Promoted_User_Story__c.copado__Promotion__c, promotionId);
    }

    public PromotedUserStory status(String value) {
        return (PromotedUserStory) set(copado__Promoted_User_Story__c.copado__Status__c, value);
    }
}