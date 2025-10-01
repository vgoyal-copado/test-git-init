@IsTest
private class EnableNewCommitExpSettingImplTest {
    
    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void enableNewCommitExp() {
        System.runAs(TestUtilities.getRunAsUser()) {

            // mock metacache is there
            PipelineBuilderSettingsCtrl.mockCacheStatusResponse = '{"globalStatus": {"pipeline": {"pipelineStatus": "ACTIVATED"}}}';

            Test.startTest();
            PipelineSettings.EnableNewCommitExpSettingRequest request = new PipelineSettings.EnableNewCommitExpSettingRequest();
            request.pipelineId = getPipelineId();

            PipelineSettings.EnableNewCommitExpSettingResult result = PipelineSettings.NewCommitExpSetting.enable(request);
            Test.stopTest();

            Assert.isTrue(result.status, 'New Commit Exp is enabled.');
        }
    }

    @IsTest
    private static void enableNewCommitExpFailBecauseUnmetDependencies() {
        
        System.runAs(TestUtilities.getRunAsUser()) {

            // mock metacache is pending
            PipelineBuilderSettingsCtrl.mockCacheStatusResponse = '{"globalStatus": {"pipeline": {"pipelineStatus": "DEACTIVATED"}}}';

            Test.startTest();
            PipelineSettings.EnableNewCommitExpSettingRequest request = new PipelineSettings.EnableNewCommitExpSettingRequest();
            request.pipelineId = getPipelineId();

            PipelineSettings.EnableNewCommitExpSettingResult result = PipelineSettings.NewCommitExpSetting.enable(request);
            Test.stopTest();

            Assert.isFalse(result.status, 'New Commit Exp is still disabled.');
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
}