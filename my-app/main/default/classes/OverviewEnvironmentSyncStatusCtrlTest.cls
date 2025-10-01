@IsTest
private class OverviewEnvironmentSyncStatusCtrlTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    private static final String DEFAULT_REFRESH_VALUE = 'N/A';
    private static final String SYNCHED = 'synched';
    private static final String OUT_OF_SYNC = 'outofsync';

    @TestSetup
    static void setupTestData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Environment sourceEnv = TestUtilities.createEnvironment('DEV');
            Environment destEnv = TestUtilities.createEnvironment('QA');

            new Credential(sourceEnv)
                .name('DEV Credential')
                .default(true);
            new Credential(destEnv)
                .name('QA Credential')
                .default(true);

            Repository repo = TestUtilities.createRepository();
            Pipeline ppline = TestUtilities.createPipeline(repo, 'SFDX').active(true);
            new PipelineConnection(ppline, sourceEnv, destEnv);
            Project proj = new Project(ppline);

            new UserStory().project(proj).environment(sourceEnv);
            new UserStory().project(proj).environment(destEnv).persist();
        }
    }

    @IsTest
    static void testGetEnvironmentsTotalRecords() {
        // SETUP
        Integer totalRecords;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;

            // EXERCISE
            Test.startTest();
            totalRecords = OverviewEnvironmentSyncStatusCtrl.getEnvironmentsTotalRecords(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(2, totalRecords, 'Should return 2 environments');
    }

    @IsTest
    static void testGetEnvironments() {
        // SETUP
        List<OverviewEnvironmentSyncStatusCtrl.EnvironmentWrapper> results;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;
            lwcParams.offset = 0;
            lwcParams.queryLimit = 10;

            // EXERCISE
            Test.startTest();
            results = OverviewEnvironmentSyncStatusCtrl.getEnvironments(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(2, results.size(), 'Should return 2 environment wrappers');
        for(OverviewEnvironmentSyncStatusCtrl.EnvironmentWrapper wrapper : results) {
            Assert.isNotNull(wrapper.Id, 'The property Id should be fulfilled');
            Assert.isNotNull(wrapper.Name, 'The property Name should be fulfilled');
            Assert.isNotNull(wrapper.environmentUrl, 'The property environmentUrl should be fulfilled');
            Assert.areEqual(1, wrapper.userStories, 'The property userStories was not calculated properly');
            Assert.isNotNull(wrapper.type, 'The property type should be fulfilled');
            Assert.isNotNull(wrapper.lastRefreshDays, 'The property lastRefreshDays should be fulfilled');
        }
    }

    @IsTest
    static void testGetEnvironmentsWithSearch() {
        // SETUP
        List<OverviewEnvironmentSyncStatusCtrl.EnvironmentWrapper> results;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            Id projectId = [SELECT Id FROM copado__Project__c LIMIT 1].Id;
    
            OverviewPipelineTablesHelper.LwcParams lwcParams = new OverviewPipelineTablesHelper.LwcParams();
            lwcParams.selectedPipelineId = pipelineId;
            lwcParams.selectedProjectId = projectId;
            lwcParams.offset = 0;
            lwcParams.queryLimit = 10;
            lwcParams.searchTerm = 'QA';

            // EXERCISE
            Test.startTest();
            results = OverviewEnvironmentSyncStatusCtrl.getEnvironments(JSON.serialize(lwcParams));
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(1, results.size(), 'Should return 1 environment matching search term');
    }

    @IsTest
    static void testGetAuthenticationStatuses() {
        // SETUP
        Map<Id, String> authResults;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            List<Id> credentialIds = new List<Id>();
            for(copado__Org__c cred : [SELECT Id FROM copado__Org__c LIMIT 2]) {
                credentialIds.add(cred.Id);
            }

            // EXERCISE
            Test.startTest();
            authResults = OverviewEnvironmentSyncStatusCtrl.getAuthenticationStatuses(credentialIds);
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(2, authResults.size(), 'Should return 2 authentication results');
        for(String authResult : authResults.values()) {
            Assert.isTrue(authResult.equalsIgnoreCase('true'), 'The credential should be authenticated.');
        }
    }

    @IsTest
    static void testGetIsEnvironmentOutOfSync() {
        // SETUP
        Map<Id, String> syncResults;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            List<Id> environmentIds = new List<Id>();
            for(copado__Environment__c env : [SELECT Id FROM copado__Environment__c LIMIT 2]) {
                environmentIds.add(env.Id);
            }

            // EXERCISE
            Test.startTest();
            syncResults = OverviewEnvironmentSyncStatusCtrl.getIsEnvironmentOutOfSync(
                pipelineId, 
                environmentIds
            );
            Test.stopTest();
        }

        // VERIFY
        Assert.areEqual(2, syncResults.size(), 'Should return 2 status results');
        for(String syncStatus : syncResults.values()) {
            Assert.isTrue(
                syncStatus == 'synched' || syncStatus == 'outofsync', 
                'Sync status should be either synched or out of sync'
            );
        }
    }

    @IsTest
    static void testGetBackPromotionCounts() {
        // SETUP
        Map<Id, Integer> backPromoteCounts;
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Id pipelineId = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
            List<Id> environmentIds = new List<Id>();
            for(copado__Environment__c env : [SELECT Id FROM copado__Environment__c LIMIT 2]) {
                environmentIds.add(env.Id);
            }

            // EXERCISE
            Test.startTest();
            backPromoteCounts = OverviewEnvironmentSyncStatusCtrl.getBackPromotionCounts(
                pipelineId, 
                environmentIds
            );
            Test.stopTest();
        }

        // VERIFY
        Assert.isTrue(!backPromoteCounts.isEmpty(), 'Should return back promotion counts');
        for (Integer backPromoteCount : backPromoteCounts.values()) {
            Assert.areEqual(0, backPromoteCount, 'There should be no US pending for back promotion');
        }
    }
}