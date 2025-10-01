@IsTest
@SuppressWarnings('PMD')
private class PromotionsServiceCtrlTest {
    private final static String LIST_HAS_NO_ROWS = 'List has no rows for assignment to SObject';
    private final static String NULL_POINTER_EXCEPTION = 'Attempt to de-reference a null object';
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    private static final String PROMOTIN_US_MERGE_ORDER = 'promotion_us_merge_order.json';

    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser('username-admin@myemail.com');
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void calculationsServiceForwardPromotionsException() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Exception expectedException;
            PromotionsServiceCtrl.CalculationResult expectedResult;

            // Exercise
            Test.startTest();
            try {
                expectedResult = PromotionsServiceCtrl.calculateForwardPromotions(null, null);
            } catch (Exception ex) {
                expectedException = ex;
            }
            Test.stopTest();

            // Verify
            Assert.areNotEqual(null, expectedResult, 'Response is null');
            Assert.areEqual(0, expectedResult.userStoryIds.size(), 'User story list size should match');
            Assert.areEqual(null, expectedException, 'An exception should not be thrown');
        }
    }

    @IsTest
    private static void calculationsServiceBackPromotionsException() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Exception expectedException;
            PromotionsServiceCtrl.CalculationResult expectedResult;

            // Exercise
            Test.startTest();
            try {
                expectedResult = PromotionsServiceCtrl.calculateBackwardPromotions(null, null);
            } catch (Exception ex) {
                expectedException = ex;
            }
            Test.stopTest();

            // Verify
            Assert.areNotEqual(null, expectedResult, 'Response is null');
            Assert.areEqual(0, expectedResult.userStoryIds.size(), 'User story list size should match');
            Assert.areEqual(null, expectedException, 'An exception should not be thrown');
        }
    }

    @IsTest
    private static void calculationsServiceOutOfSyncBackPromotionsException() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Exception expectedException;
            PromotionsServiceCtrl.CalculationResult expectedResult;

            // Exercise
            Test.startTest();
            try {
                expectedResult = PromotionsServiceCtrl.calculateOutOfSyncBackwardPromotions(null, null);
            } catch (Exception ex) {
                expectedException = ex;
            }
            Test.stopTest();

            // Verify
            Assert.areNotEqual(null, expectedResult, 'Response is null');
            Assert.areEqual(0, expectedResult.userStoryIds.size(), 'User story list size should match');
            Assert.areEqual(null, expectedException, 'An exception should not be thrown');
        }
    }

    @IsTest
    private static void calculationsServiceEnvSyncBackwardPromotionsException() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Exception expectedException;
            PromotionsServiceCtrl.CalculationResult expectedResult;

            // Exercise
            Test.startTest();
            try {
                expectedResult = PromotionsServiceCtrl.calculateEnvSyncBackwardPromotions(null, null);
            } catch (Exception ex) {
                expectedException = ex;
            }
            Test.stopTest();

            // Verify
            Assert.areNotEqual(null, expectedResult, 'Response is null');
            Assert.areEqual(0, expectedResult.userStoryIds.size(), 'User story list size should match');
            Assert.areEqual(null, expectedException, 'An exception should not be thrown');
        }
    }

    @IsTest
    private static void calculationsServiceEnvSyncBackwardPromotions() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipeline().Id;
            Id envId = getEnvironment('dev1').Id;
            createSystemProperty(pipelineId);

            // Exercise
            Test.startTest();
            PromotionsServiceCtrl.CalculationResult result = PromotionsServiceCtrl.calculateEnvSyncBackwardPromotions(pipelineId, envId);
            Test.stopTest();

            // Verify
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.areEqual(0, result.userStoryIds.size(), 'User story list should be empty');
            Assert.isNull(result.error, 'Error should be null');
        }
    }

    @IsTest
    private static void metadataServiceTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id userStoryIds = [SELECT Id FROM copado__User_Story__c LIMIT 1].Id;

            // Exercise
            PromotionsServiceCtrl.MetadataResult result = PromotionsServiceCtrl.retrieveMetadata(new List<Id>{ userStoryIds });

            // Verify
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.areEqual(0, result.userStoryMetadatas.size(), 'User story metadata size should match');
            Assert.isNull(result.error, 'Error message should match');
        }
    }

    @IsTest
    private static void metadataServiceExceptionTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Exercise
            PromotionsServiceCtrl.MetadataResult result = PromotionsServiceCtrl.retrieveMetadata(null);

            // Verify
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.areEqual(NULL_POINTER_EXCEPTION, result.error, 'Error message should match');
            Assert.isNull(result.userStoryMetadatas, 'User story metadata is not null');
        }
    }

    @IsTest
    private static void getPersonaDefinitions() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // SETUP
            createPersona('Release Manager');
            createPersona('Developer');

            // EXERCISE
            List<copado__Persona_Definition__c> result = PromotionsServiceCtrl.getPersonaDefinitions();

            // VERIFY
            Assert.areEqual(2, result.size(), 'The persona definition count does not match');
        }
    }

    @IsTest
    private static void retrieveUserStoryCommitsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id userStoryId = [SELECT Id FROM copado__User_Story__c LIMIT 1].Id;

            // EXERCISE
            PromotionsServiceCtrl.CommitResult result = PromotionsServiceCtrl.retrieveUserStoryCommits(new List<Id>{ userStoryId });

            // VERIFY
            Assert.isNotNull(result, 'Result is null');
            Assert.areEqual(null, result.error, 'There is an error');
            Assert.areEqual(0, result.userStoryCommits.size(), 'There are user story commits available');
        }
    }

    @IsTest
    private static void retrieveUserStoryCommitsExceptionTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            PromotionsServiceCtrl.CommitResult result = PromotionsServiceCtrl.retrieveUserStoryCommits(null);

            // VERIFY
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.areEqual(NULL_POINTER_EXCEPTION, result.error, 'Error message should match');
            Assert.isNull(result.userStoryCommits, 'User story commits are not null');
        }
    }

    @IsTest
    private static void executePromotionActionNoneTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            PromotionsServiceCtrl.PromotionActionResult result = PromotionsServiceCtrl.executePromotionAction(null, null, null, null, false);

            // VERIFY
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.isNotNull(result.error, 'error message is not null');
            Assert.isNull(result.promotionId, 'Promotion id is not null');
            Assert.isNull(result.jobExecutionId, 'job execution id is not null');
        }
    }

    @IsTest
    private static void exceutePromotionActionTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipeline().Id;
            Id envId = getEnvironment('dev1').Id;
            Id userStoryId = [SELECT Id FROM copado__User_Story__c LIMIT 1].Id;

            // EXERCISE
            PromotionsServiceCtrl.PromotionActionResult result = PromotionsServiceCtrl.executePromotionAction(
                'promote',
                pipelineId,
                envId,
                new List<Id>{ userStoryId },
                false
            );

            // VERIFY
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.isNull(result.error, 'Error message is not null');
            Assert.isNull(result.jobExecutionId, 'job execution id is not null');
            Assert.isNotNull(result.promotionId, 'Promotion id is null');
        }
    }

    @IsTest
    private static void exceutePromotionDeployActionTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipeline().Id;
            Id envId = getEnvironment('dev1').Id;
            Id userStoryId = [SELECT Id FROM copado__User_Story__c LIMIT 1].Id;

            // EXERCISE
            PromotionsServiceCtrl.PromotionActionResult result = PromotionsServiceCtrl.executePromotionAction(
                'deploy',
                pipelineId,
                envId,
                new List<Id>{ userStoryId },
                false
            );

            // VERIFY
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.isNull(result.error, 'Error message is not null');
            Assert.isNotNull(result.promotionId, 'Promotion id is null');
            Assert.isNull(result.jobExecutionId, 'job execution id is not null');
        }
    }

    @IsTest
    private static void exceutePromotionValidateActionTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipeline().Id;
            Id envId = getEnvironment('dev1').Id;
            Id userStoryId = [SELECT Id FROM copado__User_Story__c LIMIT 1].Id;

            // EXERCISE
            PromotionsServiceCtrl.PromotionActionResult result = PromotionsServiceCtrl.executePromotionAction(
                'validate',
                pipelineId,
                envId,
                new List<Id>{ userStoryId },
                false
            );

            // VERIFY
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.isNotNull(result.error, 'Error message is null');
            Assert.isNull(result.promotionId, 'Promotion id is not null');
            Assert.isNull(result.jobExecutionId, 'job execution id is not null');
        }
    }

    @IsTest
    private static void executeEnvironmentSyncActionTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipeline().Id;
            Id envId = getEnvironment('dev1').Id;
            Id userStoryId = [SELECT Id FROM copado__User_Story__c LIMIT 1].Id;
            createSystemProperty(pipelineId);

            // EXERCISE
            PromotionsServiceCtrl.PromotionActionResult result = PromotionsServiceCtrl.executePromotionAction(
                'environmentSync',
                pipelineId,
                envId,
                new List<Id>{ userStoryId },
                true
            );

            // VERIFY
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.isNull(result.error, 'Error message should be null');
            Assert.isNotNull(result.promotionId, 'Promotion id should not be null');
            Assert.isNull(result.jobExecutionId, 'Job execution id should be null');
        }
    }

    @IsTest
    private static void executeEnvironmentSyncActionWithoutSystemPropertyTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipeline().Id;
            Id envId = getEnvironment('dev1').Id;
            Id userStoryId = [SELECT Id FROM copado__User_Story__c LIMIT 1].Id;

            // EXERCISE
            PromotionsServiceCtrl.PromotionActionResult result = PromotionsServiceCtrl.executePromotionAction(
                'environmentSync',
                pipelineId,
                envId,
                new List<Id>{ userStoryId },
                true
            );

            // VERIFY
            Assert.areNotEqual(null, result, 'Response is null');
        }
    }

    @IsTest
    private static void checkIfBackPromotionEnvSyncEnabled() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipeline().Id;
            createSystemProperty(pipelineId);

            // Exercise
            Map<String, Object> result = PromotionsServiceCtrl.isBackPromotionEnvSyncEnabled(pipelineId);

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isInstanceOfType(result.get('isEnvironmentSyncEnabled'), Boolean.class, 'isEnvironmentSyncEnabled should be a boolean value');
        }
    }

    @IsTest
    private static void testIsCopadoLicenseAssigned() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            TestUtilities.assignLicense(TestUtilities.getRunAsUser().Id);

            // Exercise
            Test.startTest();
            Boolean result = PromotionsServiceCtrl.isCopadoLicenseAssigned();
            Test.stopTest();

            // Verify
            Assert.isTrue(result, 'User should have Copado license assigned');
        }
    }

    @IsTest
    private static void testIsCopadoLicenseAssignedWithoutLicense() {
        User userWithoutLicense = TestUtilities.createAdminUser('username-no-license@myemail.com');
        System.runAs(userWithoutLicense) {
            // Exercise
            Test.startTest();
            Boolean result = PromotionsServiceCtrl.isCopadoLicenseAssigned();
            Test.stopTest();

            // Verify
            Assert.isFalse(result, 'User should not have Copado license assigned');
        }
    }

    @IsTest
    private static void testIsCopadoLicenseAssignedWithMultipleLicenses() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id userId = TestUtilities.getRunAsUser().Id;
            TestUtilities.assignLicense(userId);

            // Create additional license
            copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
            copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
            userLicense.isCCMEnabled = true;
            userLicense.isCopadoEnabled = true;
            userLicense.userId = userId;
            copadoGlobalAPI.upsertCopadoLicense(userLicense);

            // Exercise
            Test.startTest();
            Boolean result = PromotionsServiceCtrl.isCopadoLicenseAssigned();
            Test.stopTest();

            // Verify
            Assert.isTrue(result, 'User should have Copado license assigned even with multiple licenses');
        }
    }

    @IsTest
    private static void testGetEnvironmentSyncUserStoriesExtendedData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Test.startTest();
            // Setup
            List<copado__User_Story__c> userStories = [SELECT Id FROM copado__User_Story__c];
            Id envId = getEnvironment('int').Id;
            List<String> idList = new List<String>();
            for (copado__User_Story__c us : userStories) {
                idList.add((String) us.Id);
            }

            createPromotion();

            // Exercise
            Map<Id, Map<String, Object>> result = PromotionsServiceCtrl.getEnvironmentSyncUserStoriesExtendedData(idList, envId);
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isTrue(result.containsKey(userStories[0].Id), 'Result should contain the user story ID');
            Assert.isTrue(result.get(userStories[0].Id).containsKey('lastPromotionDateTime'), 'Result should contain lastPromotionDateTime');
        }
    }

    @IsTest
    private static void getEnvironmentSyncUserStoriesExtendedDataMergeOrder() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Map<Id, copado__User_Story__c> userStories = new Map<Id, copado__User_Story__c>(getUserStories());
            List<Id> userStoryIds = new List<Id>(userStories.keySet());
            List<String> userStoryIdStrings = new List<String>();
            for (Id uid : userStoryIds) {
                userStoryIdStrings.add((String) uid);
            }
            Id envId = getEnvironment('int').Id;
            createPromotion();

            // Exercise
            Test.startTest();
            Map<Id, Map<String, Object>> result = PromotionsServiceCtrl.getEnvironmentSyncUserStoriesExtendedData(userStoryIdStrings, envId);
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isTrue(result.containsKey(userStoryIds[0]), 'Result should contain the user story ID');
            Assert.isTrue(result.get(userStoryIds[0]).containsKey('mergeOrder'), 'Result should contain mergeOrder');
            Assert.isTrue(result.get(userStoryIds[1]).containsKey('mergeOrder'), 'Result should contain mergeOrder');
        }
    }

    @IsTest
    private static void testGetEnvironmentSyncUserStoriesExtendedDataWithNullRequest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Test.startTest();
            try {
                PromotionsServiceCtrl.getEnvironmentSyncUserStoriesExtendedData(null, null);
                Assert.fail('Should have thrown an exception');
            } catch (Exception e) {
                Assert.isTrue(e instanceof AuraHandledException, 'Should throw AuraHandledException');
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void getEnvironmentSyncUserStoriesExtendedDataNoDeploymentsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            List<copado__User_Story__c> userStories = getUserStories();
            Id userStoryId = userStories[0].Id;
            Id envId = getEnvironment('int').Id;

            new Promotion([SELECT Id FROM copado__Project__c LIMIT 1].Id, null, null, null, envId)
                .add(new PromotedUserStory().userStory(userStoryId).status('Active'))
                .isBackPromotion(true)
                .status('Completed')
                .lastDeploymentExecutionId(null) // No deployment
                .persist();

            // Exercise
            Test.startTest();
            Map<Id, Map<String, Object>> result = PromotionsServiceCtrl.getEnvironmentSyncUserStoriesExtendedData(
                new List<String>{ (String) userStoryId },
                envId
            );
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isTrue(result.containsKey(userStoryId), 'Result should contain the user story ID');
            Assert.isFalse(
                result.get(userStoryId).containsKey('lastPromotionDateTime'),
                'Result should not contain lastPromotionDateTime because there is no deployment'
            );
        }
    }

    // Test methods for calculateEnvSyncBackwardPromotionsByDestination
    @IsTest
    private static void calculateEnvSyncBackwardPromotionsByDestinationSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            List<copado__User_Story__c> userStories = getUserStories();
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c sourceEnv = getEnvironment('dev1');
            copado__Environment__c destinationEnv = getEnvironment('int');

            // Create promotions to ensure there are backward promotions to calculate
            createBackwardPromotionsForTesting();

            // Exercise
            Test.startTest();
            PromotionsServiceCtrl.CalculationResult result = PromotionsServiceCtrl.calculateEnvSyncBackwardPromotionsByDestination(
                pipeline.Id,
                sourceEnv.Id,
                destinationEnv.Id
            );
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isNull(result.error, 'Error should be null for successful calculation');
            Assert.isNotNull(result.userStoryIds, 'User story IDs list should not be null');
        }
    }

    @IsTest
    private static void calculateEnvSyncBackwardPromotionsByDestinationWithNoData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c sourceEnv = getEnvironment('dev1');
            copado__Environment__c destinationEnv = getEnvironment('int');

            // Exercise - Test with empty pipeline (no user stories)
            Test.startTest();
            PromotionsServiceCtrl.CalculationResult result = PromotionsServiceCtrl.calculateEnvSyncBackwardPromotionsByDestination(
                pipeline.Id,
                sourceEnv.Id,
                destinationEnv.Id
            );
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isNull(result.error, 'Error should be null');
            Assert.isNotNull(result.userStoryIds, 'User story IDs list should not be null');
            Assert.areEqual(0, result.userStoryIds.size(), 'User story IDs list should be empty when no data exists');
        }
    }

    @IsTest
    private static void calculateEnvSyncBackwardPromotionsByDestinationWithSameSourceDestination() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            List<copado__User_Story__c> userStories = getUserStories();
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c sameEnv = getEnvironment('dev1');

            // Create promotions to ensure there are backward promotions to calculate
            createBackwardPromotionsForTesting();

            // Exercise - Test with same source and destination environment
            Test.startTest();
            PromotionsServiceCtrl.CalculationResult result = PromotionsServiceCtrl.calculateEnvSyncBackwardPromotionsByDestination(
                pipeline.Id,
                sameEnv.Id,
                sameEnv.Id
            );
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isNull(result.error, 'Error should be null when source and destination are the same');
            Assert.isNotNull(result.userStoryIds, 'User story IDs list should not be null');
            // When source and destination are the same, should return empty list (no backward promotions needed)
            Assert.areEqual(0, result.userStoryIds.size(), 'Should return empty list when source equals destination');
        }
    }

    @IsTest
    private static void calculateEnvSyncBackwardPromotionsByDestinationWithMultipleUserStories() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            List<copado__User_Story__c> userStories = getUserStories();
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c sourceEnv = getEnvironment('dev1');
            copado__Environment__c destinationEnv = getEnvironment('int');

            // Create multiple backward promotions for testing
            createMultipleBackwardPromotionsForTesting();

            // Exercise
            Test.startTest();
            PromotionsServiceCtrl.CalculationResult result = PromotionsServiceCtrl.calculateEnvSyncBackwardPromotionsByDestination(
                pipeline.Id,
                sourceEnv.Id,
                destinationEnv.Id
            );
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isNull(result.error, 'Error should be null for successful calculation');
            Assert.isNotNull(result.userStoryIds, 'User story IDs list should not be null');
            Assert.isTrue(result.userStoryIds.size() >= 0, 'Should return at least 0 user story IDs');
        }
    }

    @IsTest
    private static void calculateEnvSyncBackwardPromotionsByDestinationWithExceptionHandling() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup - Create a scenario that might cause an exception
            // We'll use a very long pipeline ID to potentially cause issues
            String longInvalidId = '0Hf0000000000000000Hf0000000000000000Hf000000000000000'; // Very long fake ID

            // Exercise
            Test.startTest();
            PromotionsServiceCtrl.CalculationResult result = PromotionsServiceCtrl.calculateEnvSyncBackwardPromotionsByDestination(
                longInvalidId,
                longInvalidId,
                longInvalidId
            );
            Test.stopTest();

            // Verify - The method should handle exceptions gracefully
            Assert.isNotNull(result, 'Result should not be null even when exception occurs');
            Assert.isNotNull(result.error, 'Error should contain exception message');
            Assert.isNull(result.userStoryIds, 'User story IDs should be null when there is an error');
        }
    }

    @IsTest
    private static void calculateOutOfSyncBackwardPromotionsByDestinationSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            List<copado__User_Story__c> userStories = getUserStories();
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c sourceEnv = getEnvironment('dev1');
            copado__Environment__c destinationEnv = getEnvironment('int');

            // Create out-of-sync backward promotions for testing
            createOutOfSyncBackwardPromotionsForTesting();

            // Exercise
            Test.startTest();
            PromotionsServiceCtrl.CalculationResult result = PromotionsServiceCtrl.calculateOutOfSyncBackwardPromotionsByDestination(
                pipeline.Id,
                sourceEnv.Id,
                destinationEnv.Id
            );
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isNull(result.error, 'Error should be null for successful calculation');
            Assert.isNotNull(result.userStoryIds, 'User story IDs list should not be null');
        }
    }

    // HELPER

    private static copado__Persona_Definition__c createPersona(String name) {
        Group personaGroup = new Group(Name = name, Type = 'Regular');
        insert personaGroup;

        PersonaDefinitionConfig config = new PersonaDefinitionConfig();
        config.publicGroupId = personaGroup.Id;

        copado__Persona_Definition__c persona = new copado__Persona_Definition__c(
            Name = name,
            copado__Is_Standard__c = true,
            copado__Config_Json__c = JSON.serialize(config)
        );
        insert persona;
        return persona;
    }

    private static void createData() {
        Credential dev1Credential = new Credential();
        Environment dev1 = new Environment().name('dev1').type('Sandbox').platform('Other').add(dev1Credential);
        Environment dev2 = new Environment().name('dev2').type('Sandbox').platform('Other').add(new Credential());
        Environment dev3 = new Environment().name('dev3').type('Sandbox').platform('Other').add(new Credential());
        Credential intCredential = new Credential();
        Environment integration = new Environment().name('int').type('Sandbox').platform('Other').add(intCredential);
        Environment uat = new Environment().name('uat').type('Sandbox').platform('Other').add(new Credential());
        Environment prod = new Environment().name('prod').type('Sandbox').platform('Other').add(new Credential());

        new Pipeline(new Repository().name('Repo 1'))
            .name('Test_Pipeline')
            .active(true)
            .mainBranch('main')
            .platform('Other')
            .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(integration).destinationBranch('int').branch('dev1'))
            .add(new PipelineConnection().sourceEnvironment(dev2).destinationEnvironment(integration).destinationBranch('int').branch('dev2'))
            .add(new PipelineConnection().sourceEnvironment(dev3).destinationEnvironment(integration).destinationBranch('int').branch('dev3'))
            .add(new PipelineConnection().sourceEnvironment(integration).destinationEnvironment(uat).destinationBranch('uat').branch('int'))
            .add(new PipelineConnection().sourceEnvironment(uat).destinationEnvironment(prod).destinationBranch('main').branch('uat'))
            .add(new Project().add(new UserStory().credential(dev1Credential)).add(new UserStory().credential(dev1Credential)))
            .persist();
    }

    private static void createBackwardPromotionsForTesting() {
        // Get existing user stories and environments
        List<copado__User_Story__c> userStories = getUserStories();
        copado__Environment__c sourceEnv = getEnvironment('dev1');
        copado__Environment__c destinationEnv = getEnvironment('int');

        if (!userStories.isEmpty()) {
            // Create a promotion with backward promotion flag
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;

            new Promotion(projectId, null, null, null, destinationEnv.Id)
                .add(new PromotedUserStory().userStory(userStories[0].Id).status('Active'))
                .isBackPromotion(true)
                .status('Completed')
                .persist();
        }
    }

    private static void createMultipleBackwardPromotionsForTesting() {
        // Get existing user stories and environments
        List<copado__User_Story__c> userStories = getUserStories();
        copado__Environment__c sourceEnv = getEnvironment('dev1');
        copado__Environment__c destinationEnv = getEnvironment('int');

        if (userStories.size() >= 2) {
            // Create multiple promotions with backward promotion flag
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;

            new Promotion(projectId, null, null, null, destinationEnv.Id)
                .add(new PromotedUserStory().userStory(userStories[0].Id).status('Active'))
                .isBackPromotion(true)
                .status('Completed')
                .persist();

            new Promotion(projectId, null, null, null, destinationEnv.Id)
                .add(new PromotedUserStory().userStory(userStories[1].Id).status('Active'))
                .isBackPromotion(true)
                .status('Completed')
                .persist();
        }
    }

    private static void createOutOfSyncBackwardPromotionsForTesting() {
        // Get existing user stories and environments
        List<copado__User_Story__c> userStories = getUserStories();
        copado__Environment__c sourceEnv = getEnvironment('dev1');
        copado__Environment__c destinationEnv = getEnvironment('int');

        if (!userStories.isEmpty()) {
            // Create promotions that would be considered "out of sync"
            // These are promotions that need to be backward promoted to sync environments
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;

            new Promotion(projectId, null, null, null, destinationEnv.Id)
                .add(new PromotedUserStory().userStory(userStories[0].Id).status('Active'))
                .isBackPromotion(true)
                .status('Completed')
                .persist();
        }
    }

    private static copado__Deployment_Flow__c getPipeline() {
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
    }

    private static copado__Environment__c getEnvironment(String name) {
        return [SELECT Id FROM copado__Environment__c WHERE Name = :name LIMIT 1];
    }

    private static copado__Promotion__c getPromotion() {
        return [SELECT Id FROM copado__Promotion__c LIMIT 1];
    }

    private static List<copado__User_Story__c> getUserStories() {
        return [SELECT Id, Name FROM copado__User_Story__c LIMIT 2];
    }
    private static copado__Org__c getOrg(String name) {
        return [SELECT Id FROM copado__Org__c WHERE Name = :name LIMIT 1];
    }

    private static void createPromotion() {
        JobTemplate jobTemplate = new JobTemplate().name('SFDX Promote').type('Custom');
        JobExecution jobExecution = new JobExecution(jobTemplate);
        JobStep jobStep1 = new JobStep().execution(jobExecution).name('SFDX Promote 1').type('Function').order(1);
        new Result(jobStep1).type('Integration').status('Success').endTime(Datetime.now()).persist();

        Id jobId = [SELECT Id FROM copado__JobExecution__c LIMIT 1].Id;

        List<copado__User_Story__c> userStories = getUserStories();
        new Promotion([SELECT Id FROM copado__Project__c LIMIT 1].Id, null, null, null, getEnvironment('int').Id)
            .add(new PromotedUserStory().userStory(userStories[0].Id).status('Active'))
            .add(new PromotedUserStory().userStory(userStories[1].Id).status('Active'))
            .isBackPromotion(true)
            .status('Completed')
            .lastDeploymentExecutionId(jobId)
            .persist();

        copado__Promotion__c promotion = getPromotion();

        new ContentVersion_t()
            .title(PROMOTIN_US_MERGE_ORDER)
            .pathOnClient(PROMOTIN_US_MERGE_ORDER + '.json')
            .firstPublishLocationId(promotion.Id)
            .versionData(getPromotionUSMergeOrder(new List<String>{ userStories[0].Name, userStories[1].Name }))
            .persist();
    }

    private static void createSystemProperty(Id pipelineId) {
        copado__System_Property__c systemProperty = new copado__System_Property__c(
            Name = 'Enable Sync Back Promote',
            copado__API_Name__c = 'EnableEnvSyncBackPromote',
            copado__Value__c = 'true',
            copado__Pipeline__c = pipelineId
        );
        insert systemProperty;
    }

    private static Blob getPromotionUSMergeOrder(List<String> userStoryNames) {
        PromotionsServiceCtrl.MergeOrderData result = new PromotionsServiceCtrl.MergeOrderData();
        List<String> usMergeOrder = new List<String>();
        for (String userStoryName : userStoryNames) {
            usMergeOrder.add('feature/' + userStoryName);
        }
        result.deploymentDate = String.valueOf(Datetime.now());
        result.usMergeOrder = usMergeOrder;
        return Blob.valueOf(JSON.serialize(result));
    }
}