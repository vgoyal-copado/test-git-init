public with sharing class StartSnapshotSfpMigration {
    public static final String MFP_TO_SFP_SNAPSHOT_MIGRATION = 'MFP_to_SFP_Snapshot_migration_1';

    @InvocableMethod(label='Add Snapshot Job Execution' category='Job Execution')
    public static List<Response> execute(List<Request> requests) {
        try {
            SnapshotInitializationDetails projectInitDetails = new SnapshotInitializationDetails();
            projectInitDetails.message = 'Snapshot commit';
            copado__JobExecution__c job = sendExecutionRequest(projectInitDetails, requests[0]);
            return new List<Response>{ new Response(job.Id) };
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    private static copado__JobExecution__c sendExecutionRequest(SnapshotInitializationDetails projectInitDetails, Request request) {
        copado__JobExecution__c execution = copado.Jobs.Execution.createFromTemplate(createExecutionRequest(projectInitDetails, request)).jobExecution;
        copado.Jobs.Execution.execute(new copado.Jobs.ExecutionRequest(execution.Id));
        return getJobExecution(execution.Id);
    }

    private static copado.Jobs.ExecutionCreateFromTemplateRequest createExecutionRequest(SnapshotInitializationDetails projectInitDetails, Request req) {
        copado.Jobs.ExecutionCreateFromTemplateRequest request = new copado.Jobs.ExecutionCreateFromTemplateRequest();
        request.templateAPIName = MFP_TO_SFP_SNAPSHOT_MIGRATION;
        projectInitDetails.snapshotInformation = req.snapshotInformation;
        request.dataJson = JSON.serialize(projectInitDetails); // branch, snapshotInformation(find replace, env replace), 
        request.pipelineId = req.pipelineId;
        request.sourceId = req.sourceOrgId;
        request.parentId = req.snapshotId;
        return request;
    }

    private static copado__JobExecution__c getJobExecution(Id jobExecutionId) {
        List<copado__JobExecution__c> result = new JobExecutionsSelector().byIds(new Set<Id>{ jobExecutionId });
        return result.isEmpty() ? new copado__JobExecution__c() : result[0];
    }

    // INNER
    public class SnapshotInitializationDetails {
        public String message;
        public String snapshotInformation;
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id sourceOrgId; 
        
        @InvocableVariable(required=true)
        public Id snapshotId; 

        @InvocableVariable(required=true)
        public Id pipelineId; 

        @InvocableVariable(required=true)
        public String branch; 

        @InvocableVariable(required=true)
        public String snapshotInformation;
    }

    public class Response {
        @InvocableVariable
        public Id jobExecutionId;

        public Response(Id jobExecutionId) {
            this.jobExecutionId = jobExecutionId;
        }
    }
}