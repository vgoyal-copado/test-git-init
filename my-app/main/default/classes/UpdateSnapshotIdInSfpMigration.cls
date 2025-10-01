public with sharing class UpdateSnapshotIdInSfpMigration {
    @InvocableMethod(label='Add Git Snapshot Id In SFP Migration JobExecution' category='SFP Migration')
    public static void execute(List<Request> requests) {
        try {
            copado__JobExecution__c jobExecution = (new JobExecutionsSelector().byIds(new Set<Id>{requests[0].jobExecutionId}))[0];
            SfpMigrationDetails dataJson = (SfpMigrationDetails)JSON.deserialize(jobExecution.copado__DataJson__c, SfpMigrationDetails.class);
            dataJson.gitSnapshotId = requests[0].gitSnapshotId;

            JobExecutionUpdateService.Request request =  new JobExecutionUpdateService.Request();
            JobExecutionUpdateService.ValuesToUpdateJson valuesToUpdate = new JobExecutionUpdateService.ValuesToUpdateJson();
            valuesToUpdate.fieldApiName = 'copado__DataJson__c';
            valuesToUpdate.value = JSON.serialize(dataJson);
    
            request.jobExecutionId = requests[0].jobExecutionId;
            request.valuesToUpdateJson = JSON.serialize(new List<JobExecutionUpdateService.ValuesToUpdateJson>{valuesToUpdate});
    
            JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{request});
            
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id jobExecutionId;

        @InvocableVariable(required=true)
        public Id gitSnapshotId;
    }
}