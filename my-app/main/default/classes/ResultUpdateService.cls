public with sharing class ResultUpdateService {
    
    private static final String RESULT = 'copado__Result__c';

    @InvocableMethod(label='Result update service from flows' category='Result Update')
    public static void execute(List<Request> requests) {
        try {
            Id resultId = requests[0].resultId;

            if(resultId == null || String.isBlank(requests[0].valuesToUpdateJson)) {
                return;
            }
            List<ValuesToUpdateJson> data = (List<ValuesToUpdateJson>) JSON.deserialize(requests[0].valuesToUpdateJson, List<ValuesToUpdateJson>.class);
            
            copado__Result__c recordToUpdate = new copado__Result__c(Id = resultId);
            Map<String, Schema.SObjectField> resultFieldMap = Utilities.getFieldMapForObject(RESULT);
            Boolean validUpdateRequest = false;

            for(ValuesToUpdateJson change : data){
                if(resultFieldMap.containsKey(change.fieldApiName.toLowerCase())) {
                   recordToUpdate.put(change.fieldApiName, change.value);
                   validUpdateRequest = true;
                }
            }

            if(validUpdateRequest) {
                updateResult(recordToUpdate);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    //PRIVATE

    private static void updateResult(copado__Result__c result) {
        Utilities.performDML(new List<copado__Result__c>{ result }, 'update', AccessLevel.USER_MODE);
    }

    // INNER

    public class Request {
        @InvocableVariable(required=true)
        public Id resultId;

        @InvocableVariable(required=true label='Data Json for field and its value changes')
        public String valuesToUpdateJson;
    }

    @TestVisible
    private class ValuesToUpdateJson {
        public String fieldApiName;
        public String value;
    }
}