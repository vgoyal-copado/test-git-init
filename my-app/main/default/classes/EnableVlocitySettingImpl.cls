public inherited sharing class EnableVlocitySettingImpl {

    private static final String SYSTEM_PROPERTY_API_NAME = 'vlocity_enabled';
    private static final String SYSTEM_PROPERTY_VALUE = 'true';
    
    private static final String COMMIT_ACTION = 'Commit';
    private static final String PROMOTION_DEPLOYMENT = 'PromotionDeployment';
    private static final String ROLLBACK_ACTION = 'Rollback';
    private static final String TAKE_SNAPSHOT = 'TakeSnapshot';
    
    private static final String VLOCITY_COMMIT_JOB_TEMPLATE = 'SFDX Vlocity Commit_1';
    private static final String VLOCITY_DEPLOY_JOB_TEMPLATE = 'SFDX Vlocity Deploy_1';
    private static final String VLOCITY_ROLLBACK_JOB_TEMPLATE = 'SFDX_Vlocity_Rollback_1';
    private static final String VLOCITY_TAKE_SNAPSHOT_JOB_TEMPLATE = 'SFDX_Vlocity_Git_Snapshot_1';

    private static final Map<String, String> VLOCITY_TEMPLATE_NAMES = new Map<String, String> {
            COMMIT_ACTION => VLOCITY_COMMIT_JOB_TEMPLATE,
            PROMOTION_DEPLOYMENT => VLOCITY_DEPLOY_JOB_TEMPLATE,
            ROLLBACK_ACTION => VLOCITY_ROLLBACK_JOB_TEMPLATE,
            TAKE_SNAPSHOT => VLOCITY_TAKE_SNAPSHOT_JOB_TEMPLATE
    };

    public static PipelineSettings.EnableVlocitySettingResult execute(PipelineSettings.EnableVlocitySettingRequest request) {
        PipelineSettings.VlocitySettingStatusRequest statusRequest = new PipelineSettings.VlocitySettingStatusRequest();
        statusRequest.pipelineId = request.pipelineId;
        PipelineSettings.VlocitySettingStatusResult vlocitySettingResult = PipelineSettings.VlocitySetting.status(statusRequest);
        if (!vlocitySettingResult.status) {
            insertSystemProperty(request);
            updatePipelineActions(request);
            disableNewCommitExpSetting(request.pipelineId);
        }
        
        PipelineSettings.EnableVlocitySettingResult result = new PipelineSettings.EnableVlocitySettingResult();
        result.status = true; 
        
        return result;
    }

    // PRIVATE

    public static void insertSystemProperty(PipelineSettings.EnableVlocitySettingRequest request) {
        copado__System_Property__c systemProperty = new copado__System_Property__c();
        systemProperty.copado__Pipeline__c = request.pipelineId;
        systemProperty.Name = SYSTEM_PROPERTY_API_NAME;
        systemProperty.copado__API_Name__c = SYSTEM_PROPERTY_API_NAME;
        systemProperty.copado__Value__c = SYSTEM_PROPERTY_VALUE;

        Utilities.performDML(new List<copado__System_Property__c>{ systemProperty }, 'insert', AccessLevel.USER_MODE);
    }

    public static void updatePipelineActions(PipelineSettings.EnableVlocitySettingRequest request) {
        Map<String, String> vlocityJobTemplates = jobTemplatesByApiName(VLOCITY_TEMPLATE_NAMES.values());
        
        List<copado__Pipeline_Action__c> pipelineActions = getPipelineActions(request.pipelineId);
        for (copado__Pipeline_Action__c pipelineAction :  pipelineActions){
            pipelineAction.copado__Job_Template__c = vlocityJobTemplates.get(VLOCITY_TEMPLATE_NAMES.get(pipelineAction.copado__Action__c));  
        }
        
        Utilities.performDML(pipelineActions, 'update', AccessLevel.USER_MODE);
    }

    private static List<copado__Pipeline_Action__c> getPipelineActions(Id pipelineId){
        return [SELECT Id, copado__Action__c, copado__Job_Template__c FROM copado__Pipeline_Action__c 
        WHERE copado__Pipeline__c =: pipelineId 
        AND copado__Action__c IN :VLOCITY_TEMPLATE_NAMES.keyset() 
        AND copado__Default__c = true WITH USER_MODE];
    }

    private static Map<String, String> jobTemplatesByApiName(List<String> templateNames){
        Map<String, String> result = new Map<String, String>();
        
        for (copado__JobTemplate__c jobTemplate : [SELECT Id, copado__ApiName__c
        FROM copado__JobTemplate__c WHERE copado__ApiName__c IN : templateNames
        WITH USER_MODE]){
            result.put(jobTemplate.copado__ApiName__c, jobTemplate.Id);
        }

        return result;
    }

    private static void disableNewCommitExpSetting(Id pipelineId) {
        copado.DevOpsUI.DisableNewCommitExpSettingRequest request = new copado.DevOpsUI.DisableNewCommitExpSettingRequest();
        request.pipelineId = pipelineId;

        copado.DevOpsUI.CommitExperience.disable(request);
    }
}