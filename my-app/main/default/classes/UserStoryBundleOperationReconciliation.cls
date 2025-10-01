@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class UserStoryBundleOperationReconciliation {
    @TestVisible
    private static List<MetaDataItem> reconciledTestChanges;
    @TestVisible
    private static List<BundledSelectiveCommitSelection> bundledSelectiveCommitSelectionsOnUserStories = new List<BundledSelectiveCommitSelection>();
    private static final List<String> OPERATIONS_IN_ORDER_OF_RECONCILIATION = new List<String>{ 'RetrieveOnly', 'SelectiveCommit', 'Add', 'Full' };
    private static final List<String> BUNDLED_SELECTIVE_COMMIT_SUPPORTED_METADATA = new List<String>{
        'AuraDefinitionBundle',
        'LightningComponentBundle',
        'ExperienceBundle',
        'WaveTemplateBundle'
    };
    private static final List<String> SELECTIVE_COMMIT_SUPPORTED_METADATA = new List<String>{ 'Layout', 'FlexiPage', 'ApexClass', 'ApexTrigger' };
    private static final String ADD = 'Add';
    private static final String SELECTIVE_COMMIT = 'SelectiveCommit';
    private static final String DELETE_OPERATION = 'Delete';
    @TestVisible
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION = 'cmcSf_SelectionsForBundledMetadata_session';
    @TestVisible
    private static final String CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT = 'cmcSf_SelectionsForBundledMetadata_commit';

    /* This execute method is triggered by the Flow(UserStoryBundleOperationReconciliation).
        This runs the logic of reconciling operations again
        to send the locked operations to the Commit action when 
        there are no Apex Tests to unify.
    */
    @InvocableMethod(label='User Story Bundle Reconciliation Logic')
    public static List<copado.CommitAction.Response> execute(List<Request> requests) {
        try {
            Id bundleUserStoryId = requests[0].bundleUserStory.Id;
            List<copado__Test__c> testsOnBundleStory = new TestsSelector()
                .byUserStoriesAndExtensionTools(new Set<Id>{ bundleUserStoryId }, new Set<String>{ getApexTestValue() });
            if (testsOnBundleStory.isEmpty()) {
                return run(requests);
            }
            return null;
        } catch (Exception ex) {
            String exceptionMessage = ex.getMessage() + ' ' + ex.getStackTraceString();
            throw new ApplicationException(exceptionMessage);
        }
    }

    public static List<copado.CommitAction.Response> run(List<Request> requests) {
        try {
            Id packageVersionId = requests[0].packageVersionId;
            Id bundleUserStoryId = requests[0].bundleUserStory.Id;

            Set<Id> userStoryIds = getUserStoryIdsFromPackageVersion(packageVersionId);
            List<copado__User_Story_Metadata__c> metadataItems = new UserStoryMetadataSelector().byUserStoryId(userStoryIds);

            List<MetaDataItem> commitChanges = convertMetadataToCommitChange(metadataItems);
            bundledSelectiveCommitSelectionsOnUserStories = populateBundledSelectiveCommitMetadata(metadataItems);

            Map<String, MetaDataItem> reconciledComponentsByTypeAndName = reconcileComponents(commitChanges);
            createSelectionsFileForBundledMetadata(bundleUserStoryId, reconciledComponentsByTypeAndName);

            UserStoryCommitRequest request = new UserStoryCommitRequest();
            request.userStoryId = bundleUserStoryId;
            request.changes = reconciledComponentsByTypeAndName.values();
            request.recreateFeatureBranch = false;
            request.executeCommit = true;
            if (Test.isRunningTest()) {
                reconciledTestChanges = request.changes;
                return null;
            } else {
                return copado.CommitAction.commitChanges(new List<copado.CommitAction.Request>{ request.parse() });
            }
        } catch (Exception ex) {
            String exceptionMessage = ex.getMessage() + ' ' + ex.getStackTraceString();
            throw new ApplicationException(exceptionMessage);
        }
    }

    /* This execute method is triggered by the banner we see on the US Bundle(package version) page. This information is needed to show
     the user the overlapping actions for metadata items and the reconciled operations. */
    @AuraEnabled
    public static List<Response> execute(Id packageVersionId) {
        try {
            List<Response> result = new List<Response>();
            Set<Id> userStoryIds = getUserStoryIdsFromPackageVersion(packageVersionId);
            result = convertMetadataToReconciledResponse(userStoryIds);
            return result;
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    //PRIVATE

    private static Set<Id> getUserStoryIdsFromPackageVersion(Id packageVersionId) {
        Set<Id> userStoryIds = new Set<Id>();
        for (copado__Bundled_Story__c bundle : new BundledStorySelector().byPackageVersionId(packageVersionId)) {
            userStoryIds.add(bundle.copado__User_Story__c);
        }
        return userStoryIds;
    }

    private static Map<String, MetaDataItem> reconcileComponents(List<MetaDataItem> commitComponents) {
        Map<String, MetaDataItem> reconciledComponentsByTypeAndName = new Map<String, MetaDataItem>();
        Set<String> conflictingComponentsTypeAndName = new Set<String>();
        Set<String> destructiveComponents = new Set<String>();
        Set<String> otherOperationComponents = new Set<String>();
        String key = '';

        for (MetaDataItem currentComponent : commitComponents) {
            key = getUniqueKey(currentComponent);
            handleChange(
                reconciledComponentsByTypeAndName,
                conflictingComponentsTypeAndName,
                destructiveComponents,
                otherOperationComponents,
                currentComponent
            );
            if (!conflictingComponentsTypeAndName.contains(key)) {
                if (reconciledComponentsByTypeAndName.containsKey(key)) {
                    MetaDataItem previousComponent = reconciledComponentsByTypeAndName.get(key);
                    reconciledComponentsByTypeAndName.put(key, reconcile(previousComponent, currentComponent));
                } else {
                    reconciledComponentsByTypeAndName.put(key, currentComponent);
                }
            }
        }
        return reconciledComponentsByTypeAndName;
    }

    private static Boolean isDestructiveChange(MetaDataItem component) {
        return component.a == DELETE_OPERATION;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void handleChange(
        Map<String, MetaDataItem> reconciledComponentsByTypeAndName,
        Set<String> conflictingComponentsTypeAndName,
        Set<String> destructiveComponents,
        Set<String> otherOperationComponents,
        MetaDataItem component
    ) {
        String key = getUniqueKey(component);
        if (!conflictingComponentsTypeAndName.contains(key)) {
            if (isDestructiveChange(component)) {
                destructiveComponents.add(key);
                if (otherOperationComponents.contains(key)) {
                    conflictingComponentsTypeAndName.add(key);
                    reconciledComponentsByTypeAndName.remove(key);
                }
            } else {
                otherOperationComponents.add(key);
                if (destructiveComponents.contains(key)) {
                    conflictingComponentsTypeAndName.add(key);
                    reconciledComponentsByTypeAndName.remove(key);
                }
            }
        }
    }

    private static String getUniqueKey(MetaDataItem change) {
        return change.t + '/' + change.n;
    }

    private static MetaDataItem reconcile(MetaDataItem previousComponent, MetaDataItem currentComponent) {
        MetaDataItem result = previousComponent;
        Integer positionOfPreviousOperation = OPERATIONS_IN_ORDER_OF_RECONCILIATION.indexOf(previousComponent.a);
        Integer positionOfCurrentOperation = OPERATIONS_IN_ORDER_OF_RECONCILIATION.indexOf(currentComponent.a);
        if (positionOfCurrentOperation > positionOfPreviousOperation) {
            result = currentComponent;
        } else if (
            positionOfPreviousOperation == positionOfCurrentOperation &&
            currentComponent.a == SELECTIVE_COMMIT &&
            SELECTIVE_COMMIT_SUPPORTED_METADATA.contains(currentComponent.t)
        ) {
            result = cloneMetadataItem(previousComponent);
            result.a = ADD;
            result.j = null;
            result.m = '';
        }
        return result;
    }

    private static MetaDataItem cloneMetadataItem(MetaDataItem component) {
        MetaDataItem result = new MetaDataItem();
        result.t = component.t;
        result.n = component.n;
        result.c = component.c;
        return result;
    }

    private static List<Response> convertMetadataToReconciledResponse(Set<Id> userStoryIds) {
        List<Response> result = new List<Response>();
        List<MetaDataItem> commitChanges = new List<MetaDataItem>();

        for (copado__User_Story_Metadata__c metadata : new UserStoryMetadataSelector().byUserStoryId(userStoryIds)) {
            MetaDataItem change = convertToMetadataIem(metadata);
            commitChanges.add(change);
            result.add(
                new Response().metadata(change).userStoryId(metadata.copado__User_Story__c).userStoryName(metadata.copado__User_Story__r.Name)
            );
        }
        Map<String, MetaDataItem> reconciledComponentsByTypeAndName = reconcileComponents(commitChanges);
        return populateResponseWithReconciledComponent(reconciledComponentsByTypeAndName, result);
    }

    private static void createSelectionsFileForBundledMetadata(Id bundledUserStoryId, Map<String, MetaDataItem> reconciledComponentsByTypeAndName) {
        Set<Id> userStoryIds = new Set<Id>();
        for (BundledSelectiveCommitSelection resultItem : bundledSelectiveCommitSelectionsOnUserStories) {
            MetaDataItem metadata = resultItem.metadata;
            String key = getUniqueKey(metadata);
            if (reconciledComponentsByTypeAndName.containsKey(key) && reconciledComponentsByTypeAndName.get(key).a == SELECTIVE_COMMIT) {
                userStoryIds.add(resultItem.userStoryId);
            }
        }

        Map<String, Set<String>> selectedFilesByBundleTypeAndName = new Map<String, Set<String>>();
        for (
            ContentVersion file : new ContentVersionsSelector()
                .byFirstPublishLocationIdAndTitleAndIsLatest(userStoryIds, new List<String>{ CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT })
        ) {
            String data = file.VersionData?.toString();

            /* Following is the structure of file content:
            {"LightningComponentBundle:testLWC":["force-app/main/default/lwc/testLWC/testLWC.html"]}
            With bundleType:bundleName as the key.
            Hence, we are deserilizing it as Map<String, Set<String>> */
            Map<String, Set<String>> userStoryBundleSelectionsJson = (Map<String, Set<String>>) JSON.deserialize(
                data,
                Map<String, Set<String>>.class
            );
            for (String bundledMetadata : userStoryBundleSelectionsJson.keySet()) {
                if (selectedFilesByBundleTypeAndName.containsKey(bundledMetadata)) {
                    Set<String> files = selectedFilesByBundleTypeAndName.get(bundledMetadata);
                    files.addAll(userStoryBundleSelectionsJson.get(bundledMetadata));
                    selectedFilesByBundleTypeAndName.put(bundledMetadata, files);
                } else {
                    selectedFilesByBundleTypeAndName.put(bundledMetadata, userStoryBundleSelectionsJson.get(bundledMetadata));
                }
            }
        }

        if (!selectedFilesByBundleTypeAndName?.isEmpty()) {
            createFile(bundledUserStoryId, selectedFilesByBundleTypeAndName);
        }
    }

    private static void createFile(Id resultId, Map<String, Set<String>> fileContent) {
        Blob serializedJson = Blob.valueOf(JSON.serialize(fileContent, true));

        ContentVersion contentVersion = new ContentVersion(
            Title = CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION,
            PathOnClient = CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION + '.json',
            VersionData = serializedJson,
            FirstPublishLocationId = resultId
        );
        Utilities.performDML(new List<ContentVersion>{ contentVersion }, 'insert', AccessLevel.USER_MODE);
    }

    private static List<Response> populateResponseWithReconciledComponent(
        Map<String, MetaDataItem> reconciledComponentsByTypeAndName,
        List<Response> result
    ) {
        for (Response resultItem : result) {
            MetaDataItem metadata = resultItem.metadata;
            String key = getUniqueKey(metadata);
            if (reconciledComponentsByTypeAndName.containsKey(key)) {
                resultItem.lockedOperation = reconciledComponentsByTypeAndName.get(key).a;
            }
        }

        return result;
    }

    private static List<MetaDataItem> convertMetadataToCommitChange(List<copado__User_Story_Metadata__c> metadataItems) {
        List<MetaDataItem> result = new List<MetaDataItem>();
        for (copado__User_Story_Metadata__c metadata : metadataItems) {
            MetaDataItem change = convertToMetadataIem(metadata);
            result.add(change);
        }
        return result;
    }

    private static List<BundledSelectiveCommitSelection> populateBundledSelectiveCommitMetadata(List<copado__User_Story_Metadata__c> metadataItems) {
        List<BundledSelectiveCommitSelection> result = new List<BundledSelectiveCommitSelection>();
        for (copado__User_Story_Metadata__c metadata : metadataItems) {
            MetaDataItem change = convertToMetadataIem(metadata);
            if (BUNDLED_SELECTIVE_COMMIT_SUPPORTED_METADATA.contains(change.t) && change.a == SELECTIVE_COMMIT) {
                result.add(new BundledSelectiveCommitSelection().setMetadataItem(change).setUserStoryId(metadata.copado__User_Story__c));
            }
        }
        return result;
    }

    private static MetaDataItem convertToMetadataIem(copado__User_Story_Metadata__c metadata) {
        MetaDataItem change = new MetaDataItem();
        change.a = metadata.copado__Action__c;
        change.c = metadata.copado__Category__c;
        change.m = metadata.copado__ModuleDirectory__c;
        change.j = metadata.copado__JsonInformation__c;
        change.t = metadata.copado__Type__c;
        change.n = metadata.copado__Metadata_API_Name__c;

        return change;
    }

    private static String getApexTestValue() {
        return Test.isRunningTest() ? picklistValueForTest() : 'Apex Tests';
    }

    private static String picklistValueForTest() {
        //As "Apex Tests" value is a manual value we have to use a standard one for testing purposes
        List<String> picklistValues = Utilities.getPicklistValues(
            SObjectType.copado__ExtensionConfiguration__c.getName(),
            // PMD is giving a false positive here.
            copado__ExtensionConfiguration__c.copado__ExtensionTool__c.getDescribe(FieldDescribeOptions.DEFAULT).getName()
        );

        return (picklistValues.isEmpty() ? '' : picklistValues[0]);
    }
    public class Request {
        @InvocableVariable(label='Package Version Id' required=true)
        public String packageVersionId;

        @InvocableVariable(label='Bundle User Story')
        public copado__User_Story__c bundleUserStory;
    }

    public class Response {
        @AuraEnabled
        public Id userStoryId;
        @AuraEnabled
        public MetaDataItem metadata;
        @AuraEnabled
        public String userStoryName;
        @AuraEnabled
        public String lockedOperation;

        public Response userStoryId(Id userStoryId) {
            this.userStoryId = userStoryId;
            return this;
        }

        public Response metadata(MetaDataItem metadata) {
            this.metadata = metadata;
            return this;
        }

        public Response userStoryName(String userStoryName) {
            this.userStoryName = userStoryName;
            return this;
        }

        public Response lockedOperation(String lockedOperation) {
            this.lockedOperation = lockedOperation;
            return this;
        }
    }

    private class BundledSelectiveCommitSelection {
        private MetaDataItem metadata;
        private Id userStoryId;

        private BundledSelectiveCommitSelection setMetadataItem(MetaDataItem metadata) {
            this.metadata = metadata;
            return this;
        }

        private BundledSelectiveCommitSelection setUserStoryId(Id userStoryId) {
            this.userStoryId = userStoryId;
            return this;
        }
    }
}