@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class UserStoryDataDevops {
    private static final String ENABLE_DATA_DEPLOY_DEVOPS = 'enable_data_deploy_devops';
    private static final String RETRIEVED_DATA_FILE_NAME = 'records_with_related_dependencies.json';
    private static final String DATA_RETRIEVE_TEMPLATE = 'SFDX_Data_Devops_Retrieve_1';
    private static final String MASTERLIST_RETRIEVE_TEMPLATE = 'SFDX_Data_Devops_Masterlist_Retrieve_1';
    private static final String DATA_DEVOPS_PERMISSION = 'copado__Enable_Data_Deploy_DevOps_User';
    private static final String DATA_CONFIG_FILE = 'DataDeployDevOpsConfiguration.json';

    @AuraEnabled(cacheable=true)
    public static Response checkDataDevopsEnablement(String userStoryId) {
        try {
            Id pipelineId = getPipelineIdForUserStory(userStoryId);
            if (String.isBlank(pipelineId)) {
                return new Response(null, false, false, false);
            }

            Boolean propertyEnabled = isDataDeployDevopsEnabledForPipeline(pipelineId);
            Boolean permissionEnabled = FeatureManagement.checkPermission(DATA_DEVOPS_PERMISSION);
            LicenseInfo licenses = getLicenseInfo();

            return new Response(null, licenses.orgLicensed && propertyEnabled, licenses.userLicensed, permissionEnabled);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getMasterListFromDocument(Id linkedEntityId) {
        try {
            List<ContentDocumentLink> contentDocumentLinks = new ContentDocumentLinksSelector()
                .contentDocumentByLinkedEntityIdAndTitle(new Set<Id>{ linkedEntityId }, new Set<String>{ DATA_CONFIG_FILE });

            if (contentDocumentLinks.isEmpty()) {
                return null;
            }

            return [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE Id = :contentDocumentLinks[0].ContentDocument.LatestPublishedVersionId
                    WITH USER_MODE
                    LIMIT 1
                ]
                .VersionData.toString();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Response getMasterListFromBackend(Id credentialId, Id pipelineId) {
        if (String.isBlank(pipelineId)) {
            throw new AuraHandledException('Pipeline Id is empty');
        }

        if (String.isBlank(credentialId)) {
            throw new AuraHandledException('Credential Id is empty');
        }

        try {
            copado__Org__c credential = getCredential(credentialId);
            Response jobAlreadyInProgress = checkMasterListRetrieveAlreadyInProgress(credential.copado__Environment__c);
            if (jobAlreadyInProgress != null) {
                return jobAlreadyInProgress;
            }
            copado.CreateExecution.Request request = new copado.CreateExecution.Request();
            request.templateName = MASTERLIST_RETRIEVE_TEMPLATE;
            request.sourceId = credential.copado__Environment__c;
            request.runAfterInstantiation = true;
            request.dataJson = JSON.serialize(new Map<String, Object>{ 'pipelineId' => pipelineId });

            return new Response(copado.CreateExecution.execute(new List<copado.CreateExecution.request>{ request })[0].Id, null, null, null);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Response executeDataRetrieve(Id userStoryId, Id credentialId, String payload) {
        try {
            deleteOldFiles(userStoryId);
            copado__Org__c credential = getCredential(credentialId);

            copado.CreateExecution.Request request = new copado.CreateExecution.Request();
            request.templateName = DATA_RETRIEVE_TEMPLATE;
            request.sourceId = credential.copado__Environment__c;
            request.dataJson = new DataJson(userStoryId, payload).toJson();
            request.runAfterInstantiation = true;

            return new Response(copado.CreateExecution.execute(new List<copado.CreateExecution.request>{ request })[0].Id, null, null, null);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static copado__Result__c checkDataJobExecutionStatus(Id copadoJobId) {
        try {
            return [
                SELECT copado__Status__c, copado__Error_Message__c, copado__Progress_Status__c, copado__Result_Data__c
                FROM copado__Result__c
                WHERE copado__JobStep__r.copado__JobExecution__c = :copadoJobId
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static string getDataDevopsFileByName(String linkedEntityId, Id copadoJobId) {
        try {
            String fullFileName = getFullFileNameFromJobResult(copadoJobId);

            String fileBody = findFileInAttachments(linkedEntityId, fullFileName);
            if (String.isNotBlank(fileBody)) {
                return fileBody;
            }

            fileBody = findFileInContentVersions(linkedEntityId, fullFileName);
            if (String.isNotBlank(fileBody)) {
                return fileBody;
            }

            throw new ApplicationException(Label.File_Not_Found);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static void deleteOldFiles(Id userStoryId) {
        List<Attachment> attachments = [
            SELECT Id
            FROM Attachment
            WHERE ParentId = :userStoryId AND Name LIKE :'%_' + RETRIEVED_DATA_FILE_NAME
            WITH USER_MODE
        ];

        if (!attachments.isEmpty()) {
            // Check for delete permission before DML
            if (!Schema.sObjectType.Attachment.isDeletable()) {
                throw new AuraHandledException('Insufficient permissions to delete Attachment records.');
            }
            new Utilities.DeleteSObjectWithoutSharing().execute(attachments);
        } else {
            DeleteSalesforceFiles.deleteContentDocuments(new List<Id>{ userStoryId }, new List<String>{ '%_' + RETRIEVED_DATA_FILE_NAME });
        }
    }

    // HELPERS

    private static LicenseInfo getLicenseInfo() {
        copado.GlobalAPI copadoAPI = new copado.GlobalAPI();
        copado.GlobalAPI.CopadoLicenses orgLicenses = copadoAPI.getLicenseInformation();
        copado.GlobalAPI.UserLicense userLicense = copadoAPI.copadoLicensesByUser(UserInfo.getUserId());

        return new LicenseInfo(orgLicenses.hasDevopsLicenseEnabled > 0, userLicense.isADDEnabled);
    }

    private static copado__Org__c getCredential(Id credentialId) {
        List<copado__Org__c> credentials = [
            SELECT copado__Environment__c
            FROM copado__Org__c
            WHERE Id = :credentialId
            WITH USER_MODE
            LIMIT 1
        ];

        if (credentials.isEmpty()) {
            throw new ApplicationException(Label.Credential_Not_Found);
        }

        return credentials[0];
    }

    private static String getFullFileNameFromJobResult(Id copadoJobId) {
        copado__Result__c jobResult = [
            SELECT copado__Result_Data__c
            FROM copado__Result__c
            WHERE copado__JobStep__r.copado__JobExecution__c = :copadoJobId
            WITH USER_MODE
            LIMIT 1
        ];

        ResultData resultData = (ResultData) JSON.deserialize(jobResult.copado__Result_Data__c, ResultData.class);
        return resultData.deploymentId + '_' + RETRIEVED_DATA_FILE_NAME;
    }

    private static String findFileInAttachments(String linkedEntityId, String fullFileName) {
        List<Attachment> attachments = new AttachmentsSelector()
            .byParentIdsAndNames(new Set<Id>{ linkedEntityId }, new Set<String>{ fullFileName }, 1);
        return !attachments.isEmpty() ? attachments[0].Body.toString() : null;
    }

    private static String findFileInContentVersions(String linkedEntityId, String fullFileName) {
        List<ContentDocumentLink> contentDocumentLinks = new ContentDocumentLinksSelector()
            .contentDocumentByLinkedEntityIdAndTitle(new Set<Id>{ linkedEntityId }, new Set<String>{ fullFileName });

        if (!contentDocumentLinks.isEmpty()) {
            return [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE Id = :contentDocumentLinks[0].ContentDocument.LatestPublishedVersionId
                    WITH USER_MODE
                    LIMIT 1
                ]
                .VersionData.toString();
        }
        return null;
    }

    private static Id getPipelineIdForUserStory(String userStoryId) {
        return [
                SELECT copado__Project__r.copado__Deployment_Flow__c
                FROM copado__User_Story__c
                WHERE Id = :userStoryId
                WITH USER_MODE
                LIMIT 1
            ]
            ?.copado__Project__r
            ?.copado__Deployment_Flow__c;
    }

    private static Boolean isDataDeployDevopsEnabledForPipeline(Id pipelineId) {
        List<copado__System_Property__c> properties = [
            SELECT copado__Value__c
            FROM copado__System_Property__c
            WHERE copado__Pipeline__c = :pipelineId AND copado__API_Name__c = :ENABLE_DATA_DEPLOY_DEVOPS
            WITH USER_MODE
            LIMIT 1
        ];
        return !properties.isEmpty() && properties[0]?.copado__Value__c?.toLowerCase() == 'true';
    }

    private static Response checkMasterListRetrieveAlreadyInProgress(Id sourceId) {
        Response response;
        List<copado__JobExecution__c> jobExecutions = new JobExecutionsSelector()
            .bySourceTemplateAndStatus(
                new Set<Id>{ sourceId },
                new Set<String>{ MASTERLIST_RETRIEVE_TEMPLATE },
                new Set<String>{ 'In Progress', 'Not Started' }
            );
        if (!jobExecutions.isEmpty()) {
            response = new Response(jobExecutions[0].Id, null, null, null);
        }
        return response;
    }

    @TestVisible
    private class Response {
        @AuraEnabled
        public String copadoJobId;
        @AuraEnabled
        public Boolean tabEnabled;
        @AuraEnabled
        public Boolean licenseEnabled;
        @AuraEnabled
        public Boolean permissionEnabled;

        @SuppressWarnings('PMD.ExcessiveParameterList')
        private Response(String copadoJobId, Boolean tabEnabled, Boolean licenseEnabled, Boolean permissionEnabled) {
            this.copadoJobId = copadoJobId;
            this.tabEnabled = tabEnabled;
            this.licenseEnabled = licenseEnabled;
            this.permissionEnabled = permissionEnabled;
        }
    }

    private class LicenseInfo {
        public Boolean orgLicensed;
        public Boolean userLicensed;

        public LicenseInfo(Boolean orgLicensed, Boolean userLicensed) {
            this.orgLicensed = orgLicensed;
            this.userLicensed = userLicensed;
        }
    }

    private class DataJson {
        private Id userStoryId;
        private String payload;

        private DataJson(Id userStoryId, String payload) {
            this.userStoryId = userStoryId;
            this.payload = payload;
        }

        private String toJson() {
            return JSON.serialize(this);
        }
    }

    private class ResultData {
        private String deploymentId;
        private String sourceSessionUrl;
    }
}