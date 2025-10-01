@IsTest
private class OverviewGovernanceOrgCredentialCtrlTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
    }
    
    @IsTest
    static void testHasValidCredentialWithValidCredential() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Create test data
            copado__Org__c orgCredential = new copado__Org__c(
                Name = 'Test Credential',
                copado__Username__c = UserInfo.getUserName(),
                copado__SFDC_Org_ID__c = UserInfo.getOrganizationId()
            );
            
            Test.startTest();
            insert orgCredential;
            OverviewGovernanceOrgCredentialCtrl.Credential result = OverviewGovernanceOrgCredentialCtrl.hasValidCredential();
            Test.stopTest();
            
            Assert.areEqual('valid', result.status, 'Status should be valid');
        }
    }
    
    @IsTest
    static void testHasValidCredentialWithNoCredential() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Test.startTest();
            OverviewGovernanceOrgCredentialCtrl.Credential result = OverviewGovernanceOrgCredentialCtrl.hasValidCredential();
            Test.stopTest();

            Assert.areEqual('notfound', result.status, 'Status should be notfound');
        }
    }
}