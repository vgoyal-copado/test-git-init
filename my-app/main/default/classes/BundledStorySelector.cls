public with sharing class BundledStorySelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public BundledStorySelector() {
        this(true, true);
    }

    public BundledStorySelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS, false);
    }

    // PUBLIC

    public SObjectType getSObjectType() {
        return copado__Bundled_Story__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
            copado__Bundled_Story__c.Id,
            copado__Bundled_Story__c.copado__User_Story__c,
            copado__Bundled_Story__c.copado__Package_Version__c
        };
    }

    public List<copado__Bundled_Story__c> byPackageVersionId(Id packageVersionId) {
       return Database.query(newQueryFactory().selectFields(new Set<String>{ 'copado__Package_Version__c'}).setCondition('copado__Package_Version__c =:packageVersionId').toSOQL());
    }
}