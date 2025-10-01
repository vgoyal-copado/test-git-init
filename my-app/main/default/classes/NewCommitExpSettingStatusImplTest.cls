@IsTest
private class NewCommitExpSettingStatusImplTest {
    
    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void statusNewCommitExpDeactivatedUnmetDeps() {
        System.runAs(TestUtilities.getRunAsUser()) {

            PipelineBuilderSettingsCtrl.mockCacheStatusResponse = '{"globalStatus": {"pipeline": {"pipelineStatus": "DEACTIVATED"}}}';
            createSystemProperty('vlocity_enabled', 'true');

            Test.startTest();
            PipelineSettings.NewCommitExpSettingStatusRequest request = new PipelineSettings.NewCommitExpSettingStatusRequest();
            request.pipelineId = getPipelineId();

            PipelineSettings.NewCommitExpSettingStatusResult result = PipelineSettings.NewCommitExpSetting.status(request);
            Test.stopTest();

            Assert.isFalse(result.status, 'New Commit Exp is deactivated.');
            Assert.areEqual(result.unmetDependencies.size(), 2, 'There should be both metacache and vlocity unmet dependencies');
        }
    }

    @isTest
    private static void statusNoUnmetDependencies() {

        System.runAs(TestUtilities.getRunAsUser()) {

            PipelineBuilderSettingsCtrl.mockCacheStatusResponse = '{"globalStatus": {"pipeline": {"pipelineStatus": "ACTIVATED"}}}';

            Test.startTest();
            PipelineSettings.NewCommitExpSettingStatusRequest request = new PipelineSettings.NewCommitExpSettingStatusRequest();
            request.pipelineId = getPipelineId();

            PipelineSettings.NewCommitExpSettingStatusResult result = PipelineSettings.NewCommitExpSetting.status(request);
            Test.stopTest();

            Assert.isFalse(result.status, 'New Commit Exp is not active active.');
            Assert.isTrue(result.unmetDependencies.isEmpty(), 'New Commit Exp has no unmet dependencies.');
            Assert.isNull(result.systemProperty, 'There is no new Commit Exp system property');
        }
    }

    // PRIVATE

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
        
            JobTemplate jobTemplate = new JobTemplate().name('SFDX Git Snapshot').type('Custom').apiName('SFDX_Git_Snapshot_1');
            new JobStep(jobTemplate).name('Snapshot').type('Function');
        
            Pipeline pipeline = new Pipeline().recordId(getPipelineId());
            new PipelineAction(pipeline).template(jobTemplate).action('TakeSnapshot').persist();
        }
    }

    private static Id getPipelineId(){
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
    }

    private static void createSystemProperty(String apiName, String value) {
        new SystemProperty(new Pipeline().recordId(getPipelineId())).apiName(apiName).value(value).persist();
    }
}