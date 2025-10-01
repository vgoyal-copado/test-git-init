@SuppressWarnings('PMD.CyclomaticComplexity')
@isTest
private class LatestTestsRunsControllerTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';

    @TestSetup
    private static void setupData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            createData();
        }
    }

    @isTest
    private static void testGetTests() {
        // SETUP
        System.runAs(getRunAsUser()) {
            copado__Promotion__c promotion = createPromotion();

            // EXERCISE
            Test.startTest();
            List<LatestTestsRunsController.TestWrapper> tests = LatestTestsRunsController.getTests(new List<Id>{promotion.Id}).get(promotion.Id);
            Test.stopTest();

            // VERIFY
            Assert.areEqual(1, tests.size(), 'There should be 1 test for user story.');
        }
    }

    private static void createData() {
        new JobTemplate().name('MockTemplate').add(new JobStep().type('Function')).persist();

        Credential dev1Credential = new Credential();
        Environment dev1 = new Environment().name('dev1').type('Sandbox').platform('Other').add(dev1Credential);
        Environment dev2 = new Environment().name('dev2').type('Sandbox').platform('Other').add(new Credential());
        Credential intCredential = new Credential();
        Environment integration = new Environment().name('int').type('Sandbox').platform('Other').add(intCredential);
        Environment uat = new Environment().name('uat').type('Sandbox').platform('Other').add(new Credential());
        Environment prod = new Environment().name('prod').type('Sandbox').platform('Other').add(new Credential());

        new Pipeline()
            .active(true)
            .mainBranch('main')
            .platform('Other')
            .add(new PipelineConnection(new Pipeline(), dev1, integration).branch('dev1'))
            .add(new PipelineConnection(new Pipeline(), dev2, integration).branch('dev2'))
            .add(new PipelineConnection(new Pipeline(), integration, uat).branch('int'))
            .add(new PipelineConnection(new Pipeline(), uat, prod).branch('uat'))
            .add(
                new Project()
                    .add(new UserStory().title('US1').credential(dev1Credential).add(new UserStoryMetadata_t().name('TestClass').type('ApexClass')))
            )
            .persist();

        copado__ExtensionConfiguration__c extConfig = createExtensionConfiguration();

        copado__Test__c userStoryTest = new copado__Test__c(
            Name = 'User Story Test',
            copado__ExtensionConfiguration__c = extConfig.Id,
            copado__ReadyToRun__c = true,
            copado__User_Story__c = getUserStory().Id
        );

        insert new List<copado__Test__c>{ userStoryTest };
    }

    private static void createRelatedResults(Id parentId, Id promotionId) {
        List<copado__Result__c> results = new List<copado__Result__c>();
        List<copado__Test__c> tests = new TestsSelector().byParentAndAutomaticallyExecutableTests(parentId);

        for (copado__Test__c test : tests) {
            results.add(createResult(test.Id));
        }
        insert results;

        copado__JobExecution__c jobExecution = (copado__JobExecution__c) new JobExecution()
            .promotionId(promotionId)
            .dataJson('{ "promotionId" : "' + promotionId + '", "testIds" : [ "' + tests[0].Id + '" ]}')
            .persist();
        tests[0].copado__LatestJobExecution__c = jobExecution.Id;
        update tests;
    }

    private static copado__Promotion__c createPromotion() {
        copado__User_Story__c userStory = getUserStory();
        copado__Promotion__c promotion = (copado__Promotion__c) new Promotion(
            getProject().Id, null, getEnvironment('dev1').Id, null, null
        ).add(new PromotedUserStory().userStory(userStory.Id))
            .persist();

        createRelatedResults(userStory.Id, promotion.Id);
        return promotion;
    }

    private static copado__Project__c getProject() {
        return [SELECT Id FROM copado__Project__c LIMIT 1];
    }

    private static copado__Environment__c getEnvironment(String envName) {
        return [SELECT Id FROM copado__Environment__c WHERE Name = :envName LIMIT 1];
    }

    private static copado__User_Story__c getUserStory() {
        return [SELECT Id FROM copado__User_Story__c LIMIT 1];
    }

    public static copado__Result__c createResult(Id testId) {
        return new copado__Result__c(
            copado__Status__c = 'Success',
            copado__Test__c = testId,
            copado__Job_Type__c = 'In Progress',
            copado__Start_Time__c = System.now()
        );
    }

    private static copado__ExtensionConfiguration__c createExtensionConfiguration() {
        copado__ExtensionConfiguration__c extensionConfig = new copado__ExtensionConfiguration__c(
            copado__ExtensionTool__c = 'Manual Tests',
            copado__ExtensionApplication__c = 'Test',
            copado__Active__c = true
        );

        insert extensionConfig;
        return extensionConfig;
    }

    private static User getRunAsUser() {
        return [SELECT Id FROM User WHERE Profile.Name = 'Standard User' ORDER BY CreatedDate DESC LIMIT 1];
    }
}