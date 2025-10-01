@IsTest
private class PipelineAutomationRulesCtrlTest {

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }
    
    @IsTest
    private static void validatePermissionForAutomationRules() {
        System.runAs(TestUtilities.getRunAsUser()) {
        
            // Exercise
            Test.startTest();
            PipelineAutomationRulesCtrl.PermissionResponse response = PipelineAutomationRulesCtrl.getPermissionResponse();
            System.Assert.areEqual(false, response.hasPermission, 'User should not have permission');
            Test.stopTest();
        }
    }

    @IsTest
    private static void validatePermissionForAutomationRulesFromPSG() {
        User testUser = TestUtilities.getRunAsUser();
        TestUtilities.assignPermissionSetGroup('PSG_Automations', new List<String>{ 'Configure_Automations' }, testUser.Id);
        System.runAs(testUser) {
            
            // Exercise
            Test.startTest();
            PipelineAutomationRulesCtrl.PermissionResponse response = PipelineAutomationRulesCtrl.getPermissionResponse();
            System.Assert.areEqual(true, response.hasPermission, 'User should have permission');
            Test.stopTest();
        }
    }

    @IsTest
    private static void MatchingRulesTest() {
        User testUser = TestUtilities.getRunAsUser();
        TestUtilities.assignPermissionSetGroup('PSG_Automations', new List<String>{ 'Configure_Automations' }, testUser.Id);

        System.runAs(testUser) {
            // Setup
            copado__Deployment_Flow__c pipeline = [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
            copado__Environment__c env = [SELECT Id FROM copado__Environment__c WHERE Name = 'Dev1' LIMIT 1];

            copado__Automation_Rule__c automationRule = new copado__Automation_Rule__c(
                Name = 'Test Automation Rule',
                copado__Pipeline__c = pipeline.Id,
                copado__Source_Action__c = 'PromotionDeployment',
                copado__Source_Action_Status__c = 'Successful',
                copado__Automated_Action__c = 'Promotion',
                copado__Automation_Connector__c = 'Promotion',
                copado__Execution__c = 'Immediate',
                copado__Config_Json__c = '{"stages":[], "environments":["'+ env.Id + '"], "environmentsForBackPromotion":[], "scope":"advanced", "isAppliedToPipeline":false}',
                copado__Active__c = true
            );
            insert automationRule;

            copado__Automation_Rule__c newAR = [SELECT Id, copado__Pipeline__c
                                        FROM copado__Automation_Rule__c
                                        WHERE copado__Active__c = TRUE AND copado__Pipeline__c = :pipeline.Id 
                                        WITH USER_MODE];
            System.assertNotEquals(null, newAR, 'newAR should not be null');
            
            Test.startTest();

            // Get matching rules for environment Dev1
            PipelineAutomationRulesCtrl.MatchingRulesResultWrapper matchingResult = PipelineAutomationRulesCtrl.getMatchingRules(pipeline.Id, env.Id);

            // Assert matching service results
            System.assertNotEquals(null, matchingResult, 'matchingResult should not be null');
            System.assertNotEquals(null, matchingResult.matchingRuleConfig, 'matchingRuleConfig should not be null');
            System.assertNotEquals(null, matchingResult.matchingRuleConfig.matchingRules, 'matchingRules should not be null');
            System.assert(matchingResult.matchingRuleConfig.matchingRules.size() == 1, 'there should be one matching rule');
            System.assert(matchingResult.matchingRuleConfig.matchingRules[0].isLastEnvironmentInAutomationRule, 'Dev1 should be the last environment in the matching rule');

            Test.stopTest();
        }
    }    
    
    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Project project = new Project();

            new Repository().name('DX');
            Environment dev1 = new Environment().name('Dev1');
            Environment staging = new Environment().name('Staging');
            new Credential(dev1).default(true);
            new Credential(staging).default(true).orgId('a00Y');

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(project)
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('staging').branch('dev1'))
            .persist();
        }
    }

    private static copado__Deployment_Flow__c getPipeline(String name) {
        return [SELECT Id FROM copado__Deployment_Flow__c WHERE copado__Platform__c = :name LIMIT 1][0];
    }
}