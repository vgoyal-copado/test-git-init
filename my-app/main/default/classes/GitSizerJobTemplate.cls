public with sharing class GitSizerJobTemplate {
    // PUBLIC

    @AuraEnabled
    public static Id execute(Id repositoryId) {
        try {
            List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byGitRepositoryAndIsActivePipeline(repositoryId);
            if (pipelines.isEmpty() || String.isBlank(pipelines[0].copado__Main_Branch__c)) {
                throw new ApplicationException(Label.NO_MAIN_BRANCH_DEFINED);
            }
            copado.CreateExecution.Request req = new copado.CreateExecution.Request();
            req.parentId = repositoryId;
            req.pipelineId = pipelines[0].Id;
            req.templateName = 'Git_Sizer_1';
            req.dataJson = JSON.serialize(new DataJson(pipelines[0].copado__Main_Branch__c));
            req.runAfterInstantiation = true;
            List<copado__JobExecution__c> execution = copado.CreateExecution.execute(new List<copado.CreateExecution.Request>{ req });
            return execution.isEmpty() ? null : execution[0].Id;
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    // PRIVATE

    private class DataJson {
        private String mainBranch;
        private DataJson(String mainBranch) {
            this.mainBranch = mainBranch;
        }
    }
}