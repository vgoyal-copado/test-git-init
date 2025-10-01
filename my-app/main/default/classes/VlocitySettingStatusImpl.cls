public inherited sharing class VlocitySettingStatusImpl {

    private static final String SYSTEM_PROPERTY = 'vlocity_enabled';

    public static PipelineSettings.VlocitySettingStatusResult execute(PipelineSettings.VlocitySettingStatusRequest request) {
        List<copado__System_Property__c> systemProperties = new SystemPropertiesSelector()
            .byPipelineAndCreatedDateForSFDX(new Set<Id>{ request.pipelineId }, SYSTEM_PROPERTY);

        PipelineSettings.VlocitySettingStatusResult result = new PipelineSettings.VlocitySettingStatusResult();
        result.systemProperty = !systemProperties.isEmpty() && systemProperties[0]?.copado__Value__c?.toLowerCase() == 'true' ? systemProperties[0] : null;
        result.status = result.systemProperty != null ? true : false;
        return result;
    }
}