@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class SelectiveCommitSetup {
    private static final String SFDX_SELECTIVE_COMMIT_SETUP = 'SFDX_Selective_Commit_Setup_1';
    private static final String SFDX_BUNDLED_METADATA_SELECTIVE_COMMIT_SETUP = 'SFDX_Bundled_Metadata_Selective_Commit_Setup_1';
    private static final Set<String> BUNDLED_METADATA = new Set<String>{
        'auradefinitionbundle',
        'experiencebundle',
        'lightningcomponentbundle',
        'wavetemplatebundle'
    };
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION = 'cmcSf_SelectionsForBundledMetadata_session';
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT = 'cmcSf_SelectionsForBundledMetadata_commit';
    private static final Set<String> LAYOUTS_FLEXIPAGES = new Set<String>{ 'layout', 'flexipage' };
    private static final String SOURCE_SUFFIX = '_source';
    private static final String BASE_SUFFIX = '_base';
    private static final String FEATURE_SUFFIX = '_feature';

    // PUBLIC

    @AuraEnabled
    public static Id execute(SelectiveCommitSetupPayload payload, Id pipelineId, Id sourceId) {
        try {
            String templateName = getTemplateName(payload.metadataTypeAndName);
            List<copado__JobExecution__c> jobExecutions = getJobExecutionsWithSameRequestInProgress(templateName, pipelineId, sourceId, payload);
            if (jobExecutions?.size() != 0) {
                return jobExecutions[0].Id;
            }
            CmcSfJobExecution jobExecution = new CmcSfJobExecution()
                .templateName(templateName)
                .pipelineId(pipelineId)
                .sourceId(sourceId)
                .dataJson(JSON.serializePretty(payload))
                .enablePreFetch(true)
                .run();
            return jobExecution.recordId;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static List<copado__JobExecution__c> getJobExecutionsWithSameRequestInProgress(
        String templateName,
        Id pipelineId,
        Id sourceId,
        SelectiveCommitSetupPayload payload
    ) {
        List<copado__JobExecution__c> result = new List<copado__JobExecution__c>();
        List<copado__JobExecution__c> jobExecutions = new JobExecutionsSelector()
            .byTemplateAndPipelineAndSourceAndStatus(templateName, pipelineId, sourceId, 'In Progress');
        for (copado__JobExecution__c jobExecution : jobExecutions) {
            if (hasSamePayload(payload, jobExecution.copado__DataJson__c)) {
                result.add(jobExecution);
            }
        }
        return result;
    }

    private static Boolean hasSamePayload(SelectiveCommitSetupPayload requestPayload, String inProgressJobExecutionPayload) {
        SelectiveCommitSetupPayload jobExecutionPayload = (SelectiveCommitSetupPayload) JSON.deserialize(
            inProgressJobExecutionPayload,
            SelectiveCommitSetupPayload.class
        );
        return (jobExecutionPayload.baseBranch?.equals(requestPayload.baseBranch) &&
        jobExecutionPayload.destinationBranch?.equals(requestPayload.destinationBranch) &&
        jobExecutionPayload.metadataTypeAndName?.equals(requestPayload.metadataTypeAndName) &&
        jobExecutionPayload.baseBranch?.equals(requestPayload.baseBranch) &&
        jobExecutionPayload.userStoryId?.equals(requestPayload.userStoryId));
    }

    @AuraEnabled(cacheable=true)
    public static String getDestinationBranchForUserStory(Id pipelineId, Id sourceEnvironmentId) {
        try {
            List<copado__Deployment_Flow_Step__c> pipelineConnections = new PipelineConnectionsSelector()
                .byPipelineAndSourceEnvironment(new Set<Id>{ pipelineId }, new Set<Id>{ sourceEnvironmentId });
            if (pipelineConnections.isEmpty() || String.isBlank(pipelineConnections[0].copado__Destination_Branch__c)) {
                throw new ApplicationException(Label.Pipeline_Connection_does_not_exists_or_Destination_Branch_is_empty);
            }
            return pipelineConnections[0].copado__Destination_Branch__c;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static JobExecutionDetails getJobExecutionDetails(Id jobExecutionId) {
        try {
            List<copado__JobExecution__c> jobExecutions = new JobExecutionsSelector().byIds(new Set<Id>{ jobExecutionId });
            return new JobExecutionDetails(jobExecutions[0].Name, jobExecutions[0].copado__Status__c, jobExecutions[0].Id);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Id> getContentVersionIdsForBundleFile(SelectiveCommitBundledMetadataRequest request) {
        try {
            List<String> titles = getTitlesOfFiles(request.filePrefix, request.filePathHash);
            return getEditorContentVersionIds(request.userStoryId, titles);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static List<Id> getEditorContentVersionIds(Id userStoryId, List<String> titles) {
        try {
            Map<Id, ContentVersion> metadataContentVersionsOnUSByIds = getLatestContentVersions(userStoryId, titles);
            return new List<Id>(metadataContentVersionsOnUSByIds.keySet());
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    private static Map<Id, ContentVersion> getLatestContentVersions(Id userStoryId, List<String> titles) {
        try {
            List<ContentDocumentLink> metadataLinksOnUserStory = new ContentDocumentLinksSelector()
                .byLinkedEntityIdAndTitles(new Set<Id>{ userStoryId }, new Set<String>(titles));

            List<ContentDocumentLink> latestMetadataLinksOnUserStory = getLatestMetadataLinksOnUserStory(metadataLinksOnUserStory);
            Set<Id> metadataDocumentIdsOnUserStory = new Set<Id>();
            for (ContentDocumentLink metadataLinkOnUserStory : latestMetadataLinksOnUserStory) {
                metadataDocumentIdsOnUserStory.add(metadataLinkOnUserStory.ContentDocumentId);
            }
            Map<Id, ContentVersion> metadataContentVersionsOnUSByIds = new Map<Id, ContentVersion>(
                new ContentVersionsSelector().byContentDocumentIdWithLatest(metadataDocumentIdsOnUserStory)
            );
            return metadataContentVersionsOnUSByIds;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static Id saveSelectionsForBundledMetadata(Id userStoryId, List<String> selectedFilePaths, String metadataTypeAndName) {
        try {
            Map<String, List<String>> selectionsByMetadataTypeAndName = new Map<String, List<String>>();
            Map<Id, ContentVersion> previousSelectionsByMetadataTypeAndName = getLatestContentVersions(
                userStoryId,
                new List<String>{ CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION }
            );

            if (!(previousSelectionsByMetadataTypeAndName.isEmpty())) {
                ContentVersion previousSelections = previousSelectionsByMetadataTypeAndName.values().get(0);
                selectionsByMetadataTypeAndName = getSelections(previousSelections);
                DeleteSalesforceFiles.deleteFiles(new List<ContentDocument>{ new ContentDocument(Id = previousSelections.ContentDocumentId) });
            }
            selectionsByMetadataTypeAndName.put(metadataTypeAndName, selectedFilePaths);
            return createContentVersion(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION, JSON.serialize((selectionsByMetadataTypeAndName)), userStoryId);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static Map<String, String> getSelectionsForBundledMetadata(Id userStoryId) {
        try {
            Map<String, String> result = new Map<String, String>();
            Map<Id, ContentVersion> selectionsByMetadataTypeAndName = getLatestContentVersions(
                userStoryId,
                new List<String>{ CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION, CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT }
            );

            for(ContentVersion file : selectionsByMetadataTypeAndName.values()) {
                result.put(file.Title, file.VersionData?.toString());
            }
            return result;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    private static List<ContentDocumentLink> getLatestMetadataLinksOnUserStory(List<ContentDocumentLink> metadataLinksOnUserStory) {
        Map<String, ContentDocumentLink> latestMetadataLinksOnUserStoryByTitle = new Map<String, ContentDocumentLink>();
        for (ContentDocumentLink metadataLinkOnUserStory : metadataLinksOnUserStory) {
            if (!latestMetadataLinksOnUserStoryByTitle.containsKey(metadataLinkOnUserStory.ContentDocument.Title)) {
                latestMetadataLinksOnUserStoryByTitle.put(metadataLinkOnUserStory.ContentDocument.Title, metadataLinkOnUserStory);
            }
        }
        return latestMetadataLinksOnUserStoryByTitle.values();
    }

    private static String getTemplateName(String metadataTypeAndName) {
        String metadataType = getMetadataType(metadataTypeAndName);
        if (BUNDLED_METADATA.contains(metadataType)) {
            return SFDX_BUNDLED_METADATA_SELECTIVE_COMMIT_SETUP;
        } else if (LAYOUTS_FLEXIPAGES.contains(metadataType)) {
            return SFDX_SELECTIVE_COMMIT_SETUP;
        } else {
            throw new ApplicationException(Label.Invalid_MetadataType);
        }
    }

    private static String getMetadataType(String metadataTypeAndName) {
        String result = metadataTypeAndName.substringBefore(':')?.toLowerCase();
        if (String.isBlank(result)) {
            throw new ApplicationException(Label.Missing_MetadataType_In_Payload);
        }
        return result;
    }

    private static List<String> getTitlesOfFiles(String filePrefix, String filePathHash) {
        String baseBranchFile = filePrefix + '_' + filePathHash + BASE_SUFFIX;
        String sourceBranchFile = filePrefix + '_' + filePathHash + SOURCE_SUFFIX;
        String featureBranchFile = filePrefix + '_' + filePathHash + FEATURE_SUFFIX;
        return new List<String>{ baseBranchFile, sourceBranchFile, featureBranchFile };
    }

    private static Map<String, List<String>> getSelections(ContentVersion file) {
        String fileContent = file.VersionData?.toString();
        return (Map<String, List<String>>) JSON.deserialize(fileContent, Map<String, List<String>>.class);
    }

    private static Id createContentVersion(String title, String content, Id linkedEntityId) {
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S'; // S = Stored in Salesforce
        contentVersion.PathOnClient = title + '.json';
        contentVersion.Title = title;
        contentVersion.VersionData = Blob.valueOf(content);
        contentVersion.FirstPublishLocationId = linkedEntityId;
        Utilities.performDML(new List<ContentVersion>{ contentVersion }, 'insert', AccessLevel.USER_MODE);
        return contentVersion.Id;
    }

    public class JobExecutionDetails {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Id recordId;

        public JobExecutionDetails(String name, String status, Id recordId) {
            this.name = name;
            this.status = status;
            this.recordId = recordId;
        }
    }
}