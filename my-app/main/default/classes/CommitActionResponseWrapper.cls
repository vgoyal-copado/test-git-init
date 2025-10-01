global class CommitActionResponseWrapper {

    @InvocableVariable(label='Job Execution')
    public copado__JobExecution__c jobExecution;

    @InvocableVariable(label='User Story Commit')
    public copado__User_Story_Commit__c userStoryCommit;

    public CommitActionResponseWrapper(copado.CommitAction.Response resp) {
        this.jobExecution   = resp.jobExecution;
        this.userStoryCommit = resp.userStorycommit;
    }
}