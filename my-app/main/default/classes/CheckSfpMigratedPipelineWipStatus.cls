public with sharing class CheckSfpMigratedPipelineWipStatus {
    @InvocableMethod(label='Check Work in Progress Migration Status' category='SFP Migration')
    public static List<Response> execute(List<Request> requests) {
        String isCompleted = 'false';
        String isFailed = 'false';
        try {
            Id sfpPipelineId = requests[0].sfpPipelineId;
            copado__Deployment_Flow__c pipeline = getPipeline(sfpPipelineId);

            SfpMigrationDetails.PipelineData pipelineData;
            if (String.isNotBlank(pipeline.Initialization_Data__c)) {
                pipelineData = (SfpMigrationDetails.PipelineData) JSON.deserialize(
                    pipeline.Initialization_Data__c,
                    SfpMigrationDetails.PipelineData.class
                );

                if (pipelineData != null) {
                    if (pipelineData.status == Label.BranchesCreated) {
                        isCompleted = 'true';
                    }
                    if (pipelineData.status == Label.BranchesCreationFailed) {
                        isFailed = 'true';
                    }
                }
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
        return new List<Response>{ new Response(isCompleted, isFailed) };
    }

    private static copado__Deployment_Flow__c getPipeline(Id pipelineId) {
        List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byId(new Set<Id>{ pipelineId });
        if (pipelines.isEmpty()) {
            throw new ApplicationException(Label.NoPipelineFound);
        }
        return pipelines[0];
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id sfpPipelineId;
    }

    public class Response {
        @InvocableVariable
        public String isCompleted;

        @InvocableVariable
        public String isFailed;

        public Response(String isCompleted, String isFailed) {
            this.isCompleted = isCompleted;
            this.isFailed = isFailed;
        }
    }
}