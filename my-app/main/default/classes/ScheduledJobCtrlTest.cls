@IsTest
private class ScheduledJobCtrlTest {
    
    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create a scheduled job for testing
        String cronExp = '0 0 0 * * ?';
        String jobName = 'TestScheduledJob';
        
        System.schedule(jobName, cronExp, new TestScheduledJob());
        TestUtilities.setup();
    }
    
    @IsTest
    static void testGetNextFireTimeValid() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Set Up
            CronTrigger ct = [SELECT Id FROM CronTrigger LIMIT 1];
            String scheduledJobId = ct.Id;
            
            // Execute
            Test.startTest();
            String nextFireTime = ScheduledJobCtrl.getNextFireTime(scheduledJobId);
            Test.stopTest();
            
            // Verify
            Assert.isNotNull(nextFireTime, 'Next fire time should not be null');
        }
    }
    
    @IsTest
    static void testGetNextFireTimeInvalid() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Set Up
            String invalidJobId = '0000000000000000';
            Boolean exceptionOccurred = false;
            // Execute
            Test.startTest();
            try {
                ScheduledJobCtrl.getNextFireTime(invalidJobId);
            } catch (Exception ex) {
                exceptionOccurred = true;
            }
            Test.stopTest();
            
            // Verify
            Assert.isTrue(exceptionOccurred, 'Exception must be there.');
        }
    }
    
    
    @IsTest
    static void testGetBatchNextFireTimesValid() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Set Up
            CronTrigger ct = [SELECT Id FROM CronTrigger LIMIT 1];
            List<String> scheduledJobIds = new List<String>{ct.Id};
            
            // Execute
            Test.startTest();
            Map<String, String> resultMap = ScheduledJobCtrl.getBatchNextFireTimes(scheduledJobIds);
            Test.stopTest();
            
            // Verify
            Assert.isTrue(!resultMap.isEmpty(), 'Result map should not be empty');
            String nextFireTime = resultMap.values()[0];
            Assert.isNotNull(nextFireTime, 'Next fire time should not be null for valid Job Id');
        }
    }
    

    // Helper scheduled class for testing
    public class TestScheduledJob implements Schedulable {
        @SuppressWarnings('PMD.EmptyStatementBlock')
        public void execute(SchedulableContext sc) {
            // Empty implementation for test purposes
        }
    }
}