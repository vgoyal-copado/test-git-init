public with sharing class MigrationGitInitializer {
    @InvocableMethod(label='Start Git Initializer as sub JE' category='SFP Migration')
    public static List<Response> execute(List<Request> requests) {
        try {
            InitializeSFDXProject.ProjectInitializationDetails details = new InitializeSFDXProject.ProjectInitializationDetails();

            // Get details from previous result 
            details.gitRepositoryId = requests[0].gitRepositoryId;
            details.gitRepositoryURI = requests[0].gitRepositoryURI;
            details.branch = requests[0].branch;
            details.projectName = 'project';
            details.template = 'standard';
            details.defaultDirectory = 'force-app';

            List<copado__JobExecution__c> childExecutions = InitializeSFDXProject.execute(JSON.serialize(details));
            if(childExecutions.size() == 0) {
                throw new ApplicationException(Label.Error_Initializing_Git);
            }
            return new List<Response>{ new Response(childExecutions[0].Id) };
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id gitRepositoryId;

        @InvocableVariable(required=true)
        public String gitRepositoryURI;

        @InvocableVariable(required=true)
        public String branch; 
    }

    public class Response {
        @InvocableVariable
        public Id initializeJobId;

        public Response(Id initializeJobId) {
            this.initializeJobId = initializeJobId;
        }
    }
}