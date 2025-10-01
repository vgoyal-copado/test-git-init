@IsTest
private with sharing class PipelineBuilderEnvironmentCtrlTest {
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void validateEnvironment() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Environment__c environment = getEnvironment();

            // EXERCISE
            Test.startTest();
            PipelineBuilderEnvironmentCtrl.EnvironmentData data = PipelineBuilderEnvironmentCtrl.validateEnvironment(environment.Id);
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(data.isValidOrg, 'Validation status should be returned');
            Assert.isNotNull(data.credentialName, 'Credential Name should be returned');
        }
    }

    // HELPER

    private static void createData() {
        Stage devStage = new Stage().name('Dev').metaStage('Build');
        Stage testStage = new Stage().name('Test').metaStage('Test');
        Stage productionStage = new Stage().name('Production').metaStage('Production');

        Environment dev1 = new Environment().name('dev1').type('Sandbox').platform('Other').add(new Credential());
        Environment dev2 = new Environment().name('dev2').type('Sandbox').platform('Other').add(new Credential());
        Environment integration = new Environment().name('int').type('Sandbox').platform('Other').add(new Credential());
        Environment uat = new Environment().name('uat').type('Sandbox').platform('Other').add(new Credential());
        Environment prod = new Environment().name('prod').type('Sandbox').platform('Other').add(new Credential());

        StageConnection devStageConnection = new StageConnection().stage(devStage);
        StageConnection testStageConnection = new StageConnection().stage(testStage);
        StageConnection productionStageConnection = new StageConnection().stage(productionStage);

        new Pipeline()
            .active(true)
            .mainBranch('main')
            .platform('Other')
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

        copado__Stage_Connection__c devStageConnectionRecord = getStageConnections('Dev');
        copado__Stage_Connection__c testStageConnectionRecord = getStageConnections('Test');
        copado__Stage_Connection__c prodStageConnectionRecord = getStageConnections('Production');
        devStageConnectionRecord.copado__Next_Stage_Connection__c = testStageConnectionRecord.Id;
        testStageConnectionRecord.copado__Next_Stage_Connection__c = prodStageConnectionRecord.Id;
        update new List<copado__Stage_Connection__c>{ devStageConnectionRecord, testStageConnectionRecord };
    }

    private static copado__Environment__c getEnvironment() {
        return [SELECT Id FROM copado__Environment__c LIMIT 1];
    }

    private static copado__Stage_Connection__c getStageConnections(String stageName) {
        return [SELECT Id FROM copado__Stage_Connection__c WHERE copado__Stage__r.Name = :stageName];
    }
}