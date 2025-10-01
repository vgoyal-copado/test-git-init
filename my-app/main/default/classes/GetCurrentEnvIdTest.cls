@IsTest
private class GetCurrentEnvIdTest {

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void testGetCurrentEnvironmentId() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Id randomId = fflib_IdGenerator.generate(SObjectType.copado__JobStep__c.getKeyPrefix());

            // EXERCISE
            String envId = new GetCurrentEnvId().execute(randomId);

            // VERIFY
            copado__Environment__c env = getEnvironment(envId);
            Assert.areEqual('currentDev', env.Name, 'Environment name must be currentDev');

        }

    }

    @IsTest
    private static void testGetCurrentEnvironmentIdWithWrongSfdcID() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Id randomId = fflib_IdGenerator.generate(SObjectType.copado__JobStep__c.getKeyPrefix());
            copado__Org__c currentDev = getOrg('currentDev');
            currentDev.copado__SFDC_Org_ID__c = currentDev.copado__SFDC_Org_ID__c + 'abc';
            update currentDev;

            String exceptionMessage;
            // EXERCISE
            try {
                new GetCurrentEnvId().execute(randomId);
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }

            // VERIFY
            Assert.areEqual(exceptionMessage, Label.Error_Validate_Current_Org_Credential, 'Error message should be ' + Label.Error_Validate_Current_Org_Credential);

        }

    }

    private static void createData() {
        new Credential(new Environment().name('currentDev').platform('SFDX').type('Production/Developer')).type('Production/Developer').persist();
        String sfdcOrgId = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();
        copado__Org__c currentDev = getOrg('currentDev');
        currentDev.copado__SFDC_Org_ID__c = sfdcOrgId;
        update currentDev;

    }

    private static copado__Org__c getOrg(String name) {
        return [SELECT Id, copado__SFDC_Org_ID__c FROM copado__Org__c WHERE Name = :name LIMIT 1];
    }


    private static copado__Environment__c getEnvironment(Id id) {
        return [SELECT Id, Name, copado__Org_ID__c FROM copado__Environment__c WHERE Id = :id LIMIT 1];
    }
}