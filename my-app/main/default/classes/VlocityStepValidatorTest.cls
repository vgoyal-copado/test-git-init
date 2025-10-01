@IsTest
private class VlocityStepValidatorTest {
    
    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }
    
    @IsTest
    private static void skipVlocityStepWhenValidationIsRunningTest() {
        // SETUP

        System.runAs(TestUtilities.getRunAsUser()) {
            JobExecution jobExecution = new JobExecution(getJobTemplateObj('SFDX Vlocity Deploy'))
                .dataJSON(JSON.serialize(new Map<String, String>{
                    'deploymentDryRun' => 'true',
                    'fileWithSelectedChanges' => String.valueOf(getContentVersionId('Copado Deploy Changes.json'))
                }));
            SObject jobStep = getJobStepObj('Vlocity Deploy').execution(jobExecution).persist();
            
            // EXERCISE
            String result;
            Test.startTest();
            result = new VlocityStepValidator().execute(jobStep.Id);
            Test.stopTest();

            // VERIFY
            Assert.areEqual('true', result, 'Should return true when validation is running');
        }
    }
    
    @IsTest
    private static void throwErrorWhenInvalidFileIdTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            String mockFileId = TestUtilities.generateRandomString(18);
            JobExecution jobExecution = new JobExecution(getJobTemplateObj('SFDX Vlocity Deploy'))
            .dataJSON(JSON.serialize(new Map<String, String>{
                'deploymentDryRun' => 'false',
                'fileWithSelectedChanges' => mockFileId
            }));
            
            SObject jobStep = getJobStepObj('Vlocity Deploy').execution(jobExecution).persist();
            
            // EXERCISE
            String error;
            Test.startTest();
            try{
                new VlocityStepValidator().execute(jobStep.Id);
            } catch(Exception ex) {
                error = ex.getMessage();
            }
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(error, 'Should return exception when invalid file id');
        }
    }
    
    @IsTest
    private static void skipVlocityStepWithoutVlocityChanges() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            JobExecution jobExecution = new JobExecution(getJobTemplateObj('SFDX Vlocity Deploy'))
            .dataJSON(JSON.serialize(new Map<String, String>{
                'deploymentDryRun' => 'false',
                'fileWithSelectedChanges' => String.valueOf(getContentVersionId('Copado Deploy Changes1.json'))
            }));
            
            SObject jobStep = getJobStepObj('Vlocity Deploy').execution(jobExecution).persist();
            
            // EXERCISE
            String result;
            Test.startTest();
            result = new VlocityStepValidator().execute(jobStep.Id);
            Test.stopTest();
            
            // VERIFY
            Assert.areEqual('true', result, 'Should return true when no Vlocity changes exist, and step should be skipped.');
        }
    }
    
    @IsTest
    private static void executeVlocityStepWithVlocityChanges() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            JobExecution jobExecution = new JobExecution(getJobTemplateObj('SFDX Vlocity Deploy'))
            .dataJSON(JSON.serialize(new Map<String, String>{
                'deploymentDryRun' => 'false',
                'fileWithSelectedChanges' => String.valueOf(getContentVersionId('Copado Deploy Changes.json'))
            }));
            
            SObject jobStep = getJobStepObj('Vlocity Deploy').execution(jobExecution).persist();

            // EXERCISE
            String result;
            Test.startTest();
            result = new VlocityStepValidator().execute(jobStep.Id);
            Test.stopTest();
            
            // VERIFY
            Assert.areEqual('false', result, 'Should return false when no Vlocity changes exist');
        }
    }
    
    private static void createData() {
        new JobStep(new JobTemplate().name('SFDX Vlocity Deploy').type('Custom'))
            .name('Vlocity Deploy')
            .type('Function');

        addContentVersion('Copado Deploy Changes.json', getDeploymentChangesDataWithVlocity());
        addContentVersion('Copado Deploy Changes1.json', getDeploymentChangesDataWithoutVlocity());
    }

    private static JobTemplate getJobTemplateObj(String name) {
        return new JobTemplate().recordId(TestUtilities.getJobTemplate(name).Id);
    }

    private static JobStep getJobStepObj(String name) {
        return new JobStep().recordId(getJobStep(name).Id);
    }

    private static Id getContentVersionId(String title) {
        return [SELECT Id, Title, VersionData FROM ContentVersion WHERE Title = :title][0].Id;
    }

    private static copado__JobStep__c getJobStep(String name) {
        return [SELECT Name, Id FROM copado__JobStep__c WHERE Name = :name LIMIT 1];
    }

    private static void addContentVersion(String title, String data) {
        new ContentVersion_t().versionData(Blob.valueOf(data)).title(title).pathOnClient(title).persist();
    }

    private static String getDeploymentChangesDataWithVlocity() {
        List<MetaDataItem> result = new List<MetaDataItem>();
        result.add(TestDataFactory.getMetadataItem('ApexClass', 'Vlocity1', 'Test User', '2023-02-17T10:41:48.000+0000'));
        result.add(TestDataFactory.getMetadataItemWithCategory('DataRaptor', 'Vlocity2', 'Test User', '2023-02-17T10:41:48.000+0000', 'Vlocity'));
        return JSON.serialize(result);
    }

    private static String getDeploymentChangesDataWithoutVlocity() {
        List<MetaDataItem> result = new List<MetaDataItem>();
        result.add(TestDataFactory.getMetadataItem('ApexClass', 'VlocityApexClass1', 'Test User', '2023-02-17T10:41:48.000+0000'));
        result.add(TestDataFactory.getMetadataItem('ApexClass', 'VlocityApexClass2', 'Test User', '2023-02-17T10:41:48.000+0000'));
        return JSON.serialize(result);
    }
}