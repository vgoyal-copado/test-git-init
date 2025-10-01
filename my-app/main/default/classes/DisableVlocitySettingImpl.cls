public inherited sharing class DisableVlocitySettingImpl {

    private static final String SYSTEM_PROPERTY_API_NAME = 'vlocity_enabled';

    private static final String COMMIT_ACTION = 'Commit';
    private static final String PROMOTION_DEPLOYMENT = 'PromotionDeployment';
    private static final String ROLLBACK_ACTION = 'Rollback';
    private static final String TAKE_SNAPSHOT = 'TakeSnapshot';

    private static final String COMMIT_JOB_TEMPLATE = 'sfdx_commit_1';
    private static final String DEPLOY_JOB_TEMPLATE = 'sfdx_deploy_1';
    private static final String ROLLBACK_JOB_TEMPLATE = 'SFDX_Rollback_1';
    private static final String TAKE_SNAPSHOT_JOB_TEMPLATE = 'SFDX_Git_Snapshot_1';

    private static final Map<String, String> TEMPLATE_NAMES = new Map<String, String> {
            COMMIT_ACTION => COMMIT_JOB_TEMPLATE,
            PROMOTION_DEPLOYMENT => DEPLOY_JOB_TEMPLATE,
            ROLLBACK_ACTION => ROLLBACK_JOB_TEMPLATE,
            TAKE_SNAPSHOT => TAKE_SNAPSHOT_JOB_TEMPLATE
    };

    public static PipelineSettings.DisableVlocitySettingResult execute(PipelineSettings.DisableVlocitySettingRequest request) {
        PipelineSettings.VlocitySettingStatusRequest statusRequest = new PipelineSettings.VlocitySettingStatusRequest();
        statusRequest.pipelineId = request.pipelineId;
        PipelineSettings.VlocitySettingStatusResult vlocitySettingResult = PipelineSettings.VlocitySetting.status(statusRequest);
       
        if (vlocitySettingResult.status){
            deleteSystemProperty(vlocitySettingResult.systemProperty);
            updatePipelineActions(request);
        }
        
        PipelineSettings.DisableVlocitySettingResult result = new PipelineSettings.DisableVlocitySettingResult();
        result.status = true; 
        
        return result;
    }

    // PRIVATE

    public static void deleteSystemProperty(copado__System_Property__c systemProperty) {
        Utilities.performDML(new List<copado__System_Property__c>{ systemProperty }, 'delete', AccessLevel.USER_MODE);
    }

    public static void updatePipelineActions(PipelineSettings.DisableVlocitySettingRequest request) {
        Map<String, String> vlocityJobTemplates = jobTemplatesByApiName(TEMPLATE_NAMES.values());
        
        List<copado__Pipeline_Action__c> pipelineActions = getPipelineActions(request.pipelineId);
        for (copado__Pipeline_Action__c pipelineAction :  pipelineActions){
            pipelineAction.copado__Job_Template__c = vlocityJobTemplates.get(TEMPLATE_NAMES.get(pipelineAction.copado__Action__c));  
        }
        
        Utilities.performDML(pipelineActions, 'update', AccessLevel.USER_MODE);
    }

    private static List<copado__Pipeline_Action__c> getPipelineActions(Id pipelineId){
        return [SELECT Id, copado__Action__c, copado__Job_Template__c FROM copado__Pipeline_Action__c 
        WHERE copado__Pipeline__c =: pipelineId 
        AND copado__Action__c IN :TEMPLATE_NAMES.keyset() 
        AND copado__Default__c = true WITH USER_MODE];
    }

    private static Map<String, String> jobTemplatesByApiName(List<String> templateNames){
        Map<String, String> result = new Map<String, String>();
        
        for (copado__JobTemplate__c jobTemplate : [SELECT Id, copado__ApiName__c
        FROM copado__JobTemplate__c WHERE copado__ApiName__c IN : templateNames WITH USER_MODE]){
            result.put(jobTemplate.copado__ApiName__c, jobTemplate.Id);
        }

        return result;
    }
}