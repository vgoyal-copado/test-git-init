public inherited sharing class EnableNewCommitExpSettingImpl {
    
    public static PipelineSettings.EnableNewCommitExpSettingResult execute(PipelineSettings.EnableNewCommitExpSettingRequest request) {

        PipelineSettings.NewCommitExpSettingStatusRequest statusReq = new PipelineSettings.NewCommitExpSettingStatusRequest();
        statusReq.pipelineId = request.pipelineId;

        PipelineSettings.NewCommitExpSettingStatusResult statusResult = PipelineSettings.NewCommitExpSetting.status(statusReq);
        Boolean activated = statusResult.status;

        if (!statusResult.status && statusResult.unmetDependencies.isEmpty()) {
            copado.DevOpsUI.EnableNewCommitExpSettingRequest coreEnableRequest = new copado.DevOpsUI.EnableNewCommitExpSettingRequest();
            coreEnableRequest.pipelineId = request.pipelineId;

            copado.DevOpsUI.EnableNewCommitExpSettingResult coreEnableResult = copado.DevOpsUI.CommitExperience.enable(coreEnableRequest);
            activated = coreEnableResult.status;
        }
        
        PipelineSettings.EnableNewCommitExpSettingResult result = new PipelineSettings.EnableNewCommitExpSettingResult();
        result.status = activated; 
        
        return result;
    }
}