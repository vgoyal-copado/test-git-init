public inherited sharing class NewCommitExpSettingStatusImpl {
    
    public static PipelineSettings.NewCommitExpSettingStatusResult execute(PipelineSettings.NewCommitExpSettingStatusRequest request) {

        copado.DevOpsUI.NewCommitExpSettingStatusResult enabledStatusResult = checkEnabledStatus(request.pipelineId);
        PipelineSettings.NewCommitExpSettingDependency vlocityDependency = checkVlocityDependency(request.pipelineId);
        PipelineSettings.NewCommitExpSettingDependency metacacheDependency = checkMetacacheDependency(request.pipelineId);

        PipelineSettings.NewCommitExpSettingStatusResult result = new PipelineSettings.NewCommitExpSettingStatusResult();
        result.unmetDependencies = new List<PipelineSettings.NewCommitExpSettingDependency>();
        result.systemProperty = enabledStatusResult.systemProperty;
        result.status = enabledStatusResult.status;
        if (vlocityDependency != null) {
            result.unmetDependencies.add(vlocityDependency);
        }
        if (metacacheDependency != null) {
            result.unmetDependencies.add(metacacheDependency);
        }

        return result;
    }

    private static copado.DevOpsUI.NewCommitExpSettingStatusResult checkEnabledStatus(String pipelineId) {

        copado.DevOpsUI.NewCommitExpSettingStatusRequest coreStatusRequest = new copado.DevOpsUI.NewCommitExpSettingStatusRequest();
        coreStatusRequest.pipelineId = pipelineId;

        return copado.DevOpsUI.CommitExperience.status(coreStatusRequest);
    }


    private static PipelineSettings.NewCommitExpSettingDependency checkVlocityDependency(String pipelineId) {
        PipelineSettings.VlocitySettingStatusRequest vlocityStatusRequest = new PipelineSettings.VlocitySettingStatusRequest();
        vlocityStatusRequest.pipelineId = pipelineId;

        PipelineSettings.VlocitySettingStatusResult vlocityStatus = PipelineSettings.VlocitySetting.status(vlocityStatusRequest);
        if (vlocityStatus.status) {
            return new PipelineSettings.NewCommitExpSettingDependency(Label.Vlocity, Label.Disabled.toLowerCase());
        }

        return null;
    }

    private static PipelineSettings.NewCommitExpSettingDependency checkMetacacheDependency(String pipelineId) {
        Map<String, Object> metacacheStatusResult = PipelineBuilderSettingsCtrl.checkMetaCacheStatus(pipelineId);
        String pipelineStatus = getPipelineStatus(metacacheStatusResult);
        if (pipelineStatus?.toLowerCase() != 'activated') {
            return new PipelineSettings.NewCommitExpSettingDependency(Label.Copado_Intelligence_Title, Label.Enabled.toLowerCase());
        }

        return null;
    }

    private static String getPipelineStatus(Map<String, Object> response){
        String result = '';
        Map<String, Object> globalStatus = (Map<String, Object>)response.get('globalStatus');
        if(globalStatus != null){ 
            Map<String, Object> pipelineStatus = (Map<String, Object>)globalStatus.get('pipeline');
            result = (String)pipelineStatus?.get('pipelineStatus');
        }
        return result;
    }
}