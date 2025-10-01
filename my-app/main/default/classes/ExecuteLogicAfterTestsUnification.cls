public with sharing class ExecuteLogicAfterTestsUnification implements Queueable {
    private List<copado__Test__c> testsToUnify = new List<copado__Test__c>();
    private List<copado__Test__c> unifiedTests = new List<copado__Test__c>();
    private List<copado__User_Story__c> bundledStories = new List<copado__User_Story__c>();

    private static final List<String> TEST_LEVELS_IN_ORDER = Utilities.getPicklistValues(
        SObjectType.copado__User_Story__c.getName(),
        copado__User_Story__c.copado__Promotion_Test_Level__c.getDescribe(FieldDescribeOptions.DEFAULT).getName() //NOPMD // PMD is giving a false positive here.
    );

    public ExecuteLogicAfterTestsUnification(Request request) {
        this.testsToUnify = request.testsToUnify;
        this.unifiedTests = request.unifiedTests;
        this.bundledStories = request.bundledStories;
    }

    public void execute(QueueableContext context) {
        List<MetadataItem> metadataItems = getMetadataItems(this.testsToUnify);
        copado__Test__c unifiedTest = this.unifiedTests[0];
        AddApexTestsController.createContentVersion(unifiedTest.Id, metadataItems);

        String apexTestLevel = getApexTestLevel();

        Utilities.performDML(
            new List<copado__User_Story__c>{
                new copado__User_Story__c(Id = unifiedTest.copado__User_Story__c, copado__Promotion_Test_Level__c = apexTestLevel)
            },
            'update',
            AccessLevel.USER_MODE
        );
    }

    private String getApexTestLevel() {
        Integer currIndex = 0;
        Integer lastTestLevelIndex = TEST_LEVELS_IN_ORDER.size() - 1;
        for (copado__User_Story__c bundledUserStory : this.bundledStories) {
            String apexTestLevel = bundledUserStory.copado__Promotion_Test_Level__c;
            if (String.isNotBlank(apexTestLevel)) {
                Integer newIndex = TEST_LEVELS_IN_ORDER.indexOf(apexTestLevel);
                currIndex = (newIndex > currIndex) ? newIndex : currIndex;
                if (currIndex == lastTestLevelIndex) {
                    break;
                }
            }
        }

        return TEST_LEVELS_IN_ORDER[currIndex];
    }

    private List<MetaDataItem> getMetadataItems(List<copado__Test__c> testToUnify) {
        List<MetaDataItem> result = new List<MetaDataItem>();

        Set<Id> testIds = new Map<Id, copado__Test__c>(testToUnify).keySet();
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink documentLink : new ContentDocumentLinksSelector().byLinkedEntityId(testIds)) {
            contentDocumentIds.add(documentLink.ContentDocumentId);
        }

        Map<String, MetaDataItem> metadataItemByKey = new Map<String, MetaDataItem>();
        for (ContentVersion contentVersion : new ContentVersionsSelector().byContentDocumentIdWithLatest(contentDocumentIds)) {
            String versionData = contentVersion.VersionData.toString();
            List<MetaDataItem> testItems = (String.isNotBlank(versionData)) ? MetaDataItem.parseForFileJSON(versionData) : new List<MetaDataItem>();
            for (MetaDataItem item : testItems) {
                String key = item.t + item.ns + item.n;
                if (!metadataItemByKey.containsKey(key) || item.s == true) {
                    metadataItemByKey.put(key, item);
                }
            }
        }

        result.addAll(metadataItemByKey.values());

        return result;
    }
    public class Request {
        public List<copado__Test__c> testsToUnify;
        public List<copado__Test__c> unifiedTests;
        public List<copado__User_Story__c> bundledStories;
    }
}