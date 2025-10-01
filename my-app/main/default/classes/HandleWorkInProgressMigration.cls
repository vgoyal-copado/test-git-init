@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.ExcessiveParameterList')
global with sharing class HandleWorkInProgressMigration implements copado.JobExecutionCallback {
    private static final String SFP_MIGRATION_WIP = 'SFP_Migration_WIP_1';
    private static final String CREATING_BRANCHES = 'Creating branches';

    // CONSTRUCTOR
    @SuppressWarnings('PMD.EmptyStatementBlock')
    global HandleWorkInProgressMigration() {
        // Empty constructor needed so callback function can be called
    }

    // GLOBAL - EXECUTION CALLBACK
    global void execute(copado__JobExecution__c job, String status) {
        try {
            JsonInformation jobDataJson = (JsonInformation) JSON.deserialize(job?.copado__DataJson__c, JsonInformation.class);
            CommitOtherInformation commitJobJson = (CommitOtherInformation) JSON.deserialize(jobDataJson.jsonInformation, CommitOtherInformation.class);
            if (commitJobJson.pipelineId == null) {
                return;
            }
            copado__Deployment_Flow__c pipeline = getPipeline(commitJobJson?.pipelineId);
            SfpMigrationDetails.PipelineData currentInitializationData = getCurrentInitializationData(pipeline?.Initialization_Data__c);

            if (status == 'Successful') {
                createBranches(pipeline);
            } else {
                updateCommitFailure(currentInitializationData, status, pipeline.Id);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // PUBLIC

    @InvocableMethod(label='Handle Work in Progress Migration' category='SFP Migration')
    public static List<Response> execute(List<Request> requests) {
        Id sfpPipelineId;
        try {
            Id jobExecutionId = requests[0].jobExecutionId;

            copado__JobExecution__c jobExecution = (new JobExecutionsSelector().byIds(new Set<Id>{jobExecutionId}))[0];
            SfpMigrationDetails dataJson = (SfpMigrationDetails)JSON.deserialize(jobExecution.copado__DataJson__c, SfpMigrationDetails.class);

            List<SfpMigrationDetails.Connection> connections = (List<SfpMigrationDetails.Connection>)JSON.deserialize(dataJson.connections, List<SfpMigrationDetails.Connection>.class);

            SfpMigrationDetails.Connection firstConnection = null;
            for (SfpMigrationDetails.Connection conn : connections) {
                if (conn.order == 1) { 
                    firstConnection = conn; 
                    break;
                }
            }

            if (firstConnection != null) {
                copado__JobExecution__c job = createJobForBranchCreation(firstConnection, dataJson.sfpPipelineId, dataJson.gitRepositoryId);
                updateInitData(job?.Id, dataJson.sfpPipelineId, firstConnection, jobExecution, dataJson.gitRepositoryId);
            }
            sfpPipelineId = dataJson.sfpPipelineId;
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
        return new List<Response>{ new Response(sfpPipelineId) };
    }

    public void createBranches(copado__Deployment_Flow__c pipeline) {
        copado__Deployment_Flow__c pipelineRecord = getPipeline(pipeline.Id);
        SfpMigrationDetails.PipelineData currentInitializationData = getCurrentInitializationData(pipelineRecord?.Initialization_Data__c);
        if (currentInitializationData.currentEnvironmentId == null) {
            return;
        }

        SfpMigrationDetails.Connection matchingConnection = null;
    
        if (String.isNotBlank(currentInitializationData.connections)) {
            List<SfpMigrationDetails.Connection> connections = 
                (List<SfpMigrationDetails.Connection>)JSON.deserialize(
                    currentInitializationData.connections,
                    List<SfpMigrationDetails.Connection>.class
                );
            
            for (SfpMigrationDetails.Connection conn : connections) {
                if (conn.destinationEnvId == currentInitializationData.currentEnvironmentId) {
                    matchingConnection = conn;
                    break;
                }
            }
        }

        if (matchingConnection != null) {
            copado__JobExecution__c job = createJobForBranchCreation(matchingConnection, pipeline.Id, currentInitializationData.gitRepositoryId);
            updateInitializationDataWithJobId(job?.Id, pipelineRecord, matchingConnection);
        }
    }

    // PRIVATE

    private static copado__JobExecution__c createJobForBranchCreation(SfpMigrationDetails.Connection connection, Id sfpPipelineId, Id gitRepositoryId) {
        copado.Jobs.ExecutionCreateFromTemplateRequest initializeRequest = new copado.Jobs.ExecutionCreateFromTemplateRequest();
        initializeRequest.templateAPIName = SFP_MIGRATION_WIP;
        initializeRequest.pipelineId = sfpPipelineId;
        initializeRequest.dataJson = getBranchesJson(connection, gitRepositoryId);
        initializeRequest.callback = EnvironmentBranchCreationCallback.class.getName();
        copado__JobExecution__c initializeJob = copado.Jobs.Execution.createFromTemplate(initializeRequest).jobExecution;

        copado.Jobs.ExecutionResult executionResult = copado.Jobs.Execution.execute(new copado.Jobs.ExecutionRequest(initializeJob.Id));
        return executionResult.jobExecution;
    }

    private static String getBranchesJson(SfpMigrationDetails.Connection connection, Id gitRepositoryId) {
        Map<String, String> jobData = new Map<String, String>();
        jobData.put('createBranch', connection.branchTo);
        jobData.put('fromBranch', connection.branchFrom);
        jobData.put('gitRepositoryId', gitRepositoryId);

        return JSON.serialize(jobData);
    }

    private static void updateInitData(Id jobId, Id pipelineId, SfpMigrationDetails.Connection connection, copado__JobExecution__c jobExecution, Id gitRepositoryId) {
        copado__Deployment_Flow__c pipeline = getPipeline(pipelineId);

        SfpMigrationDetails.PipelineData pipelineData;
        if (String.isNotBlank(pipeline.Initialization_Data__c)) {
            pipelineData = (SfpMigrationDetails.PipelineData)JSON.deserialize(
                pipeline.Initialization_Data__c,
                SfpMigrationDetails.PipelineData.class
            );
        } else {
            pipelineData = new SfpMigrationDetails.PipelineData();
        }

        pipelineData.status = CREATING_BRANCHES;
        pipelineData.pendingEnvironmentIds = getPipelineEnvironmentIds(pipeline.Id, pipeline.copado__Main_Branch__c);
        pipelineData.currentEnvironmentId = pipelineData.pendingEnvironmentIds[0];
        pipelineData.migrationJobId = jobExecution.Id;
        pipelineData.gitRepositoryId = gitRepositoryId;
        pipelineData.classicPipelineId = jobExecution.copado__Pipeline__c;

        if (pipelineData.jobIds == null) {
            pipelineData.jobIds = new List<Id>();
        }

        if (jobId != null) {
            pipelineData.jobIds.add(jobId);
        }

        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = pipelineId,
            Initialization_Data__c = JSON.serializePretty(pipelineData)
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }

    private static void updateInitializationDataWithJobId(Id jobId, copado__Deployment_Flow__c pipeline, SfpMigrationDetails.Connection connection) {
        SfpMigrationDetails.PipelineData pipelineData;

        if (String.isNotBlank(pipeline.Initialization_Data__c)) {
            pipelineData = (SfpMigrationDetails.PipelineData)JSON.deserialize(
                pipeline.Initialization_Data__c,
                SfpMigrationDetails.PipelineData.class
            );
        }

        if (pipelineData.jobIds == null) {
            pipelineData.jobIds = new List<Id>();
        }

        if (jobId != null) {
            pipelineData.jobIds.add(jobId);
        }

        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = pipeline.Id,
            Initialization_Data__c = JSON.serializePretty(pipelineData)
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }

    private static List<Id> getPipelineEnvironmentIds(Id pipelineId, String mainBranch) {
        List<Id> result = new List<Id>();

        try {
            PipelineDescriptor pipelineDescriptor = new PipelineDescriptor(pipelineId, mainBranch);

            List<copado__Deployment_Flow_Step__c> orderedConnections = pipelineDescriptor.getOrderedPipelineConnections();
            for (copado__Deployment_Flow_Step__c connection : orderedConnections) {
                result.add(connection.copado__Source_Environment__c);
            }
        } catch (Exception ex) {
            throw new ApplicationException(Label.VisitPipelineManager);
        }

        return result;
    }

    private void updateCommitFailure(SfpMigrationDetails.PipelineData currentPipelineData, String status, Id pipelineId) {
        currentPipelineData.status = 'Commit failed';

        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = pipelineId,
            Initialization_Data__c = JSON.serialize(currentPipelineData)
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }

    private static copado__Deployment_Flow__c getPipeline(Id pipelineId) {
        List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byId(new Set<Id>{ pipelineId });
        if (pipelines.isEmpty()) {
            throw new ApplicationException(Label.NoPipelineFound);
        }

        return pipelines[0];
    }

    private SfpMigrationDetails.PipelineData getCurrentInitializationData(String initializationData) {
        if (String.isBlank(initializationData)) {
            throw new ApplicationException(String.format(Label.MissingRequiredParameters, new List<String> { Label.PipelineInitializationData }));
        }

        return (SfpMigrationDetails.PipelineData) JSON.deserialize(initializationData, SfpMigrationDetails.PipelineData.class);
    }

    // INNER

    public class Request {
        @InvocableVariable(required=true)
        public Id jobExecutionId;
        @InvocableVariable(required=true)
        public Id resultId;
    }

    public class Response {
        @InvocableVariable
        public Id sfpPipelineId;

        public Response(Id sfpPipelineId) {
            this.sfpPipelineId = sfpPipelineId;
        }
    }

    @TestVisible
    private class JsonInformation {
        public String jsonInformation;
    }

    @TestVisible
    private class CommitOtherInformation {
        public Id environmentId;
        public Id pipelineId;
    }
}