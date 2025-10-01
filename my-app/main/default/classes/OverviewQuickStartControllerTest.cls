@IsTest
public class OverviewQuickStartControllerTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
    }

    @IsTest
    static void isQuickStartInProgressWithInProgressQuickStartShouldReturnTrue() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Environment environment1 = TestUtilities.createEnvironment('Environment 1');
            Environment environment2 = TestUtilities.createEnvironment('Environment 2');
    
            copado__Deployment_Flow__c deploymentFlow = new copado__Deployment_Flow__c(
                Name = 'Test Flow',
                Initialization_Data__c = getMockInitializationData()
            );
            insert deploymentFlow;
    
            copado__Deployment_Flow_Step__c deploymentFlowStep = new copado__Deployment_Flow_Step__c(
                copado__Deployment_Flow__c = deploymentFlow.Id,
                copado__Source_Environment__c = environment1.id,
                copado__Destination_Environment__c = environment2.id
            );
            insert deploymentFlowStep;
    
            Test.startTest();
                Boolean result = OverviewQuickStartController.isQuickStartInProgress();
            Test.stopTest();
    
            System.assertEquals(true, result, 'Should return true if quick start is in progress');
        }
    }

    @IsTest
    static void isQuickStartInProgressWithNoQuickStartShouldReturnFalse() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Test.startTest();
                Boolean result = OverviewQuickStartController.isQuickStartInProgress();
            Test.stopTest();
    
            System.assertEquals(false, result, 'Should return false if no quick start is in progress');
        }
    }

    private static String getMockInitializationData () {
        return '{"quickStart":{"quickStartSteps":[{"isActive":true,"isCompleted":false}]}}';
    }
}