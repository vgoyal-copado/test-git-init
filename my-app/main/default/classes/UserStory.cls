@IsTest
public class UserStory extends DomainBuilder {
    public UserStory() {
        super(copado__User_Story__c.SObjectType);
    }

    public UserStory title(String title) {
        return (UserStory) set(copado__User_Story__c.copado__User_Story_Title__c, title);
    }

    public UserStory status(String status) {
        return (UserStory) set(copado__User_Story__c.copado__Status__c, status);
    }

    public UserStory credential(Credential credential) {
        setParent(copado__User_Story__c.copado__Org_Credential__c, credential);
        return this;
    }
    
    public UserStory project(Project project) {
        setParent(copado__User_Story__c.copado__Project__c, project);
        return this;
    }

    public UserStory projectId(Id projectId) {
        return (UserStory) set(copado__User_Story__c.copado__Project__c, projectId);
    }

    public UserStory release(Release rel) {
        setParent(copado__User_Story__c.copado__Release__c, rel);
        return this;
    }

    public UserStory recordId(Id recordId) {
        return (UserStory) set(copado__User_Story__c.Id, recordId);
    }

    public UserStory environment(Environment env) {
        setParent(copado__User_Story__c.copado__Environment__c, env);
        return this;
    }

    public UserStory environmentId(Id environmentId) {
        return (UserStory) set(copado__User_Story__c.copado__Environment__c, environmentId);
    }

    public UserStory excludeFromCbm(Boolean value) {
        return (UserStory) set(copado__User_Story__c.copado__Exclude_From_CBM__c, value);
    }

    public UserStory stopIndexingMetadata(Boolean value) {
        return (UserStory) set(copado__User_Story__c.copado__Stop_Indexing_Metadata__c, value);
    }

    public UserStory add(UserStoryMetadata_t metadata) {
        metadata.setParent(copado__User_Story_Metadata__c.copado__User_Story__c, this);
        return this;
    }
}