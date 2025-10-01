@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class GetSelectionsForBundledMetadata implements copado.ParameterExpressionCallable {
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION = 'cmcSf_SelectionsForBundledMetadata_session';
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT = 'cmcSf_SelectionsForBundledMetadata_commit';
    global String execute(Id contextId) {
        String result = '';
        List<String> fileVersionIds = new List<String>();

        try {
            Id userStoryId = getUserStoryId(contextId);
            if (userStoryId == null) {
                return result;
            }
            List<ContentVersion> filesOnUserStory = new ContentVersionsSelector()
                .byFirstPublishLocationIdAndTitleAndIsLatest(new Set<Id>{ userStoryId }, new List<String>{ CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION, CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT });
            for (ContentVersion file : filesOnUserStory) {
                fileVersionIds.add(file.Id);
            }

            result = String.join(fileVersionIds, ';');
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
        return result;
    }

    private static Id getUserStoryId(Id contextId) {
        List<copado__JobStep__c> jobSteps = new JobStepsSelector().byIds(new Set<Id>{ contextId });
        if (jobSteps.isEmpty()) {
            return null;
        }
        JobExecutionPayload jobExecutionPayload = (JobExecutionPayload) JSON.deserialize(
            jobSteps[0].copado__JobExecution__r.copado__DataJson__c,
            JobExecutionPayload.class
        );
        return jobExecutionPayload.userStoryId;
    }
    private class JobExecutionPayload {
        Id userStoryId;
    }
}