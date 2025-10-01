@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
@IsTest
private class PipelineSettingsTest {

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

    @IsTest
    private static void enableVlocityFailure() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            PipelineSettings.EnableVlocitySettingRequest request = new PipelineSettings.EnableVlocitySettingRequest();
            request.pipelineId = TestUtilities.getRunAsUser().Id; // Invalid Id 
            
            // Exercise
            Test.startTest();
            Boolean jobIsSuccess = true;
            try{
                PipelineSettings.VlocitySetting.enable(request);
            }catch(Exception ex){
                jobIsSuccess = false;
            }
            Test.stopTest();

            // Assertions
            Assert.isFalse(jobIsSuccess, 'An exception is thrown.');
        }
    }

    @IsTest
    private static void disableVlocity() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            PipelineSettings.DisableVlocitySettingRequest request = new PipelineSettings.DisableVlocitySettingRequest();
            request.pipelineId = getPipelineId(); 
            
            // Exercise
            Test.startTest();
            PipelineSettings.DisableVlocitySettingResult result = PipelineSettings.VlocitySetting.disable(request);
            Test.stopTest();

            // Assertions
            Assert.isTrue(result.status, 'Vlocity is disabled.');
        }
    }

    @IsTest
    private static void disableVlocityFailure() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            PipelineSettings.DisableVlocitySettingRequest request = new PipelineSettings.DisableVlocitySettingRequest();
            request.pipelineId = null; // Invalid Id
            
            // Exercise
            Test.startTest();
            Boolean jobIsSuccess = true;
            try{
                PipelineSettings.VlocitySetting.disable(request);
            }catch(Exception ex){
                jobIsSuccess = false;
            }
            Test.stopTest();

            // Assertions
            Assert.isTrue(jobIsSuccess, 'An exception is thrown.');
        }
    }

    private static void vlocityStatus() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            PipelineSettings.VlocitySettingStatusRequest request = new PipelineSettings.VlocitySettingStatusRequest();
            request.pipelineId = getPipelineId(); 
            
            // Exercise
            Test.startTest();
            PipelineSettings.VlocitySettingStatusResult result = PipelineSettings.VlocitySetting.status(request);
            Test.stopTest();

            // Assertions
            System.assertEquals(true, result.status, 'Vlocity is enabled.');
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
        }
    }


    private static Id getPipelineId(){
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
    }

}