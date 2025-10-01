@IsTest
private class EnableVlocitySettingImplTest {

    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void enableVlocity() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            PipelineSettings.EnableVlocitySettingRequest request = new PipelineSettings.EnableVlocitySettingRequest();
            request.pipelineId = getPipelineId(); 
            
            // Exercise
            Test.startTest();
            PipelineSettings.EnableVlocitySettingResult result = PipelineSettings.VlocitySetting.enable(request);
            Test.stopTest();

            // Assertions
            Assert.isTrue(result.status, 'Vlocity is enabled.');
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

            JobTemplate vlocityJobTemplate = new JobTemplate().name('SFDX Vlocity Git Snapshot').type('Custom').apiName('SFDX_Vlocity_Git_Snapshot_1');
            new JobStep(vlocityJobTemplate).name('Snapshot').type('Function');
        
            Pipeline pipeline = new Pipeline().recordId(getPipelineId());
            new PipelineAction(pipeline).template(jobTemplate).action('TakeSnapshot').persist();
        }
    }


    private static Id getPipelineId(){
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
    }

}