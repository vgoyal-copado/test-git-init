public with sharing class PersonaDefinitionsSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public PersonaDefinitionsSelector() {
        this(true, true);
    }

    public PersonaDefinitionsSelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS, false);
    }

    // PUBLIC

    public SObjectType getSObjectType() {
        return copado__Persona_Definition__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ copado__Persona_Definition__c.Name };
    }

    public List<copado__Persona_Definition__c> getAll() {
        return Database.query(newQueryFactory().selectField(copado__Persona_Definition__c.copado__Config_JSON__c).toSOQL());
    }

    public List<copado__Persona_Definition__c> getAllExtended() {
        return Database.query(newQueryFactory().selectFields(
            new Set<String>{
                'Id', 'Name', 'copado__Config_Json__c', 'copado__Is_Standard__c', 'copado__Description__c'
            }
        ).setOrdering(
            'CreatedDate', fflib_QueryFactory.SortOrder.ASCENDING
        ).toSOQL());
    }
}