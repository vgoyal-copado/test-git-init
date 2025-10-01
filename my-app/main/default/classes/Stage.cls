@IsTest
public with sharing class Stage extends DomainBuilder {
    public Stage() {
        super(copado__Stage__c.SObjectType);
    }

    public Stage name(String name) {
        set(copado__Stage__c.Name, name);
        return (Stage) set(copado__Stage__c.copado__Display_Name__c, name);
    }

    public Stage metaStage(String metaStage) {
        return (Stage) set(copado__Stage__c.copado__Meta_Stage__c, metaStage);
    }
}