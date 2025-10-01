@IsTest
private class FieldSetControllerTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser('username-admin@myemail.com');
    }

    @IsTest
    private static void getFieldSetDetailsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Exercise
            List<FieldSetController.FieldSetMemberWrapper> result = FieldSetController.getFieldSetDetails(
                'copado__User_Story__c',
                'copado__CBM_Fields'
            );

            // Verify
            Assert.areNotEqual(null, result, 'Response is null');
            Assert.isTrue(result.size() > 0, 'Size does not match');
        }
    }
}