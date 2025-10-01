public with sharing class UpdateGitRepoDetailsOnJobExecution {
    @InvocableMethod(label='Save Git Repo Details' category='SFP Migration')
    public static void execute(List<Request> requests) {
        try {

            // Save Authentication Details in Sensitive_Information__c

            GitJson gitJson = getGitJsonValue(requests[0].classicGitRepositoryId);
            Id gitRepositoryId = requests[0].gitRepositoryId;
            QuickStartGitRepositoryCtrl.save(gitRepositoryId, 'HTTPS', gitJson.username, gitJson.password, '');
            

            // Update the details on JE DataJson
           
            String uri = requests[0].uri;
            Id jobExecutionId = requests[0].jobExecutionId;
            copado__JobExecution__c jobExecution = (new JobExecutionsSelector().byIds(new Set<Id>{jobExecutionId}))[0];
            SfpMigrationDetails dataJson =(SfpMigrationDetails)JSON.deserialize(jobExecution.copado__DataJson__c, SfpMigrationDetails.class);
            dataJson.gitRepositoryId = gitRepositoryId;
            dataJson.uri = uri;
            dataJson.classicGitRepositoryId = requests[0].classicGitRepositoryId;
            JobExecutionUpdateService.Request request =  new JobExecutionUpdateService.Request();
            JobExecutionUpdateService.ValuesToUpdateJson valuesToUpdate = new JobExecutionUpdateService.ValuesToUpdateJson();
            valuesToUpdate.fieldApiName = 'copado__DataJson__c';
            valuesToUpdate.value = JSON.serialize(dataJson);

            request.jobExecutionId = jobExecutionId;
            request.valuesToUpdateJson = JSON.serialize(new List<JobExecutionUpdateService.ValuesToUpdateJson>{valuesToUpdate});

            JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{request});
            
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    private static GitJson getGitJsonValue(Id classicGitRepositoryId) {
        copado.Jobs.DynamicExpressionEvaluateRequest request = new copado.Jobs.DynamicExpressionEvaluateRequest(
            classicGitRepositoryId,
            new List<String>{ '{$Context.Repository.Credential}' }
        );
        List<copado.Jobs.DynamicExpressionEvaluateResult> responses = copado.Jobs.DynamicExpression.evaluate(request);
        return (GitJson)JSON.deserialize(responses[0].value, GitJson.class);
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id gitRepositoryId;

        @InvocableVariable(required=true)
        public String uri;

        @InvocableVariable(required=true)
        public Id jobExecutionId;

        @InvocableVariable(required=true)
        public Id classicGitRepositoryId;
    }

    public class GitJson {
        public String url;
        public String type;
        public String username;
        public String password;
    }
}