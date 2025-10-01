public with sharing class CredentialsSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public CredentialsSelector() {
        this(true, true);
    }

    public CredentialsSelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS, false);
    }

    // PUBLIC

    public SObjectType getSObjectType() {
        return copado__Org__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ copado__Org__c.Name };
    }

    public List<copado__Org__c> byIds(List<Id> ids) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{
                        'copado__Environment__c',
                        'copado__Environment__r.Name',
                        'copado__Environment__r.copado__Platform__c',
                        'copado__Org_Type__c',
                        'copado__Username__c',
                        'copado__Default_Credential__c',
                        'copado__SFDC_Org_ID__c',
                        'copado__is_Developer_Hub_Org__c',
                        'copado__Validated_Status__c'
                    }
                )
                .setCondition(copado__Org__c.Id + ' IN :ids')
                .toSOQL()
        );
    }

    public List<copado__Org__c> byActiveEnvAndPlatform(Set<String> platforms) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{
                        'copado__Environment__c',
                        'copado__Environment__r.Name',
                        'copado__Org_Type__c',
                        'copado__Username__c',
                        'copado__Default_Credential__c',
                        'copado__SFDC_Org_ID__c',
                        'copado__is_Developer_Hub_Org__c',
                        'copado__Validated_Status__c'
                    }
                )
                .setCondition(
                    'copado__Environment__c != null AND copado__Validated_Date__c != null AND copado__Environment__r.copado__Platform__c IN :platforms'
                )
                .toSOQL()
        );
    }

    public List<copado__Org__c> byEnvironmentIdAndValidationCheck(Set<Id> environmentId) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{
                        'copado__Environment__c',
                        'copado__Org_Type__c',
                        'copado__Username__c',
                        'copado__Default_Credential__c',
                        'copado__SFDC_Org_ID__c',
                        'copado__is_Developer_Hub_Org__c',
                        'copado__Validated_Status__c'
                    }
                )
                .setCondition(
                    'copado__Environment__c =: environmentId AND ((copado__Validated_Status__c IN (\'OK\',\'None\')) AND copado__SFDC_Org_ID__c != null AND copado__Default_Credential__c = true)'
                )
                .setOrdering('CreatedDate', fflib_QueryFactory.SortOrder.DESCENDING)
                .toSOQL()
        );
    }

    public List<copado__Org__c> defaultCredential(Id environmentId) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{ 'copado__Username__c', 'copado__Platform__c', 'copado__SFDC_Org_ID__c', 'copado__Validated_Status__c' }
                )
                .setCondition('copado__Environment__c =: environmentId AND copado__Default_Credential__c = true')
                .setOrdering('CreatedDate', fflib_QueryFactory.SortOrder.DESCENDING)
                .setLimit(1)
                .toSOQL()
        );
    }

    public List<copado__Org__c> bySFDCOrgId(Set<String> sfdcOrgId) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{
                        'copado__Environment__c',
                        'copado__Org_Type__c',
                        'copado__Username__c',
                        'copado__Default_Credential__c',
                        'copado__SFDC_Org_ID__c',
                        'copado__is_Developer_Hub_Org__c',
                        'copado__Validated_Status__c'
                    }
                )
                .setCondition('copado__SFDC_Org_ID__c IN :sfdcOrgId')
                .toSOQL()
        );
    }

    public List<copado__Org__c> duplicatedUsername(copado__Org__c credential) {
        String username = credential.copado__Username__c;
        String credentialId = credential.Id;
        return Database.query(
            newQueryFactory()
                .selectFields(new List<String>{ 'copado__Environment__c', 'copado__Platform__c' })
                .setCondition('copado__Username__c = :username AND Id != :credentialId')
                .toSOQL()
        );
    }

    public List<copado__Org__c> byNotInEnvironmentIdAndPlatform(Set<Id> ids, String platform) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{'copado__Environment__c', 'copado__Environment__r.Name'}
                )
                .setCondition('copado__Environment__c NOT IN :ids AND copado__Default_Credential__c = true AND copado__Platform__c = :platform')
                .setOrdering('CreatedDate', fflib_QueryFactory.SortOrder.DESCENDING)
                .toSOQL()
        );
    }

    public List<copado__Org__c> bySfdcOrgIdAndValidationCheck(Set<String> sfdcOrgIds) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                        new List<String>{
                            'copado__Environment__c',
                            'copado__Org_Type__c',
                            'copado__Username__c',
                            'copado__Default_Credential__c',
                            'copado__SFDC_Org_ID__c',
                            'copado__is_Developer_Hub_Org__c',
                            'copado__Validated_Status__c'
                        }
                    )
                .setCondition('copado__SFDC_Org_ID__c IN :sfdcOrgIds AND ((copado__Validated_Status__c IN (\'OK\',\'None\')))')
                .toSOQL()
        );
    }

    public List<copado__Org__c> byUsernameAndOrgId(String username, String organizationId) {
        String orgIdPattern = organizationId + '%';
        String excludePattern = '%\\_%\\_%';
        
        return Database.query(
            newQueryFactory()
                .selectField('Id')
                .setCondition(
                    'copado__Username__c = :username ' +
                    'AND copado__SFDC_Org_ID__c LIKE :orgIdPattern ' +
                    'AND (NOT copado__SFDC_Org_ID__c LIKE :excludePattern)'
                )
                .toSOQL()
        );
    }    
}