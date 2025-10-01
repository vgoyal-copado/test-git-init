@IsTest
public with sharing class StageConnection extends DomainBuilder {
    public StageConnection() {
        super(copado__Stage_Connection__c.SObjectType);
    }

    public StageConnection pipelineId(Id pipelineId) {
        set(copado__Stage_Connection__c.copado__Pipeline__c, pipelineId);
        return this;
    }

    public StageConnection stageId(Id stageId) {
        set(copado__Stage_Connection__c.copado__Stage__c, stageId);
        return this;
    }

    public StageConnection nextStageConnectionId(Id nextStageConnectionId) {
        set(copado__Stage_Connection__c.copado__Next_Stage_Connection__c, nextStageConnectionId);
        return this;
    }

    public StageConnection stage(Stage stage) {
        setParent(copado__Stage_Connection__c.copado__Stage__c, stage);
        return this;
    }
}