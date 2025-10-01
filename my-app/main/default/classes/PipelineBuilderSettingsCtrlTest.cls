@IsTest
@SuppressWarnings('PMD.AvoidHardcodingId')
private class PipelineBuilderSettingsCtrlTest {
    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void vlocityStatusTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Exercise
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.vlocityStatus(pipelineId);
            Test.stopTest();

            // Assertions
            Assert.isFalse(result, 'Vlocity Status checked.');
        }
    }

    @IsTest
    private static void enableVlocity() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Exercise
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.enableVlocity(pipelineId);
            Test.stopTest();

            // Assertions
            Assert.isTrue(result, 'Vlocity is enabled.');
        }
    }

    @IsTest
    private static void disableVlocity() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Exercise
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.disableVlocity(pipelineId);
            Test.stopTest();

            // Assertions
            Assert.isTrue(result, 'Vlocity is disabled.');
        }
    }

    @IsTest
    private static void newCommitExpStatusTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Exercise
            Test.startTest();
            PipelineBuilderSettingsCtrl.mockCacheStatusResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "activated"}}}';
            PipelineSettings.NewCommitExpSettingStatusResult result = PipelineBuilderSettingsCtrl.newCommitExperienceStatus(pipelineId);
            Test.stopTest();

            // Assertions
            Assert.isFalse(result.status, 'New commit exp Status checked.');
        }
    }

    @IsTest
    private static void enableNewCommitExp() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Exercise
            Test.startTest();
            PipelineBuilderSettingsCtrl.mockCacheStatusResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "activated"}}}';
            Boolean result = PipelineBuilderSettingsCtrl.enableNewCommitExp(pipelineId);
            Test.stopTest();

            // Assertions
            Assert.isTrue(result, 'New commit exp is enabled.');
        }
    }

    @IsTest
    private static void disableNewCommitExp() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Exercise
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.disableNewCommitExp(pipelineId);
            Test.stopTest();

            // Assertions
            Assert.isTrue(result, 'New commit exp is disabled.');
        }
    }

    @IsTest
    private static void enableMetaCacheTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Mock response for disable provisioing
            PipelineBuilderSettingsCtrl.mockCacheProvisioningResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "provisioned"}}}';

            // Exercise
            Test.startTest();
            Map<String, Object> result = PipelineBuilderSettingsCtrl.enableMetaCache(pipelineId);
            Test.stopTest();

            // Assertions
            System.assertEquals('provisioned', getPipelineStatus(result), 'MetaCache should be provisioned.');
        }
    }

    @IsTest
    private static void disableMetaCacheTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Mock response for disable provisioing
            PipelineBuilderSettingsCtrl.mockCacheProvisioningResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "disabled"}}}';

            // Exercise
            Test.startTest();
            Map<String, Object> result = PipelineBuilderSettingsCtrl.disableMetaCache(pipelineId);
            Test.stopTest();

            // Assertions
            System.assertEquals(200, result.get('statusCode'), 'MetaCache should be disabled.');
        }
    }

    @IsTest
    private static void checkMetaCacheStatusTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();

            // Mock response for activated status
            PipelineBuilderSettingsCtrl.mockCacheStatusResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "activated"}}}';

            // Exercise
            Test.startTest();
            Map<String, Object> result = PipelineBuilderSettingsCtrl.checkMetaCacheStatus(pipelineId);
            Test.stopTest();

            // Assertions
            System.assertEquals('activated', getPipelineStatus(result), 'MetaCache should be activated.');
        }
    }

    @IsTest
    private static void checkCopadoAndMetaCachePermissionsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Exercise
            Test.startTest();
            PipelineBuilderSettingsCtrl.LicenseStatusWrapper wrapp = PipelineBuilderSettingsCtrl.checkCopadoAndMetaCachePermissions();
            Test.stopTest();

            // Assertions
            Assert.isTrue(wrapp.hasFeatureMetaCacheEnabled, 'MetaCache Feature is enabled.');
            Assert.isTrue(wrapp.hasCopadoAdminLicense, 'User has Copado Admin license.');
        }
    }

    @IsTest
    private static void validateAuthenticatedEnvironmentTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Environment__c environment = getEnvironment();

            // EXERCISE
            Test.startTest();
            PipelineBuilderSettingsCtrl.EnvironmentData data = PipelineBuilderSettingsCtrl.validateAuthenticatedEnvironment(environment.Id);
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(data.isValidOrg, 'Validation status should be returned');
            Assert.isNotNull(data.credentialName, 'Credential Name should be returned');
        }
    }

    @IsTest
    private static void getEnvironmentTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Environment__c environment = getEnvironment();
            List<Id> environmentIds = new List<Id>{ environment.Id };

            // EXERCISE
            Test.startTest();
            List<PipelineBuilderSettingsCtrl.EnvironmentData> data = PipelineBuilderSettingsCtrl.getEnvironmentNames(environmentIds);
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(data.get(0).environmentId, 'Environment Id should be returned');
            Assert.isNotNull(data.get(0).environmentName, 'Environment Name should be returned');
        }
    }

    @IsTest
    private static void environmentSyncStatusTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipelineId();

            // EXERCISE
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.environmentSyncStatus(pipelineId);
            Test.stopTest();

            // VERIFY
            Assert.isFalse(result, 'Environment Sync Status should be false');
        }
    }

    @IsTest
    private static void enableEnvironmentSyncTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipelineId();

            // EXERCISE
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.enableEnvironmentSync(pipelineId);
            Test.stopTest();

            // VERIFY
            Assert.isTrue(result, 'Environment Sync should be enabled');
        }
    }

    @IsTest
    private static void disableEnvironmentSyncTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id pipelineId = getPipelineId();

            // EXERCISE
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.disableEnvironmentSync(pipelineId);
            Test.stopTest();

            // VERIFY
            Assert.isTrue(result, 'Environment Sync should be disabled');
        }
    }

    @IsTest
    private static void backPromotionEnvSyncFeatureEnabledTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Test.startTest();
            Boolean result = PipelineBuilderSettingsCtrl.isBackPromotionEnvSyncFeatureEnabled();
            Test.stopTest();

            // VERIFY
            Assert.isFalse(result, 'Back Promotion Env Sync Feature should be disabled');
        }
    }

    @IsTest
    private static void shouldReturnEnvironmentsFromPipelineConnections() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Environment sourceEnv = new Environment().name('Dev Environment').type('Production/Developer').orgId('00D000000000001EAA');
            Environment destEnv = new Environment().name('QA Environment').type('Production/Developer').orgId('00D000000000002EAA');

            new Credential(sourceEnv);
            new Credential(destEnv);

            Repository repository = new Repository().name('Test Repository');
            Pipeline pipeline = new Pipeline(repository).name('Test Pipeline').platform('SFDX');

            new PipelineConnection(pipeline, sourceEnv, destEnv).persist();

            // EXERCISE
            Test.startTest();
            Map<Id, copado__Environment__c> result = new Map<Id, copado__Environment__c>();
            result = PipelineBuilderSettingsCtrl.getOrgsFromCacheStatusResponse(
                pipeline.Id,
                new List<Id>{ '00D000000000001EAA', '00D000000000002EAA' }
            );
            Test.stopTest();

            // VERIFY

            Assert.areEqual(2, result.size(), 'Should return environments for both source and destination orgs');
            for (copado__Environment__c env : result.values()) {
                Assert.isNotNull(env.Id, 'Environment Id should not be null');
                Assert.isNotNull(env.Name, 'Environment Name should not be null');
                if (env.id == sourceEnv.id) {
                    Assert.areEqual(env.id + env.Name, sourceEnv.id + 'Dev Environment', 'Environments should be rightly linked with copado org ids');
                }
                if (env.id == destEnv.Id) {
                    Assert.areEqual(env.id + env.Name, destEnv.id + 'QA Environment', 'Environments should be rightly linked with copado org ids');
                }
            }
        }
    }

    @IsTest
    private static void shouldReturnEmptyMapWhenNoMatchingConnections() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Map<Id, copado__Environment__c> result;
            List<Id> nonExistentOrgIds = new List<Id>{ '00D000000000999EAA' };
            result = PipelineBuilderSettingsCtrl.getOrgsFromCacheStatusResponse(getPipelineId(), nonExistentOrgIds);

            // VERIFY
            Assert.isNotNull(result, 'Result should not be null');
            Assert.areEqual(0, result.size(), 'Should return empty map when no matching connections found');
        }
    }

    @IsTest
    private static void shouldHandleEmptyCopadoOrgsList() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Map<Id, copado__Environment__c> result;
            result = PipelineBuilderSettingsCtrl.getOrgsFromCacheStatusResponse(getPipelineId(), new List<Id>());

            // VERIFY
            Assert.isNotNull(result, 'Result should not be null');
            Assert.areEqual(0, result.size(), 'Should return empty map when org list is empty');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Environment dev1 = new Environment().name('Dev1');
            Environment staging = new Environment().name('Staging');
            new Credential(dev1);
            new Credential(staging);

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(new Project())
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('staging').branch('dev1'))
                .persist();
        }
    }

    private static Id getPipelineId() {
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
    }

    private static copado__Environment__c getEnvironment() {
        return [SELECT Id FROM copado__Environment__c LIMIT 1];
    }

    private static String getPipelineStatus(Map<String, Object> result) {
        Map<String, Object> globalStatus = (Map<String, Object>) result.get('globalStatus');
        Map<String, Object> pipelineStatus = (Map<String, Object>) globalStatus.get('pipeline');
        return (String) pipelineStatus.get('pipelineStatus');
    }
}