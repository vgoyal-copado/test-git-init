@IsTest
private class ResultUpdateServiceTest {
    private static final String STATUS_FIELD = 'copado__Status__c';
    private static final String PROGRESS_STATUS_FIELD = 'copado__Progress_Status__c';
    private static final String NEW_STATUS = 'Success';
    private static final String NEW_PROGRESS_STATUS = 'Completed';
    private static final String INVALID_FIELD = 'invalid_field__c';

    @TestSetup
    private static void setup() {
        TestUtilities.setup();
    }

    @IsTest
    private static void shouldUpdateResultRecord() {
        
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            SObject result = new Result()
                .type('Function')
                .status('In Progress')
                .progressStatus('Execution started')
                .persist();
        
            ResultUpdateService.Request request = new ResultUpdateService.Request();
            request.resultId = result.Id;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + STATUS_FIELD + '", "value" : "' + NEW_STATUS + '"},{"fieldApiName" : "' + PROGRESS_STATUS_FIELD + '", "value" : "' + NEW_PROGRESS_STATUS + '"}]';

            // Exercise
            Test.startTest();
            ResultUpdateService.execute(new List<ResultUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__Result__c updatedResult = getResultRecord(result.Id);
            System.assertEquals(NEW_STATUS, updatedResult.copado__Status__c, 'Status should be updated to the new value');
            System.assertEquals(NEW_PROGRESS_STATUS, updatedResult.copado__Progress_Status__c, 'Progress status should be updated to the new value');
        }
    }

    @IsTest
    private static void shouldOnlyUpdateValueOfValidFieldName() {
        System.runAs(TestUtilities.getRunAsUser()) {
            //Setup
            SObject result = new Result()
                .type('Function')
                .status('In Progress')
                .progressStatus('Execution started')
                .persist();
        
            ResultUpdateService.Request request = new ResultUpdateService.Request();
            request.resultId = result.Id;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + INVALID_FIELD + '", "value" : "' + NEW_STATUS + '"},{"fieldApiName" : "' + PROGRESS_STATUS_FIELD + '", "value" : "' + NEW_PROGRESS_STATUS + '"}]';

            // Exercise
            Test.startTest();
            ResultUpdateService.execute(new List<ResultUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__Result__c updatedResult = getResultRecord(result.Id);
            System.assertEquals('In Progress', updatedResult.copado__Status__c, 'Status should be same.');
            System.assertEquals(NEW_PROGRESS_STATUS, updatedResult.copado__Progress_Status__c, 'Progress status should be updated to the new value');
        }
    }

    @IsTest
    private static void shouldNotUpdateRecordWithNullJSON() {
        System.runAs(TestUtilities.getRunAsUser()) {
            //Setup
            SObject result = new Result()
                .type('Function')
                .status('In Progress')
                .progressStatus('Execution started')
                .persist();
        
            ResultUpdateService.Request request = new ResultUpdateService.Request();
            request.resultId = result.Id;
            request.valuesToUpdateJson = '';

            // Exercise
            Test.startTest();
            ResultUpdateService.execute(new List<ResultUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__Result__c updatedResult = getResultRecord(result.Id);
            System.assertEquals('In Progress', updatedResult.copado__Status__c, 'Status should be same.');
            System.assertEquals('Execution started', updatedResult.copado__Progress_Status__c, 'Progress status should remain same.');
        }
    }

    @IsTest
    private static void shouldNotUpdateWhenNullResultId() {
        
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            SObject result = new Result()
                .type('Function')
                .status('In Progress')
                .progressStatus('Execution started')
                .persist();
        
            ResultUpdateService.Request request = new ResultUpdateService.Request();
            request.resultId = null;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + STATUS_FIELD + '", "value" : "' + NEW_STATUS + '"},{"fieldApiName" : "' + PROGRESS_STATUS_FIELD + '", "value" : "' + NEW_PROGRESS_STATUS + '"}]';

            // Exercise
            Test.startTest();
            ResultUpdateService.execute(new List<ResultUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__Result__c updatedResult = getResultRecord(result.Id);
            System.assertEquals('In Progress', updatedResult.copado__Status__c, 'Status should be same.');
            System.assertEquals('Execution started', updatedResult.copado__Progress_Status__c, 'Progress status should remain same.');
        }
    }

    @IsTest
    private static void shouldNotUpdateWhenNullFieldApiName() {
        System.runAs(TestUtilities.getRunAsUser()) {
            //Setup
            SObject result = new Result()
                .type('Function')
                .status('In Progress')
                .progressStatus('Execution started')
                .persist();
        
            ResultUpdateService.Request request = new ResultUpdateService.Request();
            request.resultId = result.Id;
            request.valuesToUpdateJson = '[{"fieldApiName" : "' + null + '", "value" : "' + NEW_STATUS + '"},{"fieldApiName" : "", "value" : "' + NEW_PROGRESS_STATUS + '"}]';

            // Exercise
            Test.startTest();
            ResultUpdateService.execute(new List<ResultUpdateService.Request>{ request });
            Test.stopTest();

            // Verify
            copado__Result__c updatedResult = getResultRecord(result.Id);
            System.assertEquals('In Progress', updatedResult.copado__Status__c, 'Status should be same.');
            System.assertEquals('Execution started', updatedResult.copado__Progress_Status__c, 'Progress status should remain same.');
        }
    }

    private static copado__Result__c getResultRecord(Id resultId) {
        return [SELECT Id, copado__Status__c, copado__Progress_Status__c FROM copado__Result__c WHERE Id =:resultId];
    }
}