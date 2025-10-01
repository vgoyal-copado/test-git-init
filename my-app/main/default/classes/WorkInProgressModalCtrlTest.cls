@IsTest
private with sharing class WorkInProgressModalCtrlTest {
    private static final String ENV_SYNC_BACK_PROMOTE_OVERRIDE_DESTINATION_CHANGES = 'Env_Sync_Back_Promote_Override_Destination_Changes';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void getData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();

            // EXERCISE
            Test.startTest();
            WorkInProgressModalCtrl.WorkInProgressData data = WorkInProgressModalCtrl.getData(pipeline.Id);
            Test.stopTest();

            // VERIFY
            Assert.areEqual(5, data.environments.size(), 'Should return 5 environments');
            Assert.areEqual(3, data.currentWorkInProgressEnvironments.size(), 'Should return 3 current work in progress environments');
        }
    }

    @IsTest
    private static void getWorkInProgressEnvironmentCount() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();

            // EXERCISE
            Test.startTest();
            Integer count = WorkInProgressModalCtrl.getWorkInProgressEnvironmentCount(pipeline.Id);
            Test.stopTest();

            // VERIFY
            Assert.areEqual(3, count, 'Should return 3 work in progress environments');
        }
    }

    @IsTest
    private static void saveWorkInProgressSettings() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            Set<Id> environmentIds = getEnvironmentIds(new Set<String>{ 'int', 'uat' });

            // EXERCISE
            Test.startTest();
            WorkInProgressModalCtrl.saveWorkInProgressSettings(pipeline.Id, new List<Id>(environmentIds));
            Test.stopTest();

            // VERIFY
            Assert.areEqual(
                2,
                [
                    SELECT COUNT()
                    FROM copado__System_Property__c
                    WHERE copado__Environment__c IN :environmentIds AND copado__API_Name__c = :ENV_SYNC_BACK_PROMOTE_OVERRIDE_DESTINATION_CHANGES
                ],
                'Should create 2 system properties'
            );
        }
    }

    // HELPER METHODS

    private static void createData() {
        Stage devStage = new Stage().name('Dev').metaStage('Build');
        Stage testStage = new Stage().name('Test').metaStage('Test');
        Stage productionStage = new Stage().name('Production').metaStage('Production');

        Environment dev1 = new Environment().name('dev1').type('Sandbox').platform('SFDX').add(new Credential());
        Environment dev2 = new Environment().name('dev2').type('Sandbox').platform('SFDX').add(new Credential());
        Environment integration = new Environment().name('int').type('Sandbox').platform('SFDX').add(new Credential());
        Environment uat = new Environment().name('uat').type('Sandbox').platform('SFDX').add(new Credential());
        Environment prod = new Environment().name('prod').type('Sandbox').platform('SFDX').add(new Credential());

        StageConnection devStageConnection = new StageConnection().stage(devStage);
        StageConnection testStageConnection = new StageConnection().stage(testStage);
        StageConnection productionStageConnection = new StageConnection().stage(productionStage);

        new Pipeline()
            .active(true)
            .mainBranch('main')
            .platform('SFDX')
            .add(
                new PipelineConnection()
                    .sourceEnvironment(dev1)
                    .destinationEnvironment(integration)
                    .branch('dev1')
                    .stageConnection(devStageConnection)
            )
            .add(
                new PipelineConnection()
                    .sourceEnvironment(dev2)
                    .destinationEnvironment(integration)
                    .branch('dev2')
                    .stageConnection(devStageConnection)
            )
            .add(
                new PipelineConnection().sourceEnvironment(integration).destinationEnvironment(uat).branch('int').stageConnection(devStageConnection)
            )
            .add(new PipelineConnection().sourceEnvironment(uat).destinationEnvironment(prod).branch('uat').stageConnection(testStageConnection))
            .add(devStageConnection)
            .add(testStageConnection)
            .add(productionStageConnection)
            .persist();

        new SystemProperty(getEnvironmentObj('dev1')).apiName(ENV_SYNC_BACK_PROMOTE_OVERRIDE_DESTINATION_CHANGES).value('true').persist();
        new SystemProperty(getEnvironmentObj('dev2')).apiName(ENV_SYNC_BACK_PROMOTE_OVERRIDE_DESTINATION_CHANGES).value('true').persist();
        new SystemProperty(getEnvironmentObj('int')).apiName(ENV_SYNC_BACK_PROMOTE_OVERRIDE_DESTINATION_CHANGES).value('true').persist();
    }

    private static copado__Deployment_Flow__c getPipeline() {
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
    }

    private static Set<Id> getEnvironmentIds(Set<String> environmentNames) {
        return new Map<Id, copado__Environment__c>([SELECT Id, Name FROM copado__Environment__c WHERE Name IN :environmentNames]).keySet();
    }

    private static copado__Environment__c getEnvironment(String name) {
        return [
            SELECT Id, Name
            FROM copado__Environment__c
            WHERE Name = :name
            LIMIT 1
        ];
    }

    private static Environment getEnvironmentObj(String name) {
        return new Environment().recordId(getEnvironment(name).Id);
    }
}