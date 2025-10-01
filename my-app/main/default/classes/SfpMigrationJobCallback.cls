@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SfpMigrationJobCallback implements copado.JobExecutionCallback {

    // CONSTRUCTOR
    @SuppressWarnings('PMD.EmptyStatementBlock')
    global SfpMigrationJobCallback() {
        // Empty constructor needed so callback function can be called
    }

    // GLOBAL - EXECUTION CALLBACK
    global void execute(copado__JobExecution__c job, String status) {
        try {
            if (job.copado__Pipeline__c == null) {
                return;
            }
            if (status != 'Successful') {
                copado__JobExecution__c jobExecution = new JobExecutionsSelector().byIds(new Set<Id>{ job.Id })[0];

                List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byId(new Set<Id>{ jobExecution?.copado__Pipeline__c });
                if (pipelines.isEmpty()) {
                    throw new ApplicationException(Label.NoPipelineFound);
                }

                copado__Deployment_Flow__c pipeline = pipelines[0];
                pipeline.copado__Block_Commits__c = false;
                pipeline.copado__Active__c = true;

                Map<Id, copado__Environment__c> pipelineEnvironments = new PipelineDescriptor(pipeline.Id).getEnvironments();

                List<copado__Environment__c> environmentsToUpdate = new List<copado__Environment__c>();
                for (copado__Environment__c environment : pipelineEnvironments.values()) {
                    environment.copado__Platform__c = 'Salesforce';
                    environmentsToUpdate.add(environment);
                }

                update as User environmentsToUpdate;
                update as User pipeline;

                deleteSfpRepository(jobExecution);
                deleteSfpPipeline(jobExecution);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // PRIVATE

    private void deleteSfpRepository(copado__JobExecution__c jobExecution) {
        SfpMigrationDetails dataJson = (SfpMigrationDetails) JSON.deserialize(jobExecution.copado__DataJson__c, SfpMigrationDetails.class);

        Id repositoryId = dataJson?.gitRepositoryId;
        if (repositoryId != null) {
            copado__Git_Repository__c repository = new copado__Git_Repository__c(Id = repositoryId);
            Utilities.performDML(new List<copado__Git_Repository__c>{ repository }, 'delete', AccessLevel.SYSTEM_MODE);
        }
    }

    private void deleteSfpPipeline(copado__JobExecution__c jobExecution) {
        SfpMigrationDetails dataJson = (SfpMigrationDetails) JSON.deserialize(jobExecution.copado__DataJson__c, SfpMigrationDetails.class);

        Id sfpPipelineId = dataJson?.sfpPipelineId;
        if (sfpPipelineId != null) {
            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c(Id = sfpPipelineId);
            Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipeline }, 'delete', AccessLevel.SYSTEM_MODE);
        }
    }
}