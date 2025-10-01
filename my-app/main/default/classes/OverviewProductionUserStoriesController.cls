public with sharing class OverviewProductionUserStoriesController {
    private final static String OK = 'ok';
    private final static String ASC_ORDER = 'ASC';
    private final static String URL = 'url';
    
    private static final Map<String,String> FIELD_APIS_BY_COLUMN_NAMES = new Map<String,String>{
        'url' => 'Name',
        'title' => 'copado__User_Story_Title__c',
        'recordType' => 'RecordType.Name',
        'status' => 'copado__Status__c',
        'excludeFromPipeline' => 'copado__Exclude_From_CBM__c',
        'excludeFromOverlapAwareness' => 'copado__Stop_Indexing_Metadata__c'
    };

    @AuraEnabled(cacheable=true)
    public static Integer getProductionUserStoryCount(
        Id selectedPipelineId, Id selectedProjectId, Id selectedReleaseId
    ) {
        try {
            if (String.isBlank(selectedPipelineId)) {
                return 0;
            }

            Id productionEnvironmentId = new PipelineDescriptor(selectedPipelineId).findFinalEnvironment()?.Id;
            if (productionEnvironmentId == null) {
                return 0;
            }

            String query = getCountQuery(productionEnvironmentId, selectedProjectId, selectedReleaseId);
            return Database.countQuery(query);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled
    public static List<UserStoryWrapper> getUserStoryData(String params) {
        try {
            OverviewPipelineTablesHelper.LwcParams lwcParams =
                (OverviewPipelineTablesHelper.LwcParams) OverviewPipelineTablesHelper.deserializeParams(params, OverviewPipelineTablesHelper.LwcParams.class);
            
            lwcParams.orderBy = String.isBlank(lwcParams.orderBy) ? URL : lwcParams.orderBy;
            lwcParams.orderDirection = String.isBlank(lwcParams.orderDirection) ? ASC_ORDER : lwcParams.orderDirection;

            fflib_QueryFactory.SortOrder orderDirectionEnum = lwcParams.orderDirection.equalsIgnoreCase(ASC_ORDER) ?
                fflib_QueryFactory.SortOrder.ASCENDING :
                fflib_QueryFactory.SortOrder.DESCENDING;

            if (String.isBlank(lwcParams.selectedPipelineId)) {
                return new List<UserStoryWrapper>();
            }

            Id productionEnvironmentId = new PipelineDescriptor(lwcParams.selectedPipelineId).findFinalEnvironment()?.Id;
            if (productionEnvironmentId == null) {
                return new List<UserStoryWrapper>();
            }

            List<copado__User_Story__c> userStories = new UserStoriesSelector().getNonExcludedProductionUserStories(
                productionEnvironmentId,
                lwcParams.selectedPipelineId,
                lwcParams.selectedProjectId,
                lwcParams.selectedReleaseId,
                lwcParams.queryLimit,
                lwcParams.offset,
                lwcParams.searchTerm,
                FIELD_APIS_BY_COLUMN_NAMES.get(lwcParams.orderBy),
                orderDirectionEnum
            );

            return wrapUserStories(userStories);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled
    public static String excludeUserStories(List<Id> userStoryIds) {
        try {
            if (!hasPermissionsForUserStoriesExclusion()) {
                throw new ApplicationException(Label.NonUpdateableUserStory);
            }

            List<copado__User_Story__c> storiesToUpdate = new List<copado__User_Story__c>();
            
            for(Id storyId : userStoryIds) {
                storiesToUpdate.add(new copado__User_Story__c(
                    Id = storyId,
                    copado__Exclude_From_CBM__c = true,
                    copado__Stop_Indexing_Metadata__c = true
                ));
            }
            
            if(!storiesToUpdate.isEmpty()) {
                // NOPMD: Security-ApexCRUDViolation
                List<Database.SaveResult> updateResults = Database.update(storiesToUpdate, false);

                for (Database.SaveResult updateResult : updateResults) {
                    if (!updateResult.isSuccess()) {
                        return Label.ExcludeSelectionsDatabaseFail;
                    }
                }
            }
            
            return OK;
        } catch(Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    private static Boolean hasPermissionsForUserStoriesExclusion() {
        return Schema.sObjectType.copado__User_Story__c.isUpdateable()
            && Schema.sObjectType.copado__User_Story__c.fields.copado__Exclude_From_CBM__c.isUpdateable()
            && Schema.sObjectType.copado__User_Story__c.fields.copado__Stop_Indexing_Metadata__c.isUpdateable();
    }

    private static String getCountQuery(Id productionEnvironmentId, Id selectedProjectId, Id selectedReleaseId) {
        String baseQuery = 'SELECT COUNT() FROM copado__User_Story__c {0} WITH USER_MODE';

        List<String> userStoryConditions = new List<String>{
            'copado__Environment__c = :productionEnvironmentId',
            '(copado__Exclude_From_CBM__c = FALSE OR copado__Stop_Indexing_Metadata__c = FALSE)',
            '(copado__Project__r.copado__Deployment_Flow__c = :selectedPipelineId OR copado__Release__r.copado__Project__r.copado__Deployment_Flow__c = :selectedPipelineId)'
        };

        OverviewPipelineTablesHelper.BaseConditionsParams baseConditionsParams =
            new OverviewPipelineTablesHelper.BaseConditionsParams();
        baseConditionsParams.selectedProjectId = selectedProjectId;
        baseConditionsParams.selectedReleaseId = selectedReleaseId;

        userStoryConditions.addAll(OverviewPipelineTablesHelper.buildBaseConditions(
            baseConditionsParams
        ));

        String userStoryConditionsString = String.join(
            userStoryConditions,
            ' AND '
        );

        String query = String.format(
            baseQuery,
            new List<String>{
                String.isNotBlank(userStoryConditionsString) ? 'WHERE ' + userStoryConditionsString : ''
            }
        );

        return query;
    }

    private static List<UserStoryWrapper> wrapUserStories(List<copado__User_Story__c> userStories) {
        List<UserStoryWrapper> wrappedStories = new List<UserStoryWrapper>();
        for(copado__User_Story__c story : userStories) {
            wrappedStories.add(new UserStoryWrapper(story));
        }
        return wrappedStories;
    }

    public class UserStoryWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String recordType;
        @AuraEnabled public String status;
        @AuraEnabled public String fullyBackPromoted;
        @AuraEnabled public String excludeFromPipeline;
        @AuraEnabled public String excludeFromOverlapAwareness;
        @AuraEnabled public String url;

        public UserStoryWrapper(copado__User_Story__c story) {
            this.id = story.Id;
            this.name = story.Name;
            this.title = story.copado__User_Story_Title__c;
            this.recordType = story.RecordType?.Name;
            this.status = story.copado__Status__c;
            this.excludeFromPipeline = story.copado__Exclude_From_CBM__c ? Label.Yes : Label.No;
            this.excludeFromOverlapAwareness = story.copado__Stop_Indexing_Metadata__c ? Label.Yes : Label.No;
            this.url = '/' + story.Id;
        }
    }
}