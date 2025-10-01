@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.CyclomaticComplexity, PMD.CognitiveComplexity')
global with sharing class CommitFunctionCallback implements copado.MCCallback {
    @TestVisible
    private static final List<String> SELECTIVE_COMMIT_HASH_SUFFIXES = new List<String>{ '_base', '_source', '_destination', '_feature', '_temp', '_structure' };
    private static final String SELECTIVE_COMMIT = 'SelectiveCommit';
    @TestVisible
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION = 'cmcSf_SelectionsForBundledMetadata_session';
    @TestVisible
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT = 'cmcSf_SelectionsForBundledMetadata_commit';
    private static final Set<String> BUNDLED_METADATA = new Set<String>{
        'auradefinitionbundle',
        'experiencebundle',
        'lightningcomponentbundle',
        'wavetemplatebundle'
    };

    global void execute(copado__Function__c function, copado__Result__c result, String status) {
        ResultData resultData = new ResultData();
        try {
            resultData = getResultData(result);
            CommitJobExecutionDataJson dataJson = getJobExecutionDataJson(result);

            Id userStoryId = (Id) dataJson?.userStoryId;
            Id fileWithSelectedChanges = (Id) dataJson?.fileWithSelectedChanges;
            List<MetadataItem> commitChanges = getCommitChanges(fileWithSelectedChanges);
            List<String> selectiveCommittedHashes = getSelectiveCommittedHashes(commitChanges);

            Map<String, String> selectionsForBundledMetadata = getFileContentForBundledMetadata(userStoryId);
            if(!selectionsForBundledMetadata.isEmpty()) {
                Boolean recreateFeatureBranch = dataJson?.recreateFeatureBranch.toLowerCase() == 'true' ? true : false;
                Map<String, List<String>> commitContentForBundledSelections = getSessionSelectionsForBundledMetadata(commitChanges, selectionsForBundledMetadata, recreateFeatureBranch);
                if(!(commitContentForBundledSelections.isEmpty())){
                    DeleteSalesforceFiles.deleteContentDocuments(new List<Id>{userStoryId}, new List<String>{CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT});
                    createContentVersion(CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT, JSON.serialize(commitContentForBundledSelections), userStoryId);
                }
            }

            List<ContentDocumentLink> files = getSelectiveCommitFiles(userStoryId);
            List<String> obsoleteCommitHashes = findObsoleteCommitHashes(commitChanges, userStoryId);
            deleteSelectiveCommitSetupFiles(files, selectiveCommittedHashes, obsoleteCommitHashes);
            UserStoryDataDevops.deleteOldFiles(userStoryId);

            /*This flow will manage the committed Selective Commit Files, it handles 3 basic flows:
                1) When only session file is present: In this case, we delete only content documents for the session files and rename the latest from hash_session to hash_commit.
                2) When both session and commit files are present: In this case, we delete the commit file, delete all the outdated session files and then rename hash_session to hash_commit.
                3) When only commit files are present: In this case, we do nothing.
                */
            if (isCommitResultValid(result, resultData) && !selectiveCommittedHashes.isEmpty()) {
                List<String> committedSessionFiles = getSessionFilesForCommittedMetadata(files, selectiveCommittedHashes);
                deleteOldCommitFiles(committedSessionFiles, files);
                Map<String, ContentDocument> latestSessionFilesByTitle = DeleteSalesforceFiles.deleteOutdatedContentDocumentsAndReturnLatest(
                    new Set<String>(committedSessionFiles),
                    userStoryId
                );
                renameLatestSessionFiles(latestSessionFilesByTitle);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // PRIVATE

    private static Map<String, String> getFileContentForBundledMetadata(Id userStoryId){
        Map<String, String> result = new Map<String, String>();
        List<ContentVersion> selectionsByMetadataTypeAndName = new ContentVersionsSelector().byFirstPublishLocationIdAndTitleAndIsLatest(
            new Set<Id>{userStoryId},
            new List<String>{ CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION, CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT }
        );

        for(ContentVersion file : selectionsByMetadataTypeAndName) {
            result.put(file.Title, file.VersionData?.toString());
        }
        return result;
    }

    private static Map<String, List<String>> getSessionSelectionsForBundledMetadata(List<MetaDataItem> changes, Map<String, String> selections, Boolean recreateFeatureBranch) {
        Map<String, List<String>> previouslyCommittedSelections = getFileContent(selections, CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT);
        Map<String, List<String>> selectionsFromSessionFile = getFileContent(selections, CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION);

        /*If we have recreateFeatureBranch = true and commit file for selections of Bundle Metadata already present,
        we dump the previously committed selections.*/
        if(recreateFeatureBranch && !previouslyCommittedSelections.isEmpty()) {
            previouslyCommittedSelections = new Map<String, List<String>>();
        }

        return getCommittedContentForBundledSelections(changes, selectionsFromSessionFile, previouslyCommittedSelections);
    }

    private static Map<String, List<String>> getFileContent(Map<String, String> selections, String title) {
        Map<String, List<String>> result = new Map<String, List<String>>();

        if(selections.containsKey(title)) {
           result = (Map<String, List<String>>) JSON.deserialize(selections.get(title), Map<String, List<String>>.class);

        }

        return result;
    }

    private static Map<String, List<String>> getCommittedContentForBundledSelections(List<MetaDataItem> changes, Map<String, List<String>> selectionsFromSessionFile, Map<String, List<String>> previouslyCommittedSelections) {
        //If previouslyCommittedSelections has data, we only update the selections from latest session file.
        Map<String, List<String>> result = previouslyCommittedSelections;

        for(MetaDataItem change : changes) {
            String key = change.t + ':' +change.n;
            if (change?.a == SELECTIVE_COMMIT && BUNDLED_METADATA.contains(change.t.toLowerCase()) && selectionsFromSessionFile.containsKey(key)) {
                result.put(key, selectionsFromSessionFile.get(key));
            }
        }

        return result;
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

    private static List<MetaDataItem> getCommitChanges(Id contentVersionId) {
        List<MetaDataItem> result = new List<MetaDataItem>();
        List<ContentVersion> fileWithSelectedchanges = new ContentVersionsSelector().byIds(new Set<Id>{ contentversionId });

        if (!fileWithSelectedchanges.isEmpty()) {
            String versionData = fileWithSelectedchanges[0].VersionData.toString();
            result = (List<MetaDataItem>) JSON.deserialize(versionData, List<MetaDataItem>.class);
        }
        return result;
    }

    private static List<String> getSelectiveCommittedHashes(List<MetaDataItem> commitChanges) {
        List<String> result = new List<String>();

        for (MetadataItem change : commitChanges) {
            if (change?.a == SELECTIVE_COMMIT) {
                JsonAdditionalInfo additionalInfo = (JsonAdditionalInfo) JSON.deserialize(change?.j, JsonAdditionalInfo.class);
                String hash = additionalInfo?.selectiveCommitHash;
                result.add(hash);
            }
        }

        return result;
    }

    /* Check and find the hashes of file which were previously commmited as Selective Commit
        but new commit has different operation like Add.
    */
    private List<String> findObsoleteCommitHashes(List<MetadataItem> commitChanges, Id userStoryId) {
        List<String> result = new List<String>();
        List<copado__User_Story_Metadata__c> previouslyCommittedMetadata = new UserStoryMetadataSelector()
            .byStoryIdsAndActions(new Set<Id>{ userStoryId }, new Set<String>{ SELECTIVE_COMMIT });

        if (previouslyCommittedMetadata.isEmpty()) {
            return result;
        }

        Map<String, MetadataItem> currentCommitMap = createCurrentCommitMap(commitChanges);

        // Compare previously committed metadata with current commit changes
        for (copado__User_Story_Metadata__c metadata : previouslyCommittedMetadata) {
            String previousKey = formatMetadataKey(metadata.copado__Category__c, metadata.copado__Metadata_API_Name__c, metadata.copado__Type__c);

            if (currentCommitMap.containsKey(previousKey)) {
                JsonAdditionalInfo additionalInfo = deserializeJsonInfo(metadata.copado__JsonInformation__c);
                if (additionalInfo != null && additionalInfo.selectiveCommitHash != null) {
                    result.add(additionalInfo.selectiveCommitHash);
                }
            }
        }

        return result;
    }

    private JsonAdditionalInfo deserializeJsonInfo(String jsonInfo) {
        try {
            return (JsonAdditionalInfo) JSON.deserialize(jsonInfo, JsonAdditionalInfo.class);
        } catch (Exception e) {
            return null;
        }
    }

    private String formatMetadataKey(String category, String name, String type) {
        return String.format('{0}:{1}:{2}', new List<String>{ category, name, type });
    }

    private Map<String, MetadataItem> createCurrentCommitMap(List<MetadataItem> commitChanges) {
        Map<String, MetadataItem> result = new Map<String, MetadataItem>();
        for (MetadataItem change : commitChanges) {
            if (change.a != SELECTIVE_COMMIT) {
                String key = formatMetadataKey(change.c, change.n, change.t);
                result.put(key, change);
            }
        }
        return result;
    }

    private static void deleteSelectiveCommitSetupFiles(
        List<ContentDocumentLink> files,
        List<String> selectiveCommittedHashes,
        List<String> obsoleteCommitHashes
    ) {
        List<ContentDocument> filesToBeDeleted = new List<ContentDocument>();
        for (ContentDocumentLink link : files) {
            List<String> title = link.ContentDocument.title.split('_');
            String hash = title[0];
            String suffix = title[title.size() - 1];

            if (
                SELECTIVE_COMMIT_HASH_SUFFIXES.contains('_' + suffix) ||
                (suffix == 'session' && !selectiveCommittedHashes.contains(hash)) ||
                (suffix == 'commit' && obsoleteCommitHashes.contains(hash))
            ) {
                filesToBeDeleted.add(new ContentDocument(Id = link.ContentDocumentId));
            }
        }
        DeleteSalesforceFiles.deleteFiles(filesToBeDeleted);
    }

    private static List<String> getSessionFilesForCommittedMetadata(List<ContentDocumentLink> files, List<String> selectiveCommittedHashes) {
        List<String> result = new List<String>();

        for (ContentDocumentLink link : files) {
            List<String> title = link.ContentDocument.title.split('_');
            String hash = title[0];
            String suffix = title[1];

            if (suffix == 'session' && selectiveCommittedHashes.contains(hash)) {
                result.add(link.ContentDocument.title);
            }
        }
        return result;
    }

    private static void renameLatestSessionFiles(Map<String, ContentDocument> sessionsFilesToBeRenamed) {
        List<ContentDocument> contentDocuments = sessionsFilesToBeRenamed.values();
        for (ContentDocument document : contentDocuments) {
            document.title = document.title.replace('_session', '_commit');
        }

        new Utilities.UpdateSObjectWithoutSharing().execute(contentDocuments);
    }

    private static void deleteOldCommitFiles(List<String> deleteRespectiveCommitFiles, List<ContentDocumentLink> files) {
        List<ContentDocument> commitFilesToBeDeleted = new List<ContentDocument>();
        for (ContentDocumentLink link : files) {
            String title = link.ContentDocument.title;
            if (title.contains('_commit') && deleteRespectiveCommitFiles.contains(title.replace('_commit', '_session'))) {
                commitFilesToBeDeleted.add(link.ContentDocument);
            }
        }

        DeleteSalesforceFiles.deleteFiles(commitFilesToBeDeleted);
    }

    private static List<ContentDocumentLink> getSelectiveCommitFiles(Id userStoryId) {
        Set<String> searchPatterns = new Set<String>{ '%_base', '%_destination', '%_feature', '%_source', '%_session', '%_commit', '%_temp' , '%_structure'};

        return getContentDocumentLinks(new Set<Id>{ userStoryId }, searchPatterns);
    }

    private static List<ContentDocumentLink> getContentDocumentLinks(Set<Id> entityIds, Set<String> fileNames) {
        return new ContentDocumentLinksSelector().contentDocumentByLinkedEntityIdAndTitle(entityIds, fileNames);
    }

    private static ResultData getResultData(copado__Result__c commitResult) {
        ResultData result = new ResultData();
        String resultData = commitResult.copado__Result_Data__c;
        if (String.isNotBlank(resultData)) {
            result = (ResultData) JSON.deserialize(resultData, ResultData.class);
        }
        return result;
    }

    private static CommitJobExecutionDataJson getJobExecutionDataJson(copado__Result__c commitResult) {
        CommitJobExecutionDataJson result = new CommitJobExecutionDataJson();
        List<copado__Result__c> results = new ResultsSelector().byIds(new Set<Id>{ commitResult.Id });
        String dataJson = results[0]?.copado__JobStep__r?.copado__JobExecution__r?.copado__DataJson__c;
        if (String.isNotBlank(dataJson)) {
            result = (CommitJobExecutionDataJson) JSON.deserialize(dataJson, CommitJobExecutionDataJson.class);
        }
        return result;
    }

    private static Boolean isCommitResultValid(copado__Result__c commitResult, ResultData resultData) {
        String status = resultData?.status != null ? (String) resultData?.status : '';
        return commitResult.copado__Status__c == 'Success' || status == 'No Changes';
    }

    // INNER

    public class ResultData {
        public String status;
    }

    public class CommitJobExecutionDataJson {
        public String fileWithSelectedChanges;
        public String userStoryId;
        public String recreateFeatureBranch;
    }

    public class JsonAdditionalInfo {
        public String selectiveCommitHash;
    }
}