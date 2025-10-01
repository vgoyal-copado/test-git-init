public inherited sharing class StageConnectionsSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public StageConnectionsSelector() {
        this(true);
    }

    public StageConnectionsSelector(Boolean enforceFLS) {
        super(false, true, enforceFLS, false);
    }

    // PUBLIC

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ copado__Stage_Connection__c.Name };
    }

    public SObjectType getSObjectType() {
        return copado__Stage_Connection__c.sObjectType;
    }

    public List<copado__Stage_Connection__c> byPipelineAndName(Id pipelineId, String stageName) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{ 'copado__Next_Stage_Connection__c', 'copado__Next_Stage_Connection__r.copado__Next_Stage_Connection__c' }
                )
                .setCondition('copado__Pipeline__c = :pipelineId AND copado__Stage__r.copado__Display_Name__c = :stageName')
                .toSOQL()
        );
    }
}