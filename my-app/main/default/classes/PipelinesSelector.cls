public inherited sharing class PipelinesSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public PipelinesSelector() {
        this(true);
    }

    public PipelinesSelector(Boolean enforceFLS) {
        super(false, true, enforceFLS, false);
    }

    // PUBLIC

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ copado__Deployment_Flow__c.Name };
    }

    public SObjectType getSObjectType() {
        return copado__Deployment_Flow__c.sObjectType;
    }

    public List<copado__Deployment_Flow__c> all() {
        return Database.query( 
            newQueryFactory()
                .selectFields(
                    new List<String>{
                        'copado__Git_Repository__r.copado__URI__c',
                        'copado__Git_Repository__r.Name',
                        'copado__Git_Repository__c',
                        'copado__Block_Commits__c',
                        'copado__Active__c',
                        'copado__Main_Branch__c',
                        'copado__Platform__c',
                        'Initialization_Data__c'
                    }
                )
            .toSOQL()
        );
      }

    public List<copado__Deployment_Flow__c> byId(Set<Id> ids) {
        return Database.query(
            newQueryFactory()
                .selectFields(
                    new List<String>{
                        'copado__Git_Repository__r.copado__URI__c',
                        'copado__Git_Repository__r.copado__Pull_Request_Base_URL__c',
                        'copado__Git_Repository__r.Name',
                        'copado__Git_Repository__c',
                        'copado__Block_Commits__c',
                        'copado__Active__c',
                        'copado__Main_Branch__c',
                        'copado__Platform__c',
                        'Initialization_Data__c'
                    }
                )
                .setCondition('Id IN :ids')
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow__c> byPlatform(String platform) {
        return Database.query(
            newQueryFactory()
                .selectFields(new List<String>{ 'copado__Active__c', 'Builder_Data__c', 'Initialization_Data__c' })
                .setCondition('copado__Platform__c = :platform')
                .setOrdering('LastModifiedDate', fflib_QueryFactory.SortOrder.DESCENDING)
                .toSOQL()
        );
    }

    public copado__Deployment_Flow__c byIdWithBuilderData(Id id) {
        return Database.query(newQueryFactory().selectFields(new List<String>{ 'copado__Platform__c', 'Builder_Data__c' }).setCondition('Id = :id').toSOQL());
    }

    public List<copado__Deployment_Flow__c> byGitRepositoryAndIsActivePipeline(Id repositoryId) {
        return Database.query(
            newQueryFactory()
                .selectField(copado__Deployment_Flow__c.copado__Main_Branch__c)
                .setCondition('copado__Git_Repository__c = :repositoryId AND copado__Active__c = true')
                .toSOQL()
        );
    }

    public List<copado__Deployment_Flow__c> byActiveAndPlatform(Boolean active, String platform) {
        return Database.query(
            newQueryFactory()
                .selectFields(new List<String>{
                    'Id',
                    'Name',
                    'copado__Git_Repository__c'
                })
                .setCondition('copado__Active__c = :active AND copado__Platform__c = :platform')
                .setOrdering('LastViewedDate', fflib_QueryFactory.SortOrder.DESCENDING, true)
                .toSOQL()
        );
    }
}