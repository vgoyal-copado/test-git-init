public with sharing class JobExecutionUpdateService {
    private static final String JOB_EXECUTION = 'copado__JobExecution__c';

    @InvocableMethod(label='Job Execution update service from flows' category='Job Execution Update')
    public static void execute(List<Request> requests) {
        try {
            Id jobExecutionId = requests[0].jobExecutionId;

            if(jobExecutionId == null || String.isBlank(requests[0].valuesToUpdateJson)) {
                return;
            }
            List<ValuesToUpdateJson> data = (List<ValuesToUpdateJson>) JSON.deserialize(requests[0].valuesToUpdateJson, List<ValuesToUpdateJson>.class);
            
            copado__JobExecution__c recordToUpdate = new copado__JobExecution__c(Id = jobExecutionId);
            Boolean validUpdateRequest = false;
            Map<String, Schema.SObjectField> jobExecutionFieldMap = Utilities.getFieldMapForObject(JOB_EXECUTION);

            for(ValuesToUpdateJson change : data){
                if(jobExecutionFieldMap.containsKey(change.fieldApiName.toLowerCase())) {
                   recordToUpdate.put(change.fieldApiName, change.value);
                   validUpdateRequest = true;
                }
            }

            if(validUpdateRequest) {
                updateJobExecution(recordToUpdate);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    //PRIVATE

    private static void updateJobExecution(copado__JobExecution__c record) {
        Utilities.performDML(new List<copado__JobExecution__c>{ record }, 'update', AccessLevel.USER_MODE);
    }

    // INNER

    public class Request {
        @InvocableVariable(required=true)
        public Id jobExecutionId;

        @InvocableVariable(required=true label='Data Json for field and its value changes')
        public String valuesToUpdateJson;
    }

    public class ValuesToUpdateJson {
        public String fieldApiName;
        public String value;
    }
}