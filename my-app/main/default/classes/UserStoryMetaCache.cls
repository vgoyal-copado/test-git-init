@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class UserStoryMetaCache {
    private static final String SEARCH_MTDT_DEPENDENCIES_ENDPOINT = 'api/v4/search-dependencies/';
    private static final String REFRESH_DEPENDENCIES_ENDPOINT = 'api/v4/refresh/';
    private static final String POST = 'POST';
    private static final String GET = 'GET';
    private static final Integer SUCCESS_STATUS_CODE = 200;
    private static final String COPADO_METACACHE_ENABLED = 'copado__MetaCache_Enabled';
    private static final String ACTIVATED = 'activated';
    private static final String DEACTIVATED = 'deactivated';
    private static final String PROVISIONED = 'provisioned';

    @TestVisible
    private static String mockDependenciesResponse;
    @TestVisible
    private static String mockCacheStatusResponse;
    @TestVisible
	private static Integer mockDependenciesStatusCode = 200;

    @AuraEnabled
    public static String getDependencies(Id credentialId, Id userStoryId, String retrieveMode, List<Metadata> selectedMetadata) {
        try {
            validateInputs(userStoryId, retrieveMode, selectedMetadata);

            OrgDetails orgDetails = getOrgDetails(userStoryId);
            validateOrgDetails(orgDetails);

            String requestBody = buildRequestBody(orgDetails, selectedMetadata, retrieveMode);
            return executeRequest(SEARCH_MTDT_DEPENDENCIES_ENDPOINT, POST, requestBody);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static String getRefreshStatus(String eventId) {
        try {
            if (String.isBlank(eventId)) {
                throw new ApplicationException(String.format(Label.MissingRequiredParameters, new List<String>{ System.label.Event_Id }));
            }

            return executeRequest(REFRESH_DEPENDENCIES_ENDPOINT + eventId, GET, '');
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static String refreshDependencies(RefreshDependencyWrapper request) {
        try {
            if(request == null) {
                return null;
            }

            Id userStoryId = request?.userStoryId;

            validateRefreshInputs(request);
            OrgDetails orgDetails = getOrgDetails(userStoryId);
            validateOrgDetails(orgDetails);
            String requestBody = buildRefreshRequestBody(orgDetails, request);
            String responseBody = executeRequest(REFRESH_DEPENDENCIES_ENDPOINT, POST, requestBody);

            Response result = (Response) JSON.deserialize(responseBody, Response.class);
            return (String) result?.eventId;
            
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static String isDependencyTabEnabled(Id pipelineId) {
        try {
            Boolean hasFeatureMetaCacheEnabled = FeatureManagement.checkPackageIntegerValue(COPADO_METACACHE_ENABLED) == 1;

            if (!hasFeatureMetaCacheEnabled || Test.isRunningTest()) {
                return DEACTIVATED;
            }

            Map<String, Object> result = checkMetaCacheStatus(pipelineId);
            
            return getValidatedMetaCacheStatus(result);        
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }
    
    @TestVisible
    private static String getValidatedMetaCacheStatus(Map<String, Object> result) {
        String status = getPipelineStatus(result)?.toLowerCase();
        Integer statusCode = Integer.valueOf(result.get('statusCode'));
    
        if (statusCode == 200 && (status == ACTIVATED || status == DEACTIVATED || status == PROVISIONED)) {
            return status;
        }
        return DEACTIVATED;          
    }

    private static void validateInputs(Id userStoryId, String retrieveMode, List<Metadata> selectedMetadata) {
        List<String> errors = new List<String>();

        if (String.isBlank(userStoryId)) {
            errors.add(System.Label.User_Story_Id_Required_Error_Message);
        }
        if (String.isBlank(retrieveMode)) {
            errors.add(System.Label.Retrieve_Mode_Required_Error_Message);
        }
        if (selectedMetadata == null || selectedMetadata.isEmpty()) {
            errors.add(System.Label.Metadata_Required_Error_Message);
        }

        if (!errors.isEmpty()) {
            throw new ApplicationException(String.join(errors, '. '));
        }
    }

    private static OrgDetails getOrgDetails(Id userStoryId) {
        OrgDetails details = new OrgDetails();

        List<copado__User_Story__c> userStories = [
            SELECT copado__Environment__r.copado__Org_ID__c, copado__Project__r.copado__Deployment_Flow__c,
                    copado__Release__r.copado__Project__r.copado__Deployment_Flow__c
            FROM copado__User_Story__c
            WHERE Id = :userStoryId
            WITH USER_MODE
            LIMIT 1
        ];

        if(userStories.isEmpty()) {
            throw new ApplicationException(System.Label.User_Story_Not_Found_Error_Message);
        }

        if (userStories[0].copado__Environment__r == null) {
            throw new ApplicationException(System.Label.Credential_Not_Defined);
        }

        copado__Deployment_Flow__c pipeline = getPipelineFromUserStory(userStories[0]);
        Id orgId = userStories[0]?.copado__Environment__r?.copado__Org_ID__c;
        
        details.pipelineId = pipeline != null ? Id.valueOf(pipeline.Id) : null;
        details.sourceOrgId = orgId != null ? Id.valueOf(orgId) : null;
        
        List<copado__Deployment_Flow_Step__c> connections = [
            SELECT copado__Destination_Environment__r.copado__Org_ID__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Deployment_Flow__c = :details.pipelineId AND copado__Source_Environment__c = :userStories[0].copado__Environment__c
            WITH USER_MODE
            LIMIT 1
        ];

        details.destinationOrgId = 
            !connections.isEmpty() && connections[0].copado__Destination_Environment__r != null
            ? Id.valueOf(connections[0].copado__Destination_Environment__r.copado__Org_ID__c)
            : null;
        return details;
    }

    @TestVisible
    private static copado__Deployment_Flow__c getPipelineFromUserStory(copado__User_Story__c userStory) {
        Id pipelineId = String.isNotBlank(userStory.copado__Project__r.copado__Deployment_Flow__c)
            ? userStory.copado__Project__r.copado__Deployment_Flow__c
            : userStory?.copado__Release__r?.copado__Project__r?.copado__Deployment_Flow__c;
        return pipelineId != null ? new PipelinesSelector().byId(new Set<Id>{ pipelineId })[0] : null;
    }

    private static void validateOrgDetails(OrgDetails details) {
        List<String> errors = new List<String>();

        if (details?.pipelineId == null || details?.sourceOrgId == null) {
            errors.add(System.Label.Pipeline_And_Source_Organization_Required_Error_Message);
        }

        if (details?.destinationOrgId == null) {
            errors.add(System.Label.Destination_Org_Required_Error_Message);
        }

        if (!errors.isEmpty()) {
            throw new ApplicationException(String.join(errors, '. '));
        }
    }

    private static String buildRequestBody(OrgDetails orgDetails, List<Metadata> selectedMetadata, String retrieveMode) {
            Map<String, Object> requestMap = new Map<String, Object>{
                'pipelineId' => orgDetails.pipelineId,
                'metadataSelections' => buildMetadataSelections(selectedMetadata),
                'compareOptions' => new Map<String, String>{
                    'retrieveMode' => retrieveMode,
                    'sourceOrgId' => orgDetails.sourceOrgId,
                    'targetOrgId' => orgDetails.destinationOrgId
                }
            };

            return JSON.serialize(requestMap);
    }

    private static List<Map<String, String>> buildMetadataSelections(List<Metadata> selectedMetadata) {
        List<Map<String, String>> selections = new List<Map<String, String>>();

        for (Metadata metadata : selectedMetadata) {
            if (String.isNotBlank(metadata.type) && String.isNotBlank(metadata.name)) {
                selections.add(new Map<String, String>{ 'type' => metadata.type, 'name' => metadata.name });
            }
        }

        return selections;
    }

    private static String buildRefreshRequestBody(OrgDetails orgDetails, RefreshDependencyWrapper request) {

            Map<String, Object> requestMap = new Map<String, Object>{
                'sourceOrgId' => orgDetails.sourceOrgId,
                'targetOrgId' => orgDetails.destinationOrgId,
                'pipelineId' => request?.pipelineId,
                'metadata' => new Map<String, Object>{
                    'refreshMode' => request?.refreshMode,
                    'selected' => buildMetadataSelections(request?.selectedMetadata)
                },
                'gitFiles' => new List<Object>()
            };

            return JSON.serialize(requestMap);
    }

    private static String executeRequest(String endpoint, String method, String requestBody) {
            HttpResponse response = !Test.isRunningTest()
                ? copado.MetaCacheAPIProxy.callMetaCacheService(endpoint, method, requestBody)
                : getMockDependenciesResponse();
            
            if (response == null) {
                throw new ApplicationException(System.Label.Server_No_Response_Error_Message);
            }

            String responseBody = response.getBody();
            if (response?.getStatusCode() == SUCCESS_STATUS_CODE) {
                return responseBody;
            } else {
            Response errorDetails = (Response) JSON.deserialize(responseBody, Response.class);
            String errorMessage =
                System.Label.Event_Id + ': ' + errorDetails.eventId + '. ' +
                System.Label.Status_Code + ': ' + response?.getStatusCode() + '. ' +
                System.Label.Error + ': ' + errorDetails.message;
            throw new ApplicationException(errorMessage);
        }
    }

    @TestVisible
    private static Map<String, Object> checkMetaCacheStatus(Id pipelineId) {
            Map<String, String> requestBody = new Map<String, String>{ 'pipelineId' => pipelineId };
            String request = JSON.serialize(requestBody);

            HttpResponse response = !Test.isRunningTest()
                ? copado.MetaCacheAPIProxy.callMetaCacheService('api/v4/cache-status/' + pipelineId, GET, request)
                : getMockCacheStatusResponse();

            if (response == null) {
                throw new ApplicationException(System.Label.Server_No_Response_Error_Message);
            }

            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.put('statusCode', response.getStatusCode());
            return result;
    }

    // MOCK

    private static HttpResponse getMockCacheStatusResponse() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(mockDependenciesStatusCode);
            response.setBody(mockCacheStatusResponse);
            return response;
    }
    
    private static HttpResponse getMockDependenciesResponse() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(mockDependenciesStatusCode);
            response.setBody(mockDependenciesResponse);
            return response;
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

    private static void validateRefreshInputs(RefreshDependencyWrapper request) {
        List<String> errors = new List<String>();

        Id userStoryId = request?.userStoryId;
        Id credentialId = request?.credentialId;
        Id pipelineId = request?.pipelineId;
        String refreshMode = request?.refreshMode;
        List<Metadata> selectedMetadata = request?.selectedMetadata;

        if (String.isBlank(pipelineId) || String.isBlank(credentialId)) {
            errors.add(System.Label.Pipeline_And_Source_Organization_Required_Error_Message);
        }
        if (String.isBlank(userStoryId)) {
            errors.add(System.Label.USER_STORY_REQUIRED);
        }
        if (String.isBlank(refreshMode)) {
            errors.add(System.Label.Refresh_Mode_Required_Error_Message);
        }
        if (selectedMetadata == null || selectedMetadata.isEmpty()) {
            errors.add(System.Label.Metadata_Required_Error_Message);
        }

        if (!errors.isEmpty()) {
            throw new ApplicationException(String.join(errors, '. '));
        }
    }
    
    // WRAPPER

    private class OrgDetails {
        Id pipelineId;
        Id sourceOrgId;
        Id destinationOrgId;
    }

    public class Metadata {
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String type { get; set; }
    }

    private class Response {
        String message;
        String eventId;
    }
}