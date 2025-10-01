@isTest
public with sharing class GitRepository extends DomainBuilder {
    public GitRepository() {
        super(copado__Git_Repository__c.SObjectType);
    }

    public GitRepository name(String name) {
        return (GitRepository) set(copado__Git_Repository__c.Name, name);
    }

    public GitRepository uri(String uri) {
        return (GitRepository) set(copado__Git_Repository__c.copado__URI__c, uri);
    }
    
    public GitRepository gitProvider(String gitProvider) {
        return (GitRepository) set(copado__Git_Repository__c.copado__Git_Provider__c, gitProvider);
    }
    
    public GitRepository sourceFormat(String sourceFormat) {
        return (GitRepository) set(copado__Git_Repository__c.copado__Source_Format__c, sourceFormat);
    }
}