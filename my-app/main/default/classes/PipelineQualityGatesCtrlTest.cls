@IsTest
private class PipelineQualityGatesCtrlTest {

    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            makeData();
        }
    }

    @IsTest
    private static void getTestToolMetadataTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXCERCISE
            List<copado__TestTool__mdt> result = PipelineQualityGatesCtrl.getAllQualityGateTestFrom();

            // VERIFY
            Assert.isNull(result, 'The result is null');
        }
    }

    @IsTest
    private static void getAllExtensionConfigurationsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXCERCISE
            List<copado__ExtensionConfiguration__c> result = PipelineQualityGatesCtrl.getAllExtensionConfigurations();

            // VERIFY
            Assert.isNotNull(result, 'The result is null');
            Assert.areEqual(1, result.size(), 'The number of extension configurations do not match');
        }
    }

    @IsTest
    private static void hasAllPermissionAssignedTest() {
        //SETUP

        User user = TestUtilities.getRunAsUser();
        TestUtilities.assignPermissionSetGroup('PSG_Automations', new List<String>{ 'Configure_Automations', 'Configure_AQF' }, user.Id);
        System.runAs(user) {
            // EXCERCISE
            Boolean result = PipelineQualityGatesCtrl.hasPermission();

            // VERIFY
            Assert.isTrue(result, 'The permission is assigned to the user.');
        }
    }

    @IsTest
    private static void hasOnlyOneOfThePermissionAssignedTest() {
        //SETUP

        User user = TestUtilities.getRunAsUser();
        TestUtilities.assignPermissionSetGroup('PSG_Automations', new List<String>{ 'Configure_AQF' }, user.Id);
        System.runAs(user) {
            // EXCERCISE
            Boolean result = PipelineQualityGatesCtrl.hasPermission();

            // VERIFY
            Assert.isFalse(result, 'All permissions are not assigned to the user.');
        }
    }

    // HELPER

    private static void makeData() {
        List<String> picklistValues = Utilities.getPicklistValues(
            SObjectType.copado__ExtensionConfiguration__c.getName(),
            // PMD is giving a false positive here
            copado__ExtensionConfiguration__c.copado__ExtensionTool__c.getDescribe(FieldDescribeOptions.DEFAULT).getName()
        );

        copado__TestTool__mdt testTool = new copado__TestTool__mdt(
            MasterLabel = !picklistValues.isEmpty() ? picklistValues[0] : '',
            copado__JobTemplate__c = 'MockTemplate',
            copado__TestType__c = 'Mock Type'
        );

        copado__ExtensionConfiguration__c extensionConfig = new copado__ExtensionConfiguration__c(
            copado__ExtensionTool__c = testTool.MasterLabel,
            copado__ExtensionApplication__c = 'Test',
            copado__Active__c = true
        );
        insert extensionConfig;
    }
}