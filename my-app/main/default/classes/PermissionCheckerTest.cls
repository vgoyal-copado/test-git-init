@IsTest
public with sharing class PermissionCheckerTest {
    private static final String NO_ACCESS_EMAIL = 'noAccess@copado.com';
    private static final String WITH_ACCESS_EMAIL = 'testuser@copado.com';
    private static final String PSET_CMC_SFDX_ADMIN = 'CMC_SFDX_Admin';
    private static final String PSET_CMC_SFDX_ADMIN_LABEL = 'CMC SFDX Admin';
    private static final String PROFILE_STANDARD_USER = 'Standard User';
    
    @TestSetup
    static void setupTestData() {
        // Create a test user with the required permission set
        Profile p = [SELECT Id FROM Profile WHERE Name = :PROFILE_STANDARD_USER];

        User testUser = createUser(p.Id, WITH_ACCESS_EMAIL);
        User noAccessUser = createUser(p.Id, NO_ACCESS_EMAIL);

        insert new List<User>{ testUser, noAccessUser };

        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = :PSET_CMC_SFDX_ADMIN];
        PermissionSet pset;
        if ( permissionSets.isEmpty() ) {
            pset = new PermissionSet(Name = PSET_CMC_SFDX_ADMIN, Label = PSET_CMC_SFDX_ADMIN_LABEL);
            insert pset;
        } else {
            pset = permissionSets[0];
        }
        
        PermissionSetAssignment psetAssignment = new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = pset.Id
        );
        insert psetAssignment;
    }
    
    @IsTest
    private static void testHasCmcSfdxAdminPermissionSetWithAccess() {
        Test.startTest();
        System.runAs(getRunAsUser()) {
            Boolean hasAccess = PermissionChecker.hasCmcSfdxAdminPermissionSet();
            Assert.isTrue(hasAccess, 'User should have permissions');
        }
        Test.stopTest();
    }

    @IsTest
    private static void testHasCmcSfdxAdminPermissionSetWithoutAccess() {
        Test.startTest();
        System.runAs(getNoAccessRunAsUser()) {
            Boolean hasAccess = PermissionChecker.hasCmcSfdxAdminPermissionSet();
            Assert.isTrue(!hasAccess, 'User should not have permissions');
        }
        Test.stopTest();
    }

    private static User createUser (Id profileId, String email) {
        String randomId = TestUtilities.generateRandomString( 8 );
        User usr = new User(
            Alias = randomId,
            Email =  email,
            EmailEncodingKey = 'UTF-8',
            LastName = randomId,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = randomId + '@copado.com' + System.currentTimeMillis()
        );

        return usr;
    }

    private static User getRunAsUser() {
        return [SELECT Id FROM User WHERE Email = :WITH_ACCESS_EMAIL LIMIT 1];
    }

    private static User getNoAccessRunAsUser () {
        return [SELECT Id FROM User WHERE Email = :NO_ACCESS_EMAIL LIMIT 1];
    }
}