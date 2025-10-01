@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class PipelineBuilderSettingsCtrl {
    private static final String COPADO_METACACHE_ENABLED = 'copado__MetaCache_Enabled';
    private static final String COPADO_ADMIN = 'Copado Admin';
    private static final String ENABLE_ENV_SYNC_SYSTEM_PROPERTY = 'Enable_Env_Sync_Back_Promote';

    @TestVisible
    private static String mockCacheProvisioningResponse;
    @TestVisible
    private static String mockCacheStatusResponse;

    @AuraEnabled(cacheable=true)
    public static Boolean vlocityStatus(Id pipelineId) {
        PipelineSettings.VlocitySettingStatusRequest request = new PipelineSettings.VlocitySettingStatusRequest();
        request.pipelineId = pipelineId;

        PipelineSettings.VlocitySettingStatusResult result = PipelineSettings.VlocitySetting.status(request);
        return result.status;
    }

    @AuraEnabled
    public static Boolean enableVlocity(Id pipelineId) {
        PipelineSettings.EnableVlocitySettingRequest request = new PipelineSettings.EnableVlocitySettingRequest();
        request.pipelineId = pipelineId;

        PipelineSettings.EnableVlocitySettingResult result = PipelineSettings.VlocitySetting.enable(request);
        return result.status;
    }

    @AuraEnabled
    public static Boolean disableVlocity(Id pipelineId) {
        PipelineSettings.DisableVlocitySettingRequest request = new PipelineSettings.DisableVlocitySettingRequest();
        request.pipelineId = pipelineId;

        PipelineSettings.DisableVlocitySettingResult result = PipelineSettings.VlocitySetting.disable(request);
        return result.status;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean environmentSyncStatus(Id pipelineId) {
        return isEnvironmentSyncEnabled(pipelineId);
    }

    @AuraEnabled
    public static Boolean enableEnvironmentSync(Id pipelineId) {
        if (!isEnvironmentSyncEnabled(pipelineId)) {
            insertEnvironmentSyncSystemProperty(pipelineId);
        }
        return true;
    }

    @AuraEnabled
    public static Boolean disableEnvironmentSync(Id pipelineId) {
        if (isEnvironmentSyncEnabled(pipelineId)) {
            deleteEnvironmentSyncSystemProperty(pipelineId);
        }
        return true;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isBackPromotionEnvSyncFeatureEnabled() {
        return !Test.isRunningTest() && copado.Feature.isBackPromotionEnvSyncEnabled();
    }

    @AuraEnabled
    public static Map<String, Object> enableMetaCache(Id pipelineId) {
        try {
            Map<String, String> request = new Map<String, String>{ 'pipelineId' => pipelineId };

            HttpResponse response = !Test.isRunningTest()
                ? copado.MetaCacheAPIProxy.callMetaCacheService('api/v4/cache-pipeline/', 'POST', JSON.serialize(request))
                : getMockCacheProvisioningResponse();

            if (response == null) {
                throw new AuraHandledException(System.Label.Server_No_Response_Error_Message);
            }

            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.put('statusCode', response.getStatusCode());
            return result;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static Map<String, Object> disableMetaCache(Id pipelineId) {
        try {
            Map<String, String> request = new Map<String, String>{ 'pipelineId' => pipelineId };

            HttpResponse response = !Test.isRunningTest()
                ? copado.MetaCacheAPIProxy.callMetaCacheService('api/v4/cache-pipeline/' + pipelineId, 'DELETE', '')
                : getMockCacheProvisioningResponse();

            if (response == null) {
                throw new AuraHandledException(System.Label.Server_No_Response_Error_Message);
            }

            if (response.getStatusCode() == 200) {
                disableNewCommitExp(pipelineId);
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('statusCode', response.getStatusCode());
            return result;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static Map<String, Object> checkMetaCacheStatus(Id pipelineId) {
        try {
            Map<String, String> request = new Map<String, String>{ 'pipelineId' => pipelineId };

            HttpResponse response = !Test.isRunningTest()
                ? copado.MetaCacheAPIProxy.callMetaCacheService('api/v4/cache-status/' + pipelineId, 'GET', '')
                : getMockCacheStatusResponse();

            if (response == null) {
                throw new AuraHandledException(System.Label.Server_No_Response_Error_Message);
            }

            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.put('statusCode', response.getStatusCode());
            return result;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static Map<Id, copado__Environment__c> getOrgsFromCacheStatusResponse(Id pipelineId, List<Id> copadoOrgs) {
        Map<Id, copado__Environment__c> result = new Map<Id, copado__Environment__c>();
        if (copadoOrgs.isEmpty() || pipelineId == null) {
            return result;
        }

        Set<Id> copadoOrgIds = new Set<Id>(copadoOrgs);

        for (
            copado__Deployment_Flow_Step__c pipelineConnection : new PipelineConnectionsSelector()
                .byPipelineIdAndCopadoOrgId(pipelineId, copadoOrgIds)
        ) {
            Id sourceEnvironmentsCopadoOrgId = pipelineConnection.copado__Source_Environment__r.copado__Org_ID__c;
            Id destinationEnvironmentCopadoOrgId = pipelineConnection.copado__Destination_Environment__r.copado__Org_ID__c;

            if (copadoOrgIds.contains(sourceEnvironmentsCopadoOrgId) && pipelineConnection.copado__Deployment_Flow__c == pipelineId) {
                copado__Environment__c environment = new copado__Environment__c(
                    Id = pipelineConnection.copado__Source_Environment__c,
                    Name = pipelineConnection.copado__Source_Environment__r.Name
                );
                result.put(sourceEnvironmentsCopadoOrgId, environment);
            }

            if (copadoOrgIds.contains(destinationEnvironmentCopadoOrgId) && pipelineConnection.copado__Deployment_Flow__c == pipelineId) {
                copado__Environment__c environment = new copado__Environment__c(
                    Id = pipelineConnection.copado__Destination_Environment__c,
                    Name = pipelineConnection.copado__Destination_Environment__r.Name
                );
                result.put(destinationEnvironmentCopadoOrgId, environment);
            }
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static LicenseStatusWrapper checkCopadoAndMetaCachePermissions() {
        try {
            Boolean hasFeatureMetaCacheEnabled = checkFeatureMetaCacheEnablement();
            Boolean hasCopadoAdminLicense = checkCopadoAdminLicense();

            return new LicenseStatusWrapper(hasFeatureMetaCacheEnabled, hasCopadoAdminLicense);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=true)
    public static EnvironmentData validateAuthenticatedEnvironment(String environmentId) {
        try {
            EnvironmentData result = new EnvironmentData();
            List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(environmentId);
            if (credentials.isEmpty()) {
                return result;
            }
            copado.ValidateOrgAction.Request request = new copado.ValidateOrgAction.Request();
            request.orgId = credentials[0].Id;

            result.isValidOrg = false;
            result.isValidOrg = String.isBlank(credentials[0].copado__SFDC_Org_ID__c)
                ? false
                : copado.ValidateOrgAction.execute(new List<copado.ValidateOrgAction.Request>{ request })?.get(0).isValidOrg;

            result.credentialName = credentials[0].copado__Username__c;
            result.credentialId = credentials[0].Id;
            return result;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<EnvironmentData> getEnvironmentNames(List<Id> environmentIds) {
        try {
            List<EnvironmentData> result = new List<EnvironmentData>();
            Set<Id> environmentIdSet = new Set<Id>(environmentIds);
            List<copado__Environment__c> environments = new EnvironmentsSelector().byIds(environmentIdSet);

            for (copado__Environment__c environment : environments) {
                EnvironmentData envData = new EnvironmentData();
                envData.environmentName = environment.Name;
                envData.environmentId = environment.Id;
                result.add(envData);
            }
            return result;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=true)
    public static PipelineSettings.NewCommitExpSettingStatusResult newCommitExperienceStatus(Id pipelineId) {
        PipelineSettings.NewCommitExpSettingStatusRequest request = new PipelineSettings.NewCommitExpSettingStatusRequest();
        request.pipelineId = pipelineId;
        return PipelineSettings.NewCommitExpSetting.status(request);
    }

    @AuraEnabled
    public static Boolean enableNewCommitExp(Id pipelineId) {
        PipelineSettings.EnableNewCommitExpSettingRequest request = new PipelineSettings.EnableNewCommitExpSettingRequest();
        request.pipelineId = pipelineId;
        PipelineSettings.EnableNewCommitExpSettingResult result = PipelineSettings.NewCommitExpSetting.enable(request);
        return result.status;
    }

    @AuraEnabled
    public static Boolean disableNewCommitExp(Id pipelineId) {
        copado.DevOpsUI.DisableNewCommitExpSettingRequest request = new copado.DevOpsUI.DisableNewCommitExpSettingRequest();
        request.pipelineId = pipelineId;

        copado.DevOpsUI.DisableNewCommitExpSettingResult result = copado.DevOpsUI.CommitExperience.disable(request);
        return result.status;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isNewCommitExperienceFeatureEnabled() {
        return Test.isRunningTest() || copado.Feature.isFeatureEnabled('NewCommitExperienceEnabled');
    }

    private static Boolean checkFeatureMetaCacheEnablement() {
        Boolean hasFeatureMetaCacheEnabled = Test.isRunningTest() || FeatureManagement.checkPackageIntegerValue(COPADO_METACACHE_ENABLED) == 1;

        return hasFeatureMetaCacheEnabled;
    }

    private static Boolean checkCopadoAdminLicense() {
        Id currentUserId = UserInfo.getUserId();
        CheckLicense checker = new CheckLicense(currentUserId);
        Boolean hasCopadoAdminLicense = Test.isRunningTest() || checker.has(COPADO_ADMIN);

        return hasCopadoAdminLicense;
    }

    private static Boolean isEnvironmentSyncEnabled(Id pipelineId) {
        List<copado__System_Property__c> systemProperties = new SystemPropertiesSelector()
            .byPipelineAndCreatedDateForSFDX(new Set<Id>{ pipelineId }, ENABLE_ENV_SYNC_SYSTEM_PROPERTY);
        return !systemProperties.isEmpty() && systemProperties[0]?.copado__Value__c?.toLowerCase() == 'true';
    }

    private static void insertEnvironmentSyncSystemProperty(Id pipelineId) {
        copado__System_Property__c systemProperty = new copado__System_Property__c();
        systemProperty.copado__Pipeline__c = pipelineId;
        systemProperty.Name = ENABLE_ENV_SYNC_SYSTEM_PROPERTY;
        systemProperty.copado__API_Name__c = ENABLE_ENV_SYNC_SYSTEM_PROPERTY;
        systemProperty.copado__Value__c = 'true';

        Utilities.performDML(new List<copado__System_Property__c>{ systemProperty }, 'insert', AccessLevel.USER_MODE);
    }

    private static void deleteEnvironmentSyncSystemProperty(Id pipelineId) {
        List<copado__System_Property__c> systemProperties = new SystemPropertiesSelector()
            .byPipelineAndCreatedDateForSFDX(new Set<Id>{ pipelineId }, ENABLE_ENV_SYNC_SYSTEM_PROPERTY);

        if (!systemProperties.isEmpty()) {
            Utilities.performDML(systemProperties, 'delete', AccessLevel.USER_MODE);
        }
    }

    // MOCK

    private static HttpResponse getMockCacheStatusResponse() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody(mockCacheStatusResponse);
        return response;
    }

    private static HttpResponse getMockCacheProvisioningResponse() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody(mockCacheProvisioningResponse);
        return response;
    }

    // WRAPPER

    public class LicenseStatusWrapper {
        @AuraEnabled
        public Boolean hasFeatureMetaCacheEnabled { get; set; }
        @AuraEnabled
        public Boolean hasCopadoAdminLicense { get; set; }

        public LicenseStatusWrapper(Boolean hasFeatureMetaCacheEnabled, Boolean hasCopadoAdminLicense) {
            this.hasFeatureMetaCacheEnabled = hasFeatureMetaCacheEnabled;
            this.hasCopadoAdminLicense = hasCopadoAdminLicense;
        }
    }

    public class EnvironmentData {
        @AuraEnabled
        public Boolean isValidOrg;
        @AuraEnabled
        public String credentialName;
        @AuraEnabled
        public String credentialId;
        @AuraEnabled
        public String environmentName;
        @AuraEnabled
        public String environmentId;
    }
}