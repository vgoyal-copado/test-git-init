public inherited sharing class Utilities {
    private final static Set<String> JOB_ENGINE_SOBJECTS_TO_BYPASS_VALIDATION = new Set<String>{ 'copado__JobExecution__c', 'copado__Result__c' };

    public static List<String> getPicklistValues(String objectApiName, String fieldApiName) {
        List<String> result = new List<String>();

        List<Schema.PicklistEntry> picklistValues = Schema.getGlobalDescribe()
            .get(objectApiName)
            .getDescribe()
            .fields.getMap()
            .get(fieldApiName)
            .getDescribe()
            .getPicklistValues();

        for (Schema.PicklistEntry ple : picklistValues) {
            result.add(ple.getValue());
        }

        return result;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void performDML(List<SObject> sobjects, String operationType, AccessLevel accessLevel) {
        allowManualChangesInJobEngineRecords(sobjects);
        switch on operationType.toLowerCase() {
            when 'insert' {
                Database.insert(sobjects, true, accessLevel);
            }
            when 'update' {
                Database.update(sobjects, true, accessLevel);
            }
            when 'delete' {
                Database.delete(sobjects, true, accessLevel);
            }
        }

        revokeManualChangesInJobEngineRecords();
    }

    public static Boolean areAllPermissionSetsAssigned(Set<String> permissionSetNames, String userId) {
        Map<Id, PermissionSet> permissionSetsById = new Map<Id, PermissionSet>(
            [SELECT Id FROM PermissionSet WHERE Name IN :permissionSetNames WITH SYSTEM_MODE]
        );

        Set<Id> permissionSetIds = permissionSetsById.keySet();
        Set<Id> permissionSetGroupIds = new Set<Id>();
        Map<Id, Set<Id>> permissionSetIdsByGroupId = new Map<Id, Set<Id>>();

        for (PermissionSetGroupComponent groupComponent : [
            SELECT PermissionSetId, PermissionSetGroupId
            FROM PermissionSetGroupComponent
            WHERE PermissionSetId IN :permissionSetIds
            WITH SYSTEM_MODE
        ]) {
            permissionSetGroupIds.add(groupComponent.PermissionSetGroupId);

            if (!permissionSetIdsByGroupId.containsKey(groupComponent.PermissionSetGroupId)) {
                permissionSetIdsByGroupId.put(groupComponent.PermissionSetGroupId, new Set<Id>());
            }
            permissionSetIdsByGroupId.get(groupComponent.PermissionSetGroupId).add(groupComponent.PermissionSetId);
        }

        Set<Id> assignedPermissionSetIds = new Set<Id>();
        Set<Id> assignedPermissionSetGroupIds = new Set<Id>();

        for (PermissionSetAssignment assignment : [
            SELECT PermissionSetId, PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE (PermissionSetId IN :permissionSetIds OR PermissionSetGroupId IN :permissionSetGroupIds) AND AssigneeId = :userId
            WITH SYSTEM_MODE
        ]) {
            if (assignment.PermissionSetGroupId != null) {
                assignedPermissionSetGroupIds.add(assignment.PermissionSetGroupId);
            } else {
                assignedPermissionSetIds.add(assignment.PermissionSetId);
            }
        }

        for (Id groupId : assignedPermissionSetGroupIds) {
            if (permissionSetIdsByGroupId.containsKey(groupId)) {
                assignedPermissionSetIds.addAll(permissionSetIdsByGroupId.get(groupId));
            }
        }

        return assignedPermissionSetIds.containsAll(permissionSetIds);
    }

    public static Boolean checkPermission(String permissionName, Set<Id> userIds, Boolean skipPermissionGroup) {
        List<PermissionSetAssignment> userPermissions = new List<PermissionSetAssignment>();

        if (skipPermissionGroup) {
            userPermissions = [
                SELECT Id
                FROM PermissionSetAssignment
                WHERE PermissionSet.Name = :permissionName AND AssigneeId = :userIds
                WITH SYSTEM_MODE
            ];
        } else {
            Set<Id> permissionSetGroupIdSet = new Set<Id>();
            List<PermissionSetGroupComponent> permissionRecords = [
                SELECT Id, PermissionSetGroupId
                FROM PermissionSetGroupComponent
                WHERE PermissionSet.Name = :permissionName
                WITH SYSTEM_MODE
            ];

            for (PermissionSetGroupComponent record : permissionRecords) {
                permissionSetGroupIdSet.add(record.PermissionSetGroupId);
            }

            userPermissions = [
                SELECT Id
                FROM PermissionSetAssignment
                WHERE (PermissionSet.Name = :permissionName OR PermissionSetGroupId IN :permissionSetGroupIdSet) AND AssigneeId = :userIds
                WITH SYSTEM_MODE
            ];
        }

        return !userPermissions.isEmpty();
    }

    public static Map<String, Schema.SObjectField> getFieldMapForObject(String objectApiName) {
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        return fieldMap;
    }

    public static Boolean checkPermissions(List<String> permissionsName, Set<Id> userIds) {
        return checkPermissions(permissionsName, userIds, false);
    }

    public static Boolean checkPermissions(List<String> permissionsName, Set<Id> userIds, Boolean skipPermissionGroup) {
        if (!isValidInput(permissionsName, userIds)) {
            return false;
        }

        Map<String, Set<Id>> permNameToGroupIds = new Map<String, Set<Id>>();
        Set<Id> permissionSetGroupIdSet = new Set<Id>();

        if (!skipPermissionGroup) {
            loadPermissionGroups(permissionsName, permNameToGroupIds, permissionSetGroupIdSet);
        }

        List<PermissionSetAssignment> userPermissions = queryPermissionAssignments(permissionsName, userIds, permissionSetGroupIdSet);

        Map<Id, Set<String>> userPermissionMap = initializeUserPermissionMap(userIds);
        processPermissionAssignments(userPermissions, permissionsName, skipPermissionGroup, permNameToGroupIds, userPermissionMap);

        return validateUserPermissions(userIds, permissionsName, userPermissionMap);
    }

    // PRIVATE

    private static Boolean isValidInput(List<String> permissionsName, Set<Id> userIds) {
        return permissionsName != null && !permissionsName.isEmpty() && userIds != null && !userIds.isEmpty();
    }

    private static void loadPermissionGroups(List<String> permissionsName, Map<String, Set<Id>> permNameToGroupIds, Set<Id> permissionSetGroupIdSet) {
        List<PermissionSetGroupComponent> permissionRecords = [
            SELECT Id, PermissionSetGroupId, PermissionSet.Name
            FROM PermissionSetGroupComponent
            WHERE PermissionSet.Name IN :permissionsName
            WITH SYSTEM_MODE
        ];

        for (PermissionSetGroupComponent record : permissionRecords) {
            if (!permNameToGroupIds.containsKey(record.PermissionSet.Name)) {
                permNameToGroupIds.put(record.PermissionSet.Name, new Set<Id>());
            }
            permNameToGroupIds.get(record.PermissionSet.Name).add(record.PermissionSetGroupId);
            permissionSetGroupIdSet.add(record.PermissionSetGroupId);
        }
    }

    private static List<PermissionSetAssignment> queryPermissionAssignments(List<String> permissionsName, Set<Id> userIds, Set<Id> groupIds) {
        return [
            SELECT Id, PermissionSet.Name, PermissionSetGroupId, AssigneeId
            FROM PermissionSetAssignment
            WHERE (PermissionSet.Name IN :permissionsName OR PermissionSetGroupId IN :groupIds) AND AssigneeId IN :userIds
            WITH SYSTEM_MODE
        ];
    }

    private static Map<Id, Set<String>> initializeUserPermissionMap(Set<Id> userIds) {
        Map<Id, Set<String>> userPermissionMap = new Map<Id, Set<String>>();
        for (Id userId : userIds) {
            userPermissionMap.put(userId, new Set<String>());
        }
        return userPermissionMap;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void processPermissionAssignments(
        List<PermissionSetAssignment> assignments,
        List<String> permissionsName,
        Boolean skipPermissionGroup,
        Map<String, Set<Id>> permNameToGroupIds,
        Map<Id, Set<String>> userPermissionMap
    ) {
        for (PermissionSetAssignment psa : assignments) {
            if (permissionsName.contains(psa.PermissionSet.Name)) {
                userPermissionMap.get(psa.AssigneeId).add(psa.PermissionSet.Name);
            }

            if (!skipPermissionGroup && psa.PermissionSetGroupId != null) {
                processGroupPermission(psa, permNameToGroupIds, userPermissionMap);
            }
        }
    }

    private static void processGroupPermission(
        PermissionSetAssignment psa,
        Map<String, Set<Id>> permNameToGroupIds,
        Map<Id, Set<String>> userPermissionMap
    ) {
        for (String permName : permNameToGroupIds.keySet()) {
            if (permNameToGroupIds.get(permName).contains(psa.PermissionSetGroupId)) {
                userPermissionMap.get(psa.AssigneeId).add(permName);
            }
        }
    }

    private static Boolean validateUserPermissions(Set<Id> userIds, List<String> permissionsName, Map<Id, Set<String>> userPermissionMap) {
        for (Id userId : userIds) {
            Set<String> userPerms = userPermissionMap.get(userId);
            if (!hasAllRequiredPermissions(userPerms, permissionsName)) {
                return false;
            }
        }
        return true;
    }

    private static Boolean hasAllRequiredPermissions(Set<String> userPerms, List<String> requiredPerms) {
        for (String requiredPerm : requiredPerms) {
            if (!userPerms.contains(requiredPerm)) {
                return false;
            }
        }
        return true;
    }

    private static void allowManualChangesInJobEngineRecords(List<SObject> records) {
        // SET THE BYEPASS VARIABLE SO THAT THE JOB ENGINE OBJECT TRIGGERS DON'T THROW A VALIDATION ERROR

        if (!records.isEmpty() && JOB_ENGINE_SOBJECTS_TO_BYPASS_VALIDATION.contains(getSobjectName(records.get(0)))) {
            copado.CheckJobEngineDMLAccess.allowJobEngineDML = 'Allow';
        }
    }

    private static String getSobjectName(SObject record) {
        return record.getSobjectType().getDescribe(SObjectDescribeOptions.DEFERRED).getName();
    }

    private static void revokeManualChangesInJobEngineRecords() {
        copado.CheckJobEngineDMLAccess.allowJobEngineDML = '';
    }

    // INNER

    public without sharing class DeleteSObjectWithoutSharing {
        public void execute(List<SObject> sobjectList) {
            // We are running the deletion logic in SYSTEM_MODE, because we need the
            // data to be deleted irrespective of its sharing and other permissions with respect to the current logged in user.
            Utilities.performDML(sobjectList, 'delete', AccessLevel.SYSTEM_MODE);
        }
    }

    public without sharing class UpdateSObjectWithoutSharing {
        public void execute(List<SObject> sobjectList) {
            // We are running the updation logic in SYSTEM_MODE, because we need the
            // data to be updated irrespective of its sharing and other permissions with respect to the current logged in user.
            Utilities.performDML(sobjectList, 'update', AccessLevel.SYSTEM_MODE);
        }
    }

    public without sharing class InsertSObjectWithoutSharing {
        public void execute(List<SObject> sobjectList) {
            // We are running the updation logic in SYSTEM_MODE, because we need the
            // data to be updated irrespective of its sharing and other permissions with respect to the current logged in user.
            Utilities.performDML(sobjectList, 'insert', AccessLevel.SYSTEM_MODE);
        }
    }
}