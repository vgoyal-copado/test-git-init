@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class ApexTestsUnifier extends copado.UserStoryBundleTestsUnifier {
    private List<copado__Test__c> testToUnify = new List<copado__Test__c>();
    private List<copado__User_Story__c> bundledStories = new List<copado__User_Story__c>();

    // GLOBAL
    global override List<copado__Test__c> unifyTests(List<copado__Test__c> testToUnify) {
        List<copado__Test__c> result = new List<copado__Test__c>();

        if (!testToUnify.isEmpty()) {
            this.testToUnify = testToUnify;
            copado__Test__c originalTest = testToUnify[0];
            result.add(cloneTest(originalTest));

            Set<Id> storyIds = new Set<Id>();
            for (copado__Test__c record : testToUnify) {
                storyIds.add(record.copado__User_Story__c);
            }
            this.bundledStories = new UserStoriesSelector().byIds(storyIds);
        }
        return result;
    }

    global override void additionalLogicAfterUnify(List<copado__Test__c> unifiedTests) {
        if (!unifiedTests.isEmpty()) {
            ExecuteLogicAfterTestsUnification.Request request = getRequest(unifiedTests);
            try {
                Id jobId = System.enqueueJob(new ExecuteLogicAfterTestsUnification(request));
                startPolling(jobId, unifiedTests[0].copado__User_Story__c);
            } catch(Exception ex) {
                System.debug(ex.getMessage() + ' ' + ex.getStackTraceString());
            }
          
        }
    }

    public static void startPolling(Id jobId, Id userStoryId) {
        PollApexJob.Request request = new PollApexJob.Request();
        request.jobId = jobId;
        request.delayInSeconds = 5;
        request.timeoutInMinutes = 5;
        request.callback = new ExecuteCommitJob(userStoryId);

        PollApexJob scheduler = new PollApexJob(request);
        if(!Test.isRunningTest()) {
            System.schedule('PollApexJob ' + System.now(), scheduler.nextCron(), scheduler);
        }
    }

    private ExecuteLogicAfterTestsUnification.Request getRequest(List<copado__Test__c> unifiedTests) {
        ExecuteLogicAfterTestsUnification.Request result = new ExecuteLogicAfterTestsUnification.Request();
        result.bundledStories = this.bundledStories;
        result.testsToUnify = this.testToUnify;
        result.unifiedTests = unifiedTests;
        return result;
    }

    // PRIVATE

    private copado__Test__c cloneTest(copado__Test__c originalTest) {
        copado__Test__c clonedTest = originalTest.clone(false, true, false, false);
        clonedTest.Name = String.format(Label.Unified_Test_Name, new List<String>{ originalTest.copado__Test_Tool__c });
        clonedTest = emptyInvalidFields(clonedTest);
        return clonedTest;
    }

    @SuppressWarnings('PMD.EagerlyLoadedDescribeSObjectResult')
    private copado__Test__c emptyInvalidFields(copado__Test__c test) {
        Set<String> invalidFields = new Set<String>{
            copado__Test__c.copado__Test_Tool__c.getDescribe().getName(),
            copado__Test__c.copado__LatestJobExecution__c.getDescribe().getName()
        };

        Map<String, Object> testFields = new Map<String, Object>(test.getPopulatedFieldsAsMap());
        for (String testField : invalidFields) {
            testFields.remove(testField);
        }
        return (copado__Test__c) JSON.deserialize(JSON.serialize(testFields), copado__Test__c.class);
    }
}