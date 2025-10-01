@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class SelectiveCommitSetupCallback implements copado.MCCallback {
    @TestVisible
    private static final String SOURCE_ORG_FILE_SUFFIX = '%_source';
    @TestVisible
    private static final String BASE_BRANCH_FILE_SUFFIX = '%_base';
    @TestVisible
    private static final String DESTINATION_BRANCH_FILE_SUFFIX = '%_destination';
    @TestVisible
    private static final String FEATURE_BRANCH_FILE_SUFFIX = '%_feature';
    @TestVisible
    private static final String TEMP_FILE_SUFFIX = '%_temp';
    @TestVisible
    private static final String SESSION_FILE_SUFFIX = '%_session';
    @TestVisible
    private static final String STRUCTURE_FILE_SUFFIX = '%_structure';

    // GLOBAL

    global void execute(copado__Function__c function, copado__Result__c result, String status) {
        copado__Result__c selectiveCommitSetupResult = getResult(result.Id);
        SelectiveCommitSetupPayload selectiveCommitSetupPayload = getSelectiveCommitSetupPayload(selectiveCommitSetupResult);
        Set<String> fileTitlesUsedInSelectiveCommitSetup = getFileTitlesUsedInSelectiveCommitSetup(selectiveCommitSetupPayload.filePrefix);
        DeleteSalesforceFiles.deleteContentDocuments(
            new List<Id>{ selectiveCommitSetupPayload.userStoryId },
            new List<String>{ selectiveCommitSetupPayload.filePrefix + TEMP_FILE_SUFFIX }
        );
        DeleteSalesforceFiles.deleteOutdatedContentDocumentsAndReturnLatest(
            fileTitlesUsedInSelectiveCommitSetup,
            selectiveCommitSetupPayload.userStoryId
        );
    }

    // PRIVATE

    private static copado__Result__c getResult(String recordId) {
        List<copado__Result__c> result = new ResultsSelector().byIds(new Set<Id>{ recordId });
        return result[0];
    }

    private static SelectiveCommitSetupPayload getSelectiveCommitSetupPayload(copado__Result__c selectiveCommitSetupResult) {
        SelectiveCommitSetupPayload result = (SelectiveCommitSetupPayload) JSON.deserialize(
            selectiveCommitSetupResult?.copado__JobStep__r?.copado__JobExecution__r?.copado__DataJson__c,
            SelectiveCommitSetupPayload.class
        );
        return result;
    }

    private static Set<String> getFileTitlesUsedInSelectiveCommitSetup(String filePrefix) {
        Set<String> result = new Set<String>();
        result.add(filePrefix + SOURCE_ORG_FILE_SUFFIX);
        result.add(filePrefix + BASE_BRANCH_FILE_SUFFIX);
        result.add(filePrefix + DESTINATION_BRANCH_FILE_SUFFIX);
        result.add(filePrefix + FEATURE_BRANCH_FILE_SUFFIX);
        result.add(filePrefix + SESSION_FILE_SUFFIX);
        result.add(filePrefix + STRUCTURE_FILE_SUFFIX);
        return result;
    }
}