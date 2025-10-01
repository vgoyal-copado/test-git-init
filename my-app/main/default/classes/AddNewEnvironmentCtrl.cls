public with sharing class AddNewEnvironmentCtrl {
    @AuraEnabled
    public static AddEnvironmentData getData(Id pipelineId, String stageName) {
        AddEnvironmentData result = new AddEnvironmentData();
        result.pipeline = getPipeline(pipelineId);
        result.isPipelineActive = result.pipeline.copado__Active__c;
        result.stageConnection = getStageConnection(pipelineId, stageName);

        List<copado__Deployment_Flow_Step__c> pipelineConnections = new PipelineConnectionsSelector().byPipelineIdWithStageInfo(pipelineId);
        Set<Id> sourceEnvironmentIds = getSourceEnvironments(pipelineConnections);
        Set<Id> destinationEnvironmentIds = getDestinationEnvironments(pipelineConnections);
        Id productionEnvironmentId = findProductionEnvironmentId(sourceEnvironmentIds, destinationEnvironmentIds);

        updateProductionDetails(result, pipelineId, productionEnvironmentId);
        result.sourceEnvironments = getExistingEnvironments(result.pipeline.copado__Platform__c, pipelineConnections);
        result.targetEnvironments = getAvailableTargetEnvironments(pipelineId, result);

        Set<Id> allEnvironments = new Set<Id>(sourceEnvironmentIds);
        allEnvironments.addAll(destinationEnvironmentIds);

        return result;
    }

    // PRIVATE

    private static copado__Deployment_Flow__c getPipeline(Id pipelineId) {
        return new PipelinesSelector().byId(new Set<Id>{ pipelineId })[0];
    }

    private static copado__Stage_Connection__c getStageConnection(Id pipelineId, String stageName) {
        return new StageConnectionsSelector().byPipelineAndName(pipelineId, stageName)[0];
    }

    private static Set<Id> getSourceEnvironments(List<copado__Deployment_Flow_Step__c> pipelineConnections) {
        Set<Id> environments = new Set<Id>();
        for (copado__Deployment_Flow_Step__c connection : pipelineConnections) {
            environments.add(connection.copado__Source_Environment__c);
        }
        return environments;
    }

    private static Set<Id> getDestinationEnvironments(List<copado__Deployment_Flow_Step__c> pipelineConnections) {
        Set<Id> environments = new Set<Id>();
        for (copado__Deployment_Flow_Step__c connection : pipelineConnections) {
            environments.add(connection.copado__Destination_Environment__c);
        }
        return environments;
    }

    private static Id findProductionEnvironmentId(Set<Id> sourceEnvironments, Set<Id> destinationEnvironments) {
        for (Id environmentId : destinationEnvironments) {
            if (!sourceEnvironments.contains(environmentId)) {
                return environmentId;
            }
        }
        return null;
    }

    private static void updateProductionDetails(AddEnvironmentData result, Id pipelineId, Id productionEnvironmentId) {
        List<copado__Deployment_Flow_Step__c> connections = new PipelineConnectionsSelector().byPipelineIdWithStageInfo(pipelineId);
        for (copado__Deployment_Flow_Step__c connection : connections) {
            if (productionEnvironmentId == connection.copado__Destination_Environment__c) {
                result.productionEnvironmentId = productionEnvironmentId;
                result.productionEnvironmentName = connection.copado__Destination_Environment__r.Name;

                String stageName = connection.copado__Stage_Connection__r.copado__Next_Stage_Connection__r.copado__Stage__r.Name != null
                    ? connection.copado__Stage_Connection__r.copado__Next_Stage_Connection__r.copado__Stage__r.Name
                    : connection.copado__Stage_Connection__r.copado__Stage__r.Name;
                result.productionStageName = Label.Stage + ': ' + stageName;
                break;
            }
        }
    }

    private static List<EnvironmentLookupData> getExistingEnvironments(String platform, List<copado__Deployment_Flow_Step__c> pipelineConnections) {
        Map<String, EnvironmentLookupData> result = new Map<String, EnvironmentLookupData>();

        Set<Id> environments = new Set<Id>();
        for (copado__Deployment_Flow_Step__c connection : pipelineConnections) {
            environments.add(connection.copado__Source_Environment__c);
            environments.add(connection.copado__Destination_Environment__c);
        }

        // Retrieve Only default credentials
        List<copado__Org__c> credentials = new CredentialsSelector().byNotInEnvironmentIdAndPlatform(environments, platform);
        for (copado__Org__c credential : credentials) {
            if (!result.containsKey(credential.copado__Environment__c)){
                result.put(credential.copado__Environment__c, new EnvironmentLookupData(credential.copado__Environment__c, credential.copado__Environment__r.Name, ''));
        }
        }
        return result.values();
    }

    private static List<EnvironmentLookupData> getAvailableTargetEnvironments(Id pipelineId, AddEnvironmentData result) {
        List<EnvironmentLookupData> environments = new List<EnvironmentLookupData>();
        Set<Id> environmentIds = new Set<Id>();
        for (
            copado__Deployment_Flow_Step__c connection : new PipelineConnectionsSelector()
                .byPipelineIdInCurrentOrNextStage(pipelineId, result.stageConnection)
        ) {
            if (!environmentIds.contains(connection.copado__Source_Environment__c)) {
                environmentIds.add(connection.copado__Source_Environment__c);
                environments.add(
                    new EnvironmentLookupData(
                        connection.copado__Source_Environment__c,
                        connection.copado__Source_Environment__r.Name,
                        Label.Stage + ': ' + connection.copado__Stage_Connection__r.copado__Stage__r.Name
                    )
                );
            }
        }
        // NOTE: if we are adding to production or a stage previous to production, we need to add last environment manually
        if (
            !environmentIds.contains(result.productionEnvironmentId) &&
            (result.stageConnection.copado__Next_Stage_Connection__c == null ||
            result.stageConnection.copado__Next_Stage_Connection__r.copado__Next_Stage_Connection__c == null)
        ) {
            environments.add(new EnvironmentLookupData(result.productionEnvironmentId, result.productionEnvironmentName, result.productionStageName));
        }
        return environments;
    }

    // WRAPPER

    public with sharing class AddEnvironmentData {
        @AuraEnabled
        public List<EnvironmentLookupData> sourceEnvironments;
        @AuraEnabled
        public List<EnvironmentLookupData> targetEnvironments;
        @AuraEnabled
        public copado__Deployment_Flow__c pipeline;
        @AuraEnabled
        public copado__Stage_Connection__c stageConnection;
        @AuraEnabled
        public String productionEnvironmentId;
        @AuraEnabled
        public String productionEnvironmentName;
        @AuraEnabled
        public String productionStageName;
        @AuraEnabled
        public Boolean isPipelineActive;

        public AddEnvironmentData() {
            this.sourceEnvironments = new List<EnvironmentLookupData>();
            this.targetEnvironments = new List<EnvironmentLookupData>();
        }
    }

    public with sharing class EnvironmentLookupData {
        @AuraEnabled
        public String environmentId;
        @AuraEnabled
        public String environmentName;
        @AuraEnabled
        public String stageName;

        public EnvironmentLookupData(String environmentId, String environmentName, String stageName) {
            this.environmentId = environmentId;
            this.environmentName = environmentName;
            this.stageName = stageName;
        }
    }
}