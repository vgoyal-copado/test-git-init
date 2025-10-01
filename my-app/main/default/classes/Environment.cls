@IsTest
public class Environment extends DomainBuilder {
    public Environment() {
        super(copado__Environment__c.SObjectType);
        type('Production/Developer');
        platform('SFDX');
    }

    public Environment(String platform) {
        super(copado__Environment__c.SObjectType);
        type('Production/Developer');
        platform(platform);
    }

    public Environment platform(String platform) {
        return (Environment) set(copado__Environment__c.copado__Platform__c, platform);
    }

    public Environment add(Credential cred) {
        return (Environment) cred.setParent(copado__Org__c.copado__Environment__c, this);
    }

    public Environment type(String value) {
        return (Environment) set(copado__Environment__c.copado__Type__c, value);
    }

    public Environment recordId(Id recordId) {
        return (Environment) set(copado__Environment__c.Id, recordId);
    }

    public Environment runAllLocalTests(Boolean value) {
        return (Environment) set(copado__Environment__c.copado__Run_all_tests__c, value);
    }

    public Environment name(String name) {
        return (Environment) set(copado__Environment__c.Name, name);
    }

    public Environment orgId(Id value) {
        return (Environment) set(copado__Environment__c.copado__Org_ID__c, value);
    }

    public Environment indexBackPromotionMetadata(Boolean value) {
        return (Environment) set(copado__Environment__c.copado__Index_Back_Promotion_metadata__c, value);
    }
}