public with sharing class EnvironmentsSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public EnvironmentsSelector() {
        this(true, true);
    }

    public EnvironmentsSelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS, false);
    }

    // PUBLIC

    public SObjectType getSObjectType() {
        return copado__Environment__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ copado__Environment__c.Name };
    }

    public List<copado__Environment__c> byIds(Set<Id> ids) {
        return Database.query(
            newQueryFactory().selectFields(
                new List<String>{
                    'copado__Last_Refresh_Date__c',
                    'copado__Type__c',
                    'Name'
                }
            ).setCondition(copado__Environment__c.Id + ' IN :ids').toSOQL()
        );
    }

    public List<copado__Environment__c> notInIds(Set<Id> ids) {
        return Database.query(newQueryFactory().setCondition(copado__Environment__c.Id + ' NOT IN :ids').toSOQL());
    }

    public List<copado__Environment__c> byName(String name) {
        return Database.query(
            newQueryFactory().selectField('Id').setCondition(copado__Environment__c.Name + ' = :name').toSOQL()
        );
    }
}