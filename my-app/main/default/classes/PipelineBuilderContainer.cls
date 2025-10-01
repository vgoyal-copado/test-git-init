public with sharing class PipelineBuilderContainer {
    private static final String COPADO_ADMIN_LICENSE = 'Copado Admin License';

    private static final Set<String> PIPELINE_PERMISSIONS = new Set<String>{
        'Copado_User',
        'Copado_Functions',
        'Copado_Job_Engine',
        'Configure_Snapshot',
        'CMC_SFDX_Admin'
    };

    // PUBLIC

    @AuraEnabled
    public static List<String> validateUserPermissions() {
        List<String> missingPermissions = new List<String>();
        Id userId = UserInfo.getUserId();

        try {           
            checkCopadoLicense(userId, missingPermissions);
            Map<String, String> permissionLabelByName = getPermissionLabelByName();

            Map<String, Set<Id>> groupIdByPermissionName = new Map<String, Set<Id>>();
            Set<Id> permissionSetGroupIds = new Set<Id>();
            loadPermissionSetGroups(groupIdByPermissionName, permissionSetGroupIds);

            Set<String> assignedPermissionSetNames = getAssignedPermissions(userId, groupIdByPermissionName, permissionSetGroupIds);
            findMissingPermissions(assignedPermissionSetNames, permissionLabelByName, missingPermissions);
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
        return missingPermissions;
    }

    // PRIVATE
    private static void checkCopadoLicense(Id userId, List<String> missingPermissions) {
        CheckLicense license = new CheckLicense(userId);

        if (license == null || !license.has('Copado Admin')) {
            missingPermissions.add(COPADO_ADMIN_LICENSE);
        }
    }

    private static Map<String, String> getPermissionLabelByName() {
        Map<String, String> permissionLabelByName = new Map<String, String>();
        List<PermissionSet> permissionSets = [
            SELECT Name, Label 
            FROM PermissionSet
            WHERE Name IN :PIPELINE_PERMISSIONS
            WITH SYSTEM_MODE
        ];

        for (PermissionSet ps : permissionSets) {
            permissionLabelByName.put(ps.Name, ps.Label);
        }

        return permissionLabelByName;
    }    

    private static void loadPermissionSetGroups(Map<String, Set<Id>> groupIdByPermissionName, Set<Id> permissionSetGroupIds) {
        List<PermissionSetGroupComponent> permissionSetGroups = [
            SELECT PermissionSet.Name, PermissionSetGroupId
            FROM PermissionSetGroupComponent
            WHERE PermissionSet.Name IN :PIPELINE_PERMISSIONS
            WITH SYSTEM_MODE
        ];

        for (PermissionSetGroupComponent permissionSetGroup : permissionSetGroups) {
            if (!groupIdByPermissionName.containsKey(permissionSetGroup.PermissionSet.Name)) {
                groupIdByPermissionName.put(permissionSetGroup.PermissionSet.Name, new Set<Id>());
            }
            groupIdByPermissionName.get(permissionSetGroup.PermissionSet.Name).add(permissionSetGroup.PermissionSetGroupId);
            permissionSetGroupIds.add(permissionSetGroup.PermissionSetGroupId);
        }
    }

    private static Set<String> getAssignedPermissions(Id userId, Map<String, Set<Id>> groupIdByPermissionName, Set<Id> permissionSetGroupIds) {
        Set<String> assignedPermissionSetNames = new Set<String>();

        List<PermissionSetAssignment> permissionSetAssignments = [
            SELECT PermissionSet.Name, PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
                AND (PermissionSet.Name IN :PIPELINE_PERMISSIONS
                    OR PermissionSetGroupId IN :permissionSetGroupIds)
            WITH SYSTEM_MODE
        ];

        for (PermissionSetAssignment permissionSetAssignment : permissionSetAssignments) {
            if (permissionSetAssignment.PermissionSet != null && PIPELINE_PERMISSIONS.contains(permissionSetAssignment.PermissionSet.Name)) {
                assignedPermissionSetNames.add(permissionSetAssignment.PermissionSet.Name);
            } else if (permissionSetAssignment.PermissionSetGroupId != null) {
                for (String permissionSetName : groupIdByPermissionName.keySet()) {
                    if (groupIdByPermissionName.get(permissionSetName).contains(permissionSetAssignment.PermissionSetGroupId)) {
                        assignedPermissionSetNames.add(permissionSetName);
                    }
                }
            }
        }

        return assignedPermissionSetNames;
    }

    private static void findMissingPermissions(Set<String> assignedPermissionSetNames, Map<String, String> permissionLabelByName, List<String> missingPermissions) {
        for (String permission : PIPELINE_PERMISSIONS) {
            if (!assignedPermissionSetNames.contains(permission)) {
                missingPermissions.add(permissionLabelByName.get(permission) ?? permission);
            }
        }
    }
}