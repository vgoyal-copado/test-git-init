@IsTest
public class Promotion extends DomainBuilder {
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public Promotion(Project prj, Credential source, Environment sourceEnv, Credential dest, Environment destEnv) {
        super(copado__Promotion__c.SObjectType);
        setParent(copado__Promotion__c.copado__Project__c, prj);
        setParent(copado__Promotion__c.copado__Source_Org_Credential__c, source);
        setParent(copado__Promotion__c.copado__Source_Environment__c, sourceEnv);
        setParent(copado__Promotion__c.copado__Destination_Org_Credential__c, dest);
        setParent(copado__Promotion__c.copado__Destination_Environment__c, destEnv);

        Pipeline pip = (Pipeline) prj.parentByRelationship.get(copado__Project__c.copado__Deployment_Flow__c);

        new PipelineConnection(pip, sourceEnv, destEnv);
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public Promotion(Id projectId, Id sourceId, Id sourceEnvId, Id destId, Id destEnvId) {
        super(copado__Promotion__c.SObjectType);

        set(copado__Promotion__c.copado__Project__c, projectId);
        set(copado__Promotion__c.copado__Source_Org_Credential__c, sourceId);
        set(copado__Promotion__c.copado__Source_Environment__c, sourceEnvId);
        set(copado__Promotion__c.copado__Destination_Org_Credential__c, destId);
        set(copado__Promotion__c.copado__Destination_Environment__c, destEnvId);
    }

    public Promotion() {
        super(copado__Promotion__c.SObjectType);
    }

    public Promotion recordId(Id value) {
        return (Promotion) set(copado__Promotion__c.Id, value);
    }

    public Promotion testLevel(String value) {
        return (Promotion) set(copado__Promotion__c.Apex_Test_Level__c, value);
    }

    public Promotion isBackPromotion(Boolean value) {
        return (Promotion) set(copado__Promotion__c.copado__Back_Promotion__c, value);
    }

    public Promotion status(String value) {
        return (Promotion) set(copado__Promotion__c.copado__Status__c, value);
    }

    public Promotion lastDeploymentExecutionId(Id value) {
        return (Promotion) set(copado__Promotion__c.copado__Last_Deployment_Execution_Id__c, value);
    }

    public Promotion method(String value) {
        return (Promotion) set(copado__Promotion__c.copado__Promotion_Method__c, value);
    }

    public Promotion add(PromotedUserStory promotedUserStory) {
        promotedUserStory.setParent(copado__Promoted_User_Story__c.copado__Promotion__c, this);
        return this;
    }
}