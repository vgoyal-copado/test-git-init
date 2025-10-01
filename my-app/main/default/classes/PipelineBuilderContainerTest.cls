@IsTest
private with sharing class PipelineBuilderContainerTest {

    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
    }

    @IsTest
    private static void validateUserPermissions() {
        User standardUser = TestUtilities.getRunAsUser();

        System.runAs(standardUser) {
            // Exercise
            Test.startTest();
            removePermissionSetAssignment(standardUser.Id);
            List<String> missingPermissions = PipelineBuilderContainer.validateUserPermissions();
            Test.stopTest();

            // Verify
            System.assertEquals(false, missingPermissions.contains('Copado Admin License'), 'User should have Copado Admin License');
            System.assertEquals(false, missingPermissions.contains('Copado User'), 'User should have Copado User permission set');            
            System.assertEquals(false, missingPermissions.isEmpty(), 'User should have missing permissions');
            System.assertEquals(true, missingPermissions.contains('Copado Functions Admin'), 'Copado Functions Admin permission set should be missing');
            System.assertEquals(true, missingPermissions.contains('Copado Job Engine'), 'Copado Job Engine permission set should be missing');
            System.assertEquals(true, missingPermissions.contains('CMC SFDX Admin'), 'Git Snapshot Admin permission set should be missing');
        }
    }

    private static void removePermissionSetAssignment(Id userId) {
        Set<String> permissions = new Set<String>{ 'Copado_Functions', 'Copado_Job_Engine', 'CMC_SFDX_Admin' };
        List<PermissionSetAssignment> permissionSetAssignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId AND PermissionSet.Name IN :permissions
        ];
        delete permissionSetAssignments;
    }    
}