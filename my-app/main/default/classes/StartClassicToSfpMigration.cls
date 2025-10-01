public with sharing class StartClassicToSfpMigration {
    @InvocableMethod(label='Start Classic To Sfp Migration')
    public static List<Response> execute(List<Request> requests) {
        try {
            Id pipelineId = requests[0].pipelineId;
            copado__Deployment_Flow__c pipeline = [
                SELECT Id, copado__Git_Repository__c
                FROM copado__Deployment_Flow__c
                WHERE Id = :pipelineId
                WITH SYSTEM_MODE
            ];
            copado__Git_Repository__c classicRepo = [
                SELECT Id, Name, copado__Git_Provider__c
                FROM copado__Git_Repository__c
                WHERE Id = :pipeline.copado__Git_Repository__c
                WITH SYSTEM_MODE
            ];

            authenticateGitRepository(requests[0]);
            copado.Jobs.ExecutionCreateFromTemplateRequest request = new copado.Jobs.ExecutionCreateFromTemplateRequest();
            request.templateAPIName = 'Classic_to_Source_Format_Migration_2';

            SfpMigrationDetails dataJson = new SfpMigrationDetails();
            dataJson.repoName = 'SFP - ' + classicRepo.Name;
            dataJson.uri = requests[0].repositoryUri;
            dataJson.refreshSandboxes = requests[0].refreshSandboxes;
            dataJson.hasWip = requests[0].hasWip;
            dataJson.provider = classicRepo.copado__Git_Provider__c;
            dataJson.gitRepositoryId = requests[0].sfRepositoryId;
            dataJson.userStoryStatusValues = requests[0].userStoryStatusValues;

            request.dataJson = JSON.serialize(dataJson);
            request.pipelineId = pipelineId;
            request.sourceId = getLastEnvironmentOfPipeline(pipelineId);
            request.destinationId = getLastEnvironmentOfPipeline(pipelineId);
            request.callback = SfpMigrationJobCallback.class.getName();

            Id jobExecutionId = copado.Jobs.Execution.createFromTemplate(request).jobExecution?.Id;
            copado.Jobs.Execution.execute(new copado.Jobs.ExecutionRequest(jobExecutionId));
            return new List<Response>{ new Response(jobExecutionId) };
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    public static void authenticateGitRepository(Request request) {
        if (request.repositoryUri.contains('https')) {
            copado.RepositoryOAuth.RepositoryAuthenticationRequest authRequest = new copado.RepositoryOAuth.RepositoryAuthenticationRequest();
            authRequest.repositoryId = request.sfRepositoryId;
            authRequest.authType = 'HTTPS';
            authRequest.username = request.userName;
            authRequest.password = request.password;
            authRequest.extraHeaders = request.extraHeaders;

            copado.RepositoryOAuth.authenticate(authRequest);
        }
    }

    public static Id getDefaultCredentialId(Id pipelineId) {
        Id environmentId = getLastEnvironmentOfPipeline(pipelineId);
        List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(environmentId);
        copado__Org__c credential = !credentials.isEmpty() ? credentials[0] : null;
        return credential?.Id;
    }

    public static Id getLastEnvironmentOfPipeline(Id pipelineId) {
        List<copado__Deployment_Flow_Step__c> connections = getPipelineConnectionsForPipeline(pipelineId);
        if (connections.isEmpty()) {
            throw new ApplicationException(Label.Pipeline_Connection_does_not_exist);
        }

        Set<Id> sourceEnvs = new Set<Id>();
        Set<Id> destinationEnvs = new Set<Id>();
        for (copado__Deployment_Flow_Step__c pipelineConnection : connections) {
            sourceEnvs.add(pipelineConnection.copado__Source_Environment__c);
            destinationEnvs.add(pipelineConnection.copado__Destination_Environment__c);
        }

        for (Id destinationId : destinationEnvs) {
            if (!sourceEnvs.contains(destinationId)) {
                return destinationId;
            }
        }
        throw new ApplicationException(Label.InvalidPipelineStructure);
    }

    private static List<copado__Deployment_Flow_Step__c> getPipelineConnectionsForPipeline(Id pipelineId) {
        return new PipelineConnectionsSelector().byPipelineId(pipelineId);
    }

    // INNER

    public class Request {
        @InvocableVariable(label='Classic Pipeline Id')
        public Id pipelineId;

        @InvocableVariable(label='Sfp Repository Id')
        public Id sfRepositoryId;

        @InvocableVariable(label='Destinaton Respository URI')
        public String repositoryUri;

        @InvocableVariable(label='Refresh Sandboxes')
        public Boolean refreshSandboxes;

        @InvocableVariable(label='Has WIP?')
        public Boolean hasWip;

        @InvocableVariable(label='User Name')
        public String userName;

        @InvocableVariable(label='Password')
        public String password;

        @InvocableVariable(label='Extra Headers')
        public String extraHeaders;

        @InvocableVariable(label='Ssh key')
        public String sshKey;

        @InvocableVariable(label='User Story Status values')
        public String userStoryStatusValues;
    }

    public class Response {
        @InvocableVariable(label='Job Execution Id')
        public Id jobExecutionId;

        public Response(Id jobExecutionId) {
            this.jobExecutionId = jobExecutionId;
        }
    }
}