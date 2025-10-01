public with sharing class MigrationGitInitializerStatusCheck {
    @InvocableMethod(label='Check if Project initialized' category='SFP Migration')
    public static List<Response> execute(List<Request> requests) {
        try {
            Boolean isProjectInitialized = false;
            if (requests[0].jobStatus == 'Error') {
                isProjectInitialized = isProjectInitialized(requests[0].jobId);
            }

            return new List<Response>{ new Response(isProjectInitialized) };
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    // PRIVATE

    private static Boolean isProjectInitialized(Id jobId) {
        Boolean result = false;

        List<copado__Result__c> jobStepResults = new ResultsSelector().byJobExecutionId(jobId);

        if (!jobStepResults.isEmpty() && String.isNotBlank(jobStepResults[0].copado__Result_Data__c)) {
            ResultData resultData = (ResultData) JSON.deserialize(jobStepResults[0].copado__Result_Data__c, ResultData.class);
            result = resultData.projectInitialized;
        }

        return result;
    }

    // INNER

    public class Request {
        @InvocableVariable(required=true)
        public Id jobId;

        @InvocableVariable(required=true)
        public String jobStatus;
    }

    public class Response {
        @InvocableVariable
        public Boolean isProjectInitialized;

        public Response(Boolean isProjectInitialized) {
            this.isProjectInitialized = isProjectInitialized;
        }
    }

    private class ResultData {
        Boolean projectInitialized;
    }
}