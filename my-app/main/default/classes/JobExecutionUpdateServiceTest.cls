@IsTest
private class JobExecutionUpdateServiceTest {
    private static final String STATUS_FIELD = 'copado__Status__c';
    private static final String ERROR_MESSAGE_FIELD = 'copado__ErrorMessage__c';
    private static final String SOURCE_FIELD = 'copado__Source__c';
    private static final String DESTINATION_FIELD = 'copado__Destination__c';
    private static final String DATA_JSON_FIELD = 'copado__DataJson__c';

    private static final String NEW_STATUS = 'Success';
    private static final String NEW_ERROR_MESSAGE = 'Error message field';
    private static final String NEW_DATA_JSON = 'new Data Json';
    private static final String INVALID_FIELD = 'invalid_field__c';

    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void shouldUpdateJERecord() {
        
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            SObject jobExecution = new JobExecution().source(getEnvironmentObject('Source')).destination(getEnvironmentObject('Target')).dataJSON('old data json').persist();
            Id newSourceEnvId = getEnvironmentRecord('New Source').Id;
            Id newTargetEnvId = getEnvironmentRecord('New Target').Id;

            JobExecutionUpdateService.Request request = new JobExecutionUpdateService.Request();
            request.jobExecutionId = jobExecution.Id;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + STATUS_FIELD + '", "value" : "' + NEW_STATUS + '"},'+
            '{"fieldApiName" : "' + ERROR_MESSAGE_FIELD + '", "value" : "' + NEW_ERROR_MESSAGE + '"},'+
            '{"fieldApiName" : "' + SOURCE_FIELD + '", "value" : "' + newSourceEnvId + '"},'+
            '{"fieldApiName" : "' + DESTINATION_FIELD + '", "value" : "' + newTargetEnvId + '"},'+
            '{"fieldApiName" : "' + DATA_JSON_FIELD + '", "value" : "' + NEW_DATA_JSON + '"}]';

            // Exercise
            Test.startTest();
            JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__JobExecution__c updatedJE = getJobExecutionRecord(jobExecution.Id);
            System.assertEquals(NEW_STATUS, updatedJE.copado__Status__c, 'Status should be updated to the new value');
            System.assertEquals(NEW_ERROR_MESSAGE, updatedJE.copado__ErrorMessage__c, 'Progress status should be updated to the new value');
            System.assertEquals(newSourceEnvId, updatedJE.copado__Source__c, 'Progress status should be updated to the new value');
            System.assertEquals(newTargetEnvId, updatedJE.copado__Destination__c, 'Progress status should be updated to the new value');
            System.assertEquals(NEW_DATA_JSON, updatedJE.copado__DataJson__c, 'Progress status should be updated to the new value');
        }
    }

    @IsTest
    private static void shouldOnlyUpdateValueOfValidFieldName() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            SObject jobExecution = new JobExecution().source(getEnvironmentObject('Source')).destination(getEnvironmentObject('Target')).dataJSON('old data json').persist();

            JobExecutionUpdateService.Request request = new JobExecutionUpdateService.Request();
            request.jobExecutionId = jobExecution.Id;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + INVALID_FIELD + '", "value" : "' + NEW_STATUS + '"},{"fieldApiName" : "' + DATA_JSON_FIELD + '", "value" : "' + NEW_DATA_JSON + '"}]';

            // Exercise
            Test.startTest();
            JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__JobExecution__c updatedJE = getJobExecutionRecord(jobExecution.Id);
            System.assertEquals(null, updatedJE.copado__Status__c, 'Status should be updated to the new value');
            System.assertEquals(NEW_DATA_JSON, updatedJE.copado__DataJson__c, 'Progress status should be updated to the new value');
        }
    }

    @IsTest
    private static void shouldNotUpdateRecordWithNullJSON() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            SObject jobExecution = new JobExecution().source(getEnvironmentObject('Source')).destination(getEnvironmentObject('Target')).dataJSON('old data json').persist();

            JobExecutionUpdateService.Request request = new JobExecutionUpdateService.Request();
            request.jobExecutionId = jobExecution.Id;
            request.valuesToUpdateJson = null;

            // Exercise
            Test.startTest();
            JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__JobExecution__c updatedJE = getJobExecutionRecord(jobExecution.Id);
            System.assertEquals(null, updatedJE.copado__Status__c, 'Status should be updated to the new value');
            System.assertEquals(null, updatedJE.copado__ErrorMessage__c, 'Progress status should be updated to the new value');
            System.assertEquals(getEnvironmentRecord('Source').Id, updatedJE.copado__Source__c, 'Progress status should be updated to the new value');
            System.assertEquals(getEnvironmentRecord('Target').Id, updatedJE.copado__Destination__c, 'Progress status should be updated to the new value');
            System.assertEquals('old data json', updatedJE.copado__DataJson__c, 'Progress status should be updated to the new value');
        }
    }

    @IsTest
    private static void shouldNotUpdateWhenNullResultId() {
        
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            SObject jobExecution = new JobExecution().source(getEnvironmentObject('Source')).destination(getEnvironmentObject('Target')).dataJSON('old data json').persist();

            JobExecutionUpdateService.Request request = new JobExecutionUpdateService.Request();
            request.jobExecutionId = null;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + STATUS_FIELD + '", "value" : "' + NEW_STATUS + '"}]';

            // Exercise
            Test.startTest();
            JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__JobExecution__c updatedJE = getJobExecutionRecord(jobExecution.Id);
            System.assertEquals(null, updatedJE.copado__Status__c, 'Status should be updated to the new value');
            System.assertEquals(null, updatedJE.copado__ErrorMessage__c, 'Progress status should be updated to the new value');
            System.assertEquals(getEnvironmentRecord('Source').Id, updatedJE.copado__Source__c, 'Progress status should be updated to the new value');
            System.assertEquals(getEnvironmentRecord('Target').Id, updatedJE.copado__Destination__c, 'Progress status should be updated to the new value');
            System.assertEquals('old data json', updatedJE.copado__DataJson__c, 'Progress status should be updated to the new value');
        }
    }

    @IsTest
    private static void shouldNotUpdateWhenNullFieldApiName() {
        System.runAs(TestUtilities.getRunAsUser()) {
            //Setup
            SObject jobExecution = new JobExecution().source(getEnvironmentObject('Source')).destination(getEnvironmentObject('Target')).dataJSON('old data json').persist();

            JobExecutionUpdateService.Request request = new JobExecutionUpdateService.Request();
            request.jobExecutionId = jobExecution.Id;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + null + '", "value" : "' + NEW_STATUS + '"},{"fieldApiName" : "", "value" : "' + NEW_DATA_JSON + '"}]';

            // Exercise
            Test.startTest();
            JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__JobExecution__c updatedJE = getJobExecutionRecord(jobExecution.Id);
            System.assertEquals(null, updatedJE.copado__Status__c, 'Status should be updated to the new value');
            System.assertEquals(null, updatedJE.copado__ErrorMessage__c, 'Progress status should be updated to the new value');
            System.assertEquals(getEnvironmentRecord('Source').Id, updatedJE.copado__Source__c, 'Progress status should be updated to the new value');
            System.assertEquals(getEnvironmentRecord('Target').Id, updatedJE.copado__Destination__c, 'Progress status should be updated to the new value');
            System.assertEquals('old data json', updatedJE.copado__DataJson__c, 'Progress status should be updated to the new value');
        }
    }

    private static void createData() {
        Credential sourceCred = new Credential();
        new Environment().name('Source').add(sourceCred).platform('SFDX').persist();

        Credential newSourceCred = new Credential();
        new Environment().name('New Source').add(newSourceCred).platform('SFDX').persist();

        Credential targetCred = new Credential();
        new Environment().name('Target').add(targetCred).platform('SFDX').persist();

        Credential newTargetCred = new Credential();
        new Environment().name('New Target').add(newTargetCred).platform('SFDX').persist();
    }

    private static Environment getEnvironmentObject(String value) {
        return new Environment().recordId(getEnvironmentRecord(value).Id);
    }

    private static copado__Environment__c getEnvironmentRecord(String value) {
        return [SELECT Name FROM copado__Environment__c WHERE Name =:value];
    }

    private static copado__JobExecution__c getJobExecutionRecord(Id jobExecutionId) {
        return [SELECT copado__Status__c, copado__Source__c, copado__Destination__c, copado__DataJson__c, copado__ErrorMessage__c FROM copado__JobExecution__c WHERE Id =:jobExecutionId];
    }
}