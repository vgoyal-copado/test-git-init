public with sharing class PipelineConnectionsSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public PipelineConnectionsSelector() {
        this(true, true);
    }

    public PipelineConnectionsSelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS, false);
    }

    // PUBLIC

    public SObjectType getSObjectType() {
        return copado__Deployment_Flow_Step__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ copado__Deployment_Flow_Step__c.Name };
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineAndSourceEnv(Set<Id> pipelineIds, Set<Id> sourceEnvIds) {
        return Database.query(
            newQueryFactory()
                .selectField('copado__Destination_Environment__r.Name')
                .setCondition(copado__Deployment_Flow_Step__c.copado__Deployment_Flow__c + ' IN :pipelineIds')
                .setCondition(copado__Deployment_Flow_Step__c.copado__Source_Environment__c + ' IN :sourceEnvIds')
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineAndSourceEnvAndDestinationEnv(
        Set<Id> pipelineIds,
        Set<Id> sourceEnvIds,
        Set<Id> destinationEnvIds
    ) {
        return Database.query(
            newQueryFactory()
                .selectField(copado__Deployment_Flow_Step__c.copado__Destination_Branch__c)
                .selectField(copado__Deployment_Flow_Step__c.copado__Branch__c)
                .setCondition(
                    'copado__Deployment_Flow__c IN :pipelineIds AND copado__Source_Environment__c IN :sourceEnvIds AND copado__Destination_Environment__c IN :destinationEnvIds'
                )
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineAndSourceEnvironment(Set<Id> pipelineIds, Set<Id> sourceEnvironmentIds) {
        return Database.query(
            newQueryFactory()
                .selectField('copado__Branch__c')
                .selectField('copado__Destination_Branch__c')
                .selectField('copado__Destination_Environment__r.Name')
                .setCondition('copado__Deployment_Flow__c IN :pipelineIds AND copado__Source_Environment__c IN :sourceEnvironmentIds')
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineIds(Set<Id> pipelineIds) {
        return Database.query(
            newQueryFactory()
                .selectField('copado__Source_Environment__c')
                .setCondition(copado__Deployment_Flow_Step__c.copado__Deployment_Flow__c + ' IN :pipelineIds')
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineId(Id pipelineId) {
        return Database.query(
            newQueryFactory()
                .selectField('copado__Source_Environment__c')
                .selectField('copado__Source_Environment__r.Name')
                .selectField('copado__Source_Environment__r.copado__Platform__c')
                .selectField('copado__Destination_Environment__c')
                .selectField('copado__Destination_Environment__r.Name')
                .selectField('copado__Destination_Environment__r.copado__Platform__c')
                .selectField('copado__Branch__c')
                .selectField('copado__Destination_Branch__c')
                .setCondition(copado__Deployment_Flow_Step__c.copado__Deployment_Flow__c + '= :pipelineId')
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineIdAndCopadoOrgId(Id pipelineId, Set<Id> copadoOrgIds) {
        String copadoOrgIdsForQuery = getCopadoOrgIds(copadoOrgIds);

        String conditions = copado__Deployment_Flow_Step__c.copado__Deployment_Flow__c + '= :pipelineId OR ' +
            'copado__Source_Environment__r.copado__Org_ID__c IN (' + copadoOrgIdsForQuery + ') OR ' +
            'copado__Destination_Environment__r.copado__Org_ID__c IN (' + copadoOrgIdsForQuery + ')';

        return Database.query(
            newQueryFactory()
                .selectField('copado__Source_Environment__c')
                .selectField('copado__Source_Environment__r.Name')
                .selectField('copado__Destination_Environment__c')
                .selectField('copado__Destination_Environment__r.Name')
                .selectField('copado__Source_Environment__r.copado__Org_ID__c')
                .selectField('copado__Destination_Environment__r.copado__Org_ID__c')
                .selectField('copado__Deployment_Flow__c')
                .setCondition(conditions)
                .toSOQL()
        );
    }

    private static String getCopadoOrgIds(Set<Id> ids){
        String result = '';

        for (Id copadoOrgId: ids) {
            result += '\'' + copadoOrgId + '\',';
        }

        if (result.endsWith(',')) {
            result = result.substring(0, result.lastIndexOf(','));
        }
        return result;
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineIdAndSearchTerm(Id pipelineId, String searchTerm) {
        String conditions = copado__Deployment_Flow_Step__c.copado__Deployment_Flow__c + '= :pipelineId AND ' +
            '(copado__Source_Environment__r.Name LIKE \'%' + searchTerm + '%\' OR ' +
            'copado__Destination_Environment__r.Name LIKE \'%' + searchTerm + '%\')';

        return Database.query(
            newQueryFactory()
                .selectField('copado__Source_Environment__c')
                .selectField('copado__Source_Environment__r.Name')
                .selectField('copado__Destination_Environment__c')
                .selectField('copado__Destination_Environment__r.Name')
                .setCondition(conditions)
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineIdWithStageInfo(Id pipelineId) {
        return Database.query(
            newQueryFactory()
                .selectField('copado__Source_Environment__c')
                .selectField('copado__Destination_Environment__c')
                .selectField('copado__Destination_Environment__r.Name')
                .selectField('copado__Stage_Connection__r.copado__Stage__r.Name')
                .selectField('copado__Stage_Connection__r.copado__Next_Stage_Connection__r.copado__Stage__r.Name')
                .setCondition(copado__Deployment_Flow_Step__c.copado__Deployment_Flow__c + '= :pipelineId')
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow_Step__c> byPipelineIdInCurrentOrNextStage(Id pipelineId, copado__Stage_Connection__c stageConnection) {
        Id stageConnectionId = stageConnection.Id;
        Id nextStageConnectionId = stageConnection.copado__Next_Stage_Connection__c;
        return Database.query(
            newQueryFactory()
                .selectField('copado__Source_Environment__c')
                .selectField('copado__Source_Environment__r.Name')
                .selectField('copado__Destination_Environment__c')
                .selectField('copado__Destination_Environment__r.Name')
                .selectField('copado__Stage_Connection__c')
                .selectField('copado__Stage_Connection__r.copado__Next_Stage_Connection__c')
                .selectField('copado__Stage_Connection__r.copado__Stage__r.Name')
                .selectField('copado__Stage_Connection__r.copado__Next_Stage_Connection__r.copado__Stage__r.Name')
                .setCondition(
                    'copado__Deployment_Flow_Step__c.copado__Deployment_Flow__c = :pipelineId AND (copado__Stage_Connection__c = :stageConnectionId OR copado__Stage_Connection__c = :nextStageConnectionId)'
                )
                .toSOQL()
        );
    }
}