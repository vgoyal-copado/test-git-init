public with sharing class TestsSelector extends fflib_SObjectSelector {
    //PUBLIC

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
            copado__Test__c.Id,
            copado__Test__c.Name,
            copado__Test__c.copado__Reference__c,
            copado__Test__c.copado__Type__c,
            copado__Test__c.copado__User_Story__c,
            copado__Test__c.copado__Configuration__c,
            copado__Test__c.copado__ExtensionConfiguration__c,
            copado__Test__c.copado__LatestJobExecution__c,
            copado__Test__c.copado__AcceptanceCriteria__c
        };
    }

    public SObjectType getSObjectType() {
        return copado__Test__c.sObjectType;
    }

    public List<copado__Test__c> byIds(Set<Id> ids) {
        return (List<copado__Test__c>) Database.query(
            newQueryFactory()
                .setEnforceFLS(true)
                .selectField('copado__User_Story__r.copado__Org_Credential__c')
                .setCondition('Id IN :ids')
                .toSOQL()
        );
    }

    public List<copado__Test__c> byUserStoriesAndExtensionTools(Set<Id> userStories, Set<String> extensionTools) {
        return (List<copado__Test__c>) Database.query(
            newQueryFactory()
                .setEnforceFLS(true)
                .setCondition(
                    'copado__User_Story__c IN :userStories AND copado__ExtensionConfiguration__r.copado__ExtensionTool__c IN : extensionTools'
                )
                .addOrdering('LastModifiedDate', fflib_QueryFactory.SortOrder.DESCENDING)
                .toSOQL()
        );
    }

    public List<copado__Test__c> byUserStoryIds(Set<Id> ids) {
        return (List<copado__Test__c>) Database.query(
            newQueryFactory().setEnforceFLS(true).setCondition('copado__User_Story__c IN :ids').toSOQL()
        );
    }

    @SuppressWarnings('PMD.UnusedLocalVariable')
    public List<copado__Test__c> byParentAndAutomaticallyExecutableTests(Id parentId) {
        final String BY_PARENT_CONDITION = '(copado__User_Story__c IN :parentIds OR copado__Feature__c IN :parentIds ' +
            'OR copado__Application__c IN :parentIds OR copado__Promotion__c IN :parentIds)'; // NOPMD - PMD.LocalVariableNamingConventions

        // PMD returns parentIds as unusedvariable but it is being used in BY_PARENT_CONDITION final string
        Set<Id> parentIds = new Set<Id>{ parentId };
        String condition = BY_PARENT_CONDITION + ' AND (copado__ExtensionConfiguration__r.copado__Active__c = true ' +
            'AND copado__ReadyToRun__c = true)';

        // @Note: Manual Tests is the only picklist value we have for Extension Tool, and are not automatically executable.
        // Therefore, to also test automatic execution, we need to disable this filter explicitly for Manual Tests.
        if (!Test.isRunningTest()) {
            condition += ' AND copado__ExtensionConfiguration__r.copado__ExtensionTool__c != \'Manual Tests\'';
        }

        return (List<copado__Test__c>) Database.query(
            newQueryFactory()
                .setEnforceFLS(true)
                .selectField('copado__ExtensionConfiguration__r.copado__ExtensionTool__c')
                .setCondition(condition)
                .toSOQL()
        );
    }
}