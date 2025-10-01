public with sharing class UpdateMigrationSnapshotJobDataJson {
    @InvocableMethod(label='Add Metadata.json ContentId ' category='MFP to SFP Migration')
    public static void execute(List<Request> requests) {
        try {
            copado__JobExecution__c jobExecution = (new JobExecutionsSelector().byIds(new Set<Id>{requests[0].jobExecutionId}))[0];
            SnapshotMigrationJson dataJson = (SnapshotMigrationJson) JSON.deserialize(jobExecution.copado__DataJson__c, SnapshotMigrationJson.class);
            dataJson.metadataRefreshResult = (RefreshMetadataJson) JSON.deserialize(requests[0].metadataRefreshResult, RefreshMetadataJson.class);

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
        public String metadataRefreshResult;
    }

    public class SnapshotMigrationJson {
        public String snapshotInformation;
        public String message;
        public RefreshMetadataJson metadataRefreshResult;
    }

    public class RefreshMetadataJson {
        public Id contentVersionId;
    }
}