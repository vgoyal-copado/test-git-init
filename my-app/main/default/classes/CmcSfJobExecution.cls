public with sharing class CmcSfJobExecution {
    // PUBLIC

    public String templateName;
    public Id pipelineId;
    public Id sourceId;
    public String dataJson;
    public Id recordId;
    public Boolean hasPreFetchEnabled;

    public CmcSfJobExecution templateName(String templateName) {
        this.templateName = templateName;
        return this;
    }

    public CmcSfJobExecution pipelineId(Id pipelineId) {
        this.pipelineId = pipelineId;
        return this;
    }

    public CmcSfJobExecution sourceId(Id sourceId) {
        this.sourceId = sourceId;
        return this;
    }

    public CmcSfJobExecution dataJson(String dataJson) {
        this.dataJson = dataJson;
        return this;
    }

    public CmcSfJobExecution enablePreFetch(Boolean hasPreFetchEnabled) {
        this.hasPreFetchEnabled = hasPreFetchEnabled;
        return this;
    }

    public CmcSfJobExecution run() {
        copado.Jobs.ExecutionCreateFromTemplateRequest templateRequest = this.hasPreFetchEnabled ? createRequestWithPrefetchEnabled() : createRequest();
        this.recordId = copado.Jobs.Execution.createFromTemplate(templateRequest).jobExecution?.Id;
        copado.Jobs.Execution.execute(new copado.Jobs.ExecutionRequest(this.recordId));
        return this;
    }

    public copado__JobExecution__c fetchDetails() {
        List<copado__JobExecution__c> result = new JobExecutionsSelector().byIds(new Set<Id>{ this.recordId });
        return result.isEmpty() ? new copado__JobExecution__c() : result[0];
    }

    // PRIVATE

    private copado.Jobs.ExecutionCreateFromTemplateRequest createRequest() {
        copado.Jobs.ExecutionCreateFromTemplateRequest request = new copado.Jobs.ExecutionCreateFromTemplateRequest();
        request.templateAPIName = this.templateName;
        request.dataJson = this.dataJson;
        request.pipelineId = this.pipelineId;
        request.sourceId = this.sourceId;
        return request;
    }

    private copado.Jobs.ExecutionCreateFromTemplateRequest createRequestWithPrefetchEnabled() {
        copado.Jobs.ExecutionCreateFromTemplateRequest request = new copado.Jobs.ExecutionCreateFromTemplateRequest();
        request.templateAPIName = this.templateName;
        request.dataJson = this.dataJson;
        request.pipelineId = this.pipelineId;
        request.sourceId = this.sourceId;
        request.steps = getPrefetchedStepIfEnabled(this.pipelineId);
        return request;
    }

    private List<copado.Jobs.ExecutionStep> getPrefetchedStepIfEnabled(Id pipelineId) {
        copado.Jobs.GetPrefetchedStepIfEnabledRequest prefetchRequest = new copado.Jobs.GetPrefetchedStepIfEnabledRequest(pipelineId);
        copado.Jobs.ExecutionStep preFetchedStep = copado.Jobs.Execution.getPrefetchedStepIfEnabled(prefetchRequest);
        return preFetchedStep != null ? new List<copado.Jobs.ExecutionStep> { preFetchedStep } : null;
    }
}