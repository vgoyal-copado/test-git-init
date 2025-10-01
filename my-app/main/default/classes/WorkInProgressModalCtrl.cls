@SuppressWarnings('PMD.ApexDoc, PMD.CyclomaticComplexity')
public with sharing class WorkInProgressModalCtrl {
    private static final String WORK_IN_PROGRESS_SYSTEM_PROPERTY = 'Env_Sync_Back_Promote_Override_Destination_Changes';
    private static final String SYSTEM_PROPERTY_VALUE = 'true';

    @AuraEnabled
    public static WorkInProgressData getData(Id pipelineId) {
        try {
            WorkInProgressData result = new WorkInProgressData();
            Set<Id> environmentIds = new Set<Id>();
            Map<Id, String> environmentNames = new Map<Id, String>();

            List<copado__Deployment_Flow_Step__c> pipelineConnections = new PipelineConnectionsSelector().byPipelineId(pipelineId);
            if (pipelineConnections.isEmpty()) {
                return result;
            }

            for (copado__Deployment_Flow_Step__c connection : pipelineConnections) {
                if (connection.copado__Source_Environment__c != null) {
                    environmentIds.add(connection.copado__Source_Environment__c);
                    environmentNames.put(connection.copado__Source_Environment__c, connection.copado__Source_Environment__r.Name);
                }
                if (connection.copado__Destination_Environment__c != null) {
                    environmentIds.add(connection.copado__Destination_Environment__c);
                    environmentNames.put(connection.copado__Destination_Environment__c, connection.copado__Destination_Environment__r.Name);
                }
            }
            result.environments = getEnvironmentLookupData(environmentIds, environmentNames);
            result.currentWorkInProgressEnvironments = getCurrentWorkInProgressEnvironments(environmentIds);
            return result;
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getWorkInProgressEnvironmentCount(Id pipelineId) {
        try {
            Integer count = 0;
            Set<Id> environmentIds = getAllEnvironmentIdsForPipeline(pipelineId);
            if (environmentIds.isEmpty()) {
                return count;
            }
            List<copado__System_Property__c> systemProperties = new SystemPropertiesSelector()
                .byEnvironmentForSFDX(environmentIds, WORK_IN_PROGRESS_SYSTEM_PROPERTY);

            for (copado__System_Property__c prop : systemProperties) {
                if (isWorkInProgressEnabled(prop)) {
                    count++;
                }
            }
            return count;
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void saveWorkInProgressSettings(Id pipelineId, List<Id> environmentIds) {
        try {
            Set<Id> allEnvironmentIds = getAllEnvironmentIdsForPipeline(pipelineId);
            Map<Id, copado__System_Property__c> existingSystemProperties = getExistingSystemProperties(allEnvironmentIds);

            List<copado__System_Property__c> systemPropertiesToInsert = getSystemPropertiesToInsert(allEnvironmentIds, environmentIds, existingSystemProperties);
            List<copado__System_Property__c> systemPropertiesToDelete = getSystemPropertiesToDelete(allEnvironmentIds, environmentIds, existingSystemProperties);

            performInsert(systemPropertiesToInsert);
            performDelete(systemPropertiesToDelete);
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    // PRIVATE METHODS

    private static Set<Id> getAllEnvironmentIdsForPipeline(Id pipelineId) {
        Set<Id> environmentIds = new Set<Id>();
        List<copado__Deployment_Flow_Step__c> pipelineConnections = new PipelineConnectionsSelector().byPipelineId(pipelineId);
        if (pipelineConnections.isEmpty()) {
            return environmentIds;
        }
        for (copado__Deployment_Flow_Step__c connection : pipelineConnections) {
            environmentIds.add(connection.copado__Source_Environment__c);
            environmentIds.add(connection.copado__Destination_Environment__c);
        }
        return environmentIds;
    }

    private static List<copado__System_Property__c> getSystemPropertiesToInsert(Set<Id> allEnvironmentIds, List<Id> selectedEnvironmentIds, Map<Id, copado__System_Property__c> existingSystemProperties) {
        List<copado__System_Property__c> toInsert = new List<copado__System_Property__c>();
        for (Id environmentId : allEnvironmentIds) {
            Boolean shouldHaveProperty = selectedEnvironmentIds.contains(environmentId);
            Boolean hasProperty = existingSystemProperties.containsKey(environmentId);
            if (shouldHaveProperty && !hasProperty) {
                toInsert.add(createSystemProperty(environmentId));
            }
        }
        return toInsert;
    }

    private static List<copado__System_Property__c> getSystemPropertiesToDelete(Set<Id> allEnvironmentIds, List<Id> selectedEnvironmentIds, Map<Id, copado__System_Property__c> existingSystemProperties) {
        List<copado__System_Property__c> toDelete = new List<copado__System_Property__c>();
        for (Id environmentId : allEnvironmentIds) {
            Boolean shouldHaveProperty = selectedEnvironmentIds.contains(environmentId);
            Boolean hasProperty = existingSystemProperties.containsKey(environmentId);
            if (!shouldHaveProperty && hasProperty) {
                toDelete.add(existingSystemProperties.get(environmentId));
            }
        }
        return toDelete;
    }

    private static void performInsert(List<copado__System_Property__c> systemPropertiesToInsert) {
        if (!systemPropertiesToInsert.isEmpty()) {
            Utilities.performDML(systemPropertiesToInsert, 'insert', AccessLevel.USER_MODE);
        }
    }

    private static void performDelete(List<copado__System_Property__c> systemPropertiesToDelete) {
        if (!systemPropertiesToDelete.isEmpty()) {
            Utilities.performDML(systemPropertiesToDelete, 'delete', AccessLevel.USER_MODE);
        }
    }

    private static boolean isWorkInProgressEnabled(copado__System_Property__c prop) {
        return prop.copado__Value__c?.toLowerCase() == SYSTEM_PROPERTY_VALUE.toLowerCase();
    }

    private static List<EnvironmentLookupData> getEnvironmentLookupData(Set<Id> environmentIds, Map<Id, String> environmentNames) {
        List<EnvironmentLookupData> result = new List<EnvironmentLookupData>();
        for (Id environmentId : environmentIds) {
            String environmentName = environmentNames.get(environmentId);
            if (environmentName != null) {
                result.add(new EnvironmentLookupData(environmentId, environmentName));
            }
        }
        return result;
    }

    private static List<Id> getCurrentWorkInProgressEnvironments(Set<Id> environmentIds) {
        List<Id> result = new List<Id>();
        List<copado__System_Property__c> systemProperties = new SystemPropertiesSelector()
            .byEnvironmentForSFDX(environmentIds, WORK_IN_PROGRESS_SYSTEM_PROPERTY);
        for (copado__System_Property__c prop : systemProperties) {
            if (isWorkInProgressEnabled(prop)) {
                result.add(prop.copado__Environment__c);
            }
        }
        return result;
    }

    private static Map<Id, copado__System_Property__c> getExistingSystemProperties(Set<Id> environmentIds) {
        Map<Id, copado__System_Property__c> result = new Map<Id, copado__System_Property__c>();
        List<copado__System_Property__c> systemProperties = new SystemPropertiesSelector()
            .byEnvironmentForSFDX(environmentIds, WORK_IN_PROGRESS_SYSTEM_PROPERTY);
        for (copado__System_Property__c prop : systemProperties) {
            result.put(prop.copado__Environment__c, prop);
        }
        return result;
    }

    private static copado__System_Property__c createSystemProperty(Id environmentId) {
        return new copado__System_Property__c(
            Name = WORK_IN_PROGRESS_SYSTEM_PROPERTY,
            copado__API_Name__c = WORK_IN_PROGRESS_SYSTEM_PROPERTY,
            copado__Environment__c = environmentId,
            copado__Value__c = SYSTEM_PROPERTY_VALUE
        );
    }

    // WRAPPER CLASSES

    public with sharing class WorkInProgressData {
        @AuraEnabled
        public List<EnvironmentLookupData> environments;
        @AuraEnabled
        public List<Id> currentWorkInProgressEnvironments;

        public WorkInProgressData() {
            this.environments = new List<EnvironmentLookupData>();
            this.currentWorkInProgressEnvironments = new List<Id>();
        }
    }

    public with sharing class EnvironmentLookupData {
        @AuraEnabled
        public String environmentId;
        @AuraEnabled
        public String environmentName;

        public EnvironmentLookupData(String environmentId, String environmentName) {
            this.environmentId = environmentId;
            this.environmentName = environmentName;
        }
    }
}