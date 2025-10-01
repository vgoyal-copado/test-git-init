@SuppressWarnings('PMD.ExcessiveParameterList,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
public with sharing class CloneClassicPipelineToSourceFormat {
    private static final Set<String> NON_SFP_FIELDS = new Set<String>{
        'copado__apply_connection_behaviours_to_existing__c',
        'copado__branch_management_coordinates__c',
        'copado__continuous_delivery_configuration_json__c',
        'copado__continuous_delivery_enabled__c',
        'copado__copado_dx_mode__c',
        'copado__enable_copado_dx__c',
        'copado__exclude_from_auto_resolve__c',
        'copado__flow_step_coordinates__c',
        'copado__platform__c',
        'copado__static_code_analysis_settings__c'
    };

    // PUBLIC
    @InvocableMethod(
        label='Clone Classic Pipeline'
        description='This method clones the classic pipeline into a Source Format Pipeline'
        category='MFP Migration'
    )
    public static List<Response> execute(List<Request> requests) {
        try {
            Id pipelineId = requests[0].pipelineId;
            Id repositoryId = requests[0].repositoryId;

            Id sfpPipelineId = clonePipeline(pipelineId, repositoryId);
            List<copado__Deployment_Flow_Step__c> classicPipelineConnections = getPipelineConnections(pipelineId);
            updateExistingEnvironmentsToSfdxPlatform(classicPipelineConnections);
            Set<String> branches = clonePipelineConnectionsAndGetBranches(classicPipelineConnections, sfpPipelineId);
            reassignFindAndReplace(pipelineId, sfpPipelineId);
            reassignSystemProperties(pipelineId, sfpPipelineId);
            cloneProject(pipelineId, sfpPipelineId);

            updateJobExecutionDataJson(requests[0].jobExecutionId, sfpPipelineId, pipelineId, branches, classicPipelineConnections);
            return new List<Response>{ new Response(sfpPipelineId) };
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    // PRIVATE
    private static List<SfpMigrationDetails.Connection> getOrderedConnections(List<copado__Deployment_Flow_Step__c> classicPipelineConnections) {
        List<SfpMigrationDetails.Connection> orderedConnections = new List<SfpMigrationDetails.Connection>();

        // Build maps
        Map<String, Id> branchToEnvMap = new Map<String, Id>();
        Map<String, Id> destBranchToEnvMap = new Map<String, Id>();
        Map<Id, List<copado__Deployment_Flow_Step__c>> connectionsByDestination = new Map<Id, List<copado__Deployment_Flow_Step__c>>();
        Set<Id> sourceEnvIds = new Set<Id>();
        Set<Id> destinationEnvIds = new Set<Id>();

        for (copado__Deployment_Flow_Step__c step : classicPipelineConnections) {
            sourceEnvIds.add(step.copado__Source_Environment__c);
            destinationEnvIds.add(step.copado__Destination_Environment__c);

            if (!connectionsByDestination.containsKey(step.copado__Destination_Environment__c)) {
                connectionsByDestination.put(step.copado__Destination_Environment__c, new List<copado__Deployment_Flow_Step__c>());
            }
            connectionsByDestination.get(step.copado__Destination_Environment__c).add(step);

            if (step.copado__Branch__c != null && step.copado__Source_Environment__c != null) {
                branchToEnvMap.put(step.copado__Branch__c, step.copado__Source_Environment__c);
            }
            if (step.copado__Destination_Branch__c != null && step.copado__Destination_Environment__c != null) {
                destBranchToEnvMap.put(step.copado__Destination_Branch__c, step.copado__Destination_Environment__c);
            }
        }

        // Find last envs (never a source)
        Set<Id> lastEnvIds = new Set<Id>();
        for (Id destId : destinationEnvIds) {
            if (!sourceEnvIds.contains(destId)) {
                lastEnvIds.add(destId);
            }
        }

        Integer orderCounter = 1;
        processConnections(lastEnvIds, connectionsByDestination, orderedConnections, branchToEnvMap, destBranchToEnvMap, orderCounter);

        return orderedConnections;
    }

    private static void processConnections(
        Set<Id> currentEnvIds,
        Map<Id, List<copado__Deployment_Flow_Step__c>> connectionsByDestination,
        List<SfpMigrationDetails.Connection> orderedConnections,
        Map<String, Id> branchToEnvMap,
        Map<String, Id> destBranchToEnvMap,
        Integer orderCounter
    ) {
        if (currentEnvIds.isEmpty()) {
            return;
        }

        Set<Id> nextLevelEnvIds = new Set<Id>();

        for (Id envId : currentEnvIds) {
            if (!connectionsByDestination.containsKey(envId)) {
                continue;
            }

            for (copado__Deployment_Flow_Step__c flowStep : connectionsByDestination.get(envId)) {
                SfpMigrationDetails.Connection conn = new SfpMigrationDetails.Connection();

                conn.branchFrom = flowStep.copado__Destination_Branch__c; // source branch
                conn.branchTo = flowStep.copado__Branch__c; // destination branch

                conn.sourceEnvId = flowStep.copado__Destination_Environment__c;
                conn.destinationEnvId = flowStep.copado__Source_Environment__c;

                conn.sourceDefaultCredentialId = getDefaultCredential(conn.sourceEnvId);
                conn.destinationDefaultCredentialId = getDefaultCredential(conn.destinationEnvId);
                conn.order = orderCounter;

                orderedConnections.add(conn);
                nextLevelEnvIds.add(conn.destinationEnvId);
            }
        }

        processConnections(nextLevelEnvIds, connectionsByDestination, orderedConnections, branchToEnvMap, destBranchToEnvMap, orderCounter + 1);
    }

    private static Id clonePipeline(Id pipelineId, Id repositoryId) {
        String baseQuery = 'SELECT {0} FROM copado__Deployment_Flow__c WHERE Id = :pipelineId WITH SYSTEM_MODE LIMIT 1';

        Schema.DescribeSObjectResult pipelineDescribe = copado__Deployment_Flow__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED);
        Map<String, Schema.SObjectField> pipelineFields = pipelineDescribe.fields.getMap();

        List<String> writeableFieldNames = new List<String>();
        for (String fieldName : pipelineFields.keySet()) {
            Schema.SObjectField field = pipelineFields.get(fieldName);
            if (field.getDescribe().isUpdateable() && !NON_SFP_FIELDS.contains(fieldName)) {
                writeableFieldNames.add(fieldName);
            }
        }

        String query = String.format(baseQuery, new List<String>{ String.join(writeableFieldNames, ',') });
        List<copado__Deployment_Flow__c> pipelineToClone = Database.query(query);
        if (pipelineToClone.isEmpty()) {
            throw new ApplicationException(Label.NoPipelineFound);
        }

        copado__Deployment_Flow__c newPipeline = pipelineToClone[0].clone();
        newPipeline.copado__Block_Commits__c = false;
        newPipeline.copado__Active__c = true;
        newPipeline.copado__Platform__c = 'SFDX';
        newPipeline.copado__Git_Repository__c = repositoryId;
        newPipeline.Name = 'SFP - ' + pipelineToClone[0].Name;

        insert as system newPipeline;

        return newPipeline.Id;
    }

    private static List<copado__Deployment_Flow_Step__c> getPipelineConnections(Id pipelineId) {
        return new PipelineConnectionsSelector().byPipelineId(pipelineId);
    }

    private static Id getDefaultCredential(Id envId) {
        List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(envId);
        if (credentials.isEmpty()) {
            
            throw new ApplicationException(String.format(Label.NoDefaultCredential, new List<String> { envId }));
        }
        return credentials[0].Id;
    }

    private static copado__Deployment_Flow__c getClassicPipeline(Id pipelineId) {
        return new PipelinesSelector().byId(new Set<Id>{ pipelineId })[0];
    }

    private static void updateExistingEnvironmentsToSfdxPlatform(List<copado__Deployment_Flow_Step__c> classicPipelineConnections) {
        Set<Id> envIdsToUpdateToSfdx = new Set<Id>();
        for (copado__Deployment_Flow_Step__c connection : classicPipelineConnections) {
            envIdsToUpdateToSfdx.add(connection.copado__Source_Environment__c);
            envIdsToUpdateToSfdx.add(connection.copado__Destination_Environment__c);
        }

        List<copado__Environment__c> environmentsToMigrate = new List<copado__Environment__c>();
        for (Id envId : envIdsToUpdateToSfdx) {
            copado__Environment__c sfpEnvironment = new copado__Environment__c();
            sfpEnvironment.Id = envId;
            sfpEnvironment.copado__Platform__c = 'SFDX';
            environmentsToMigrate.add(sfpEnvironment);
        }

        update as system environmentsToMigrate;
    }

    private static Set<String> clonePipelineConnectionsAndGetBranches(
        List<copado__Deployment_Flow_Step__c> classicPipelineConnections,
        Id sfpPipelineId
    ) {
        Set<String> branches = new Set<String>();
        List<copado__Deployment_Flow_Step__c> newPipelineConnections = new List<copado__Deployment_Flow_Step__c>();
        for (copado__Deployment_Flow_Step__c connection : classicPipelineConnections) {
            copado__Deployment_Flow_Step__c newConnection = new copado__Deployment_Flow_Step__c();
            newConnection.copado__Deployment_Flow__c = sfpPipelineId;
            newConnection.copado__Source_Environment__c = connection.copado__Source_Environment__c;
            newConnection.copado__Destination_Environment__c = connection.copado__Destination_Environment__c;
            newConnection.copado__Branch__c = connection.copado__Branch__c;
            branches.add(connection.copado__Branch__c);
            newConnection.copado__Destination_Branch__c = connection.copado__Destination_Branch__c;
            branches.add(connection.copado__Destination_Branch__c);
            newPipelineConnections.add(newConnection);
        }
        insert as system newPipelineConnections;

        return branches;
    }

    private static void reassignFindAndReplace(Id pipelineId, Id sfpPipelineId) {
        List<ContentDocumentLink> documentLinks = new ContentDocumentLinksSelector()
            .byLinkedEntityIdAndTitles(new Set<Id>{ pipelineId }, new Set<String>{ 'Copado' });

        if (documentLinks.isEmpty()) {
            return;
        }

        ContentDocumentLink sfpFindAndReplace = documentLinks[0].clone();
        sfpFindAndReplace.LinkedEntityId = sfpPipelineId;
        insert as system sfpFindAndReplace;

        delete as system documentLinks[0];
    }

    private static String getMainBranch(Id pipelineId) {
        copado__Deployment_Flow__c pipeline = getClassicPipeline(pipelineId);
        return pipeline.copado__Main_Branch__c;
    }

    private static void reassignSystemProperties(Id pipelineId, Id sfpPipelineId) {
        List<copado__System_Property__c> propertiesToReassign = new List<copado__System_Property__c>();
        for (copado__System_Property__c systemProperty : [
            SELECT Id, copado__Pipeline__c
            FROM copado__System_Property__c
            WHERE copado__Pipeline__c = :pipelineId
            WITH SYSTEM_MODE
        ]) {
            systemProperty.copado__Pipeline__c = sfpPipelineId;
            propertiesToReassign.add(systemProperty);
        }
        update as system propertiesToReassign;
    }

    private static void cloneProject(Id pipelineId, Id sfpPipelineId) {
        List<copado__Project__c> mfpProject = [
            SELECT Id, Name, copado__Description__c
            FROM copado__Project__c
            WHERE copado__Deployment_Flow__c = :pipelineId
            WITH SYSTEM_MODE
        ];
        if (mfpProject.isEmpty()) {
            throw new ApplicationException(Label.NoProjectFound);
        }

        copado__Project__c sfpProject = new copado__Project__c();
        sfpProject.Name = mfpProject[0].Name + ' SFP';
        sfpProject.copado__Description__c = mfpProject[0].copado__Description__c;
        sfpProject.copado__Deployment_Flow__c = sfpPipelineId;

        insert as system sfpProject;
    }

    private static void updateJobExecutionDataJson(
        String jobExecutionId,
        Id sfpPipelineId,
        Id classicPipelineId,
        Set<String> branches,
        List<copado__Deployment_Flow_Step__c> classicPipelineConnections
    ) {
        copado__JobExecution__c jobExecution = (new JobExecutionsSelector().byIds(new Set<Id>{ jobExecutionId }))[0];
        SfpMigrationDetails dataJson = (SfpMigrationDetails) JSON.deserialize(jobExecution?.copado__DataJson__c, SfpMigrationDetails.class);
        dataJson.sfpPipelineId = sfpPipelineId;
        dataJson.mainBranch = getMainBranch(classicPipelineId);
        dataJson.branches = JSON.serialize(branches);
        dataJson.connections = JSON.serialize(getOrderedConnections(classicPipelineConnections));
        Id finalEnvId = findFinalEnvironment(sfpPipelineId);
        List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(finalEnvId);
        dataJson.credentialId = credentials[0].Id;

        JobExecutionUpdateService.Request request = new JobExecutionUpdateService.Request();
        JobExecutionUpdateService.ValuesToUpdateJson valuesToUpdate = new JobExecutionUpdateService.ValuesToUpdateJson();
        valuesToUpdate.fieldApiName = 'copado__DataJson__c';
        valuesToUpdate.value = JSON.serialize(dataJson);

        request.jobExecutionId = jobExecutionId;
        request.valuesToUpdateJson = JSON.serialize(new List<JobExecutionUpdateService.ValuesToUpdateJson>{ valuesToUpdate });

        JobExecutionUpdateService.execute(new List<JobExecutionUpdateService.Request>{ request });

        List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byId(new Set<Id>{ sfpPipelineId });
        if (pipelines.isEmpty()) {
            throw new ApplicationException(Label.NoPipelineFound);
        }

        SfpMigrationDetails.PipelineData pipelineData = new SfpMigrationDetails.PipelineData();
        pipelineData.connections = dataJson.connections;
        pipelineData.userStoryStatusValues = dataJson.userStoryStatusValues;
        pipelines[0].Initialization_Data__c = JSON.serializePretty(pipelineData);

        Utilities.performDML(pipelines, 'update', AccessLevel.USER_MODE);
    }

    private static Id findFinalEnvironment(Id pipelineId) {
        List<copado__Deployment_Flow_Step__c> pipelineConnections = [
            SELECT Id, copado__Source_Environment__c, copado__Destination_Environment__c
            FROM copado__Deployment_Flow_Step__c
            WHERE copado__Deployment_Flow__c = :pipelineId
            WITH USER_MODE
        ];
        Set<Id> sourceEnvironments = new Set<Id>();
        Set<Id> destinationEnvironments = new Set<Id>();

        for (copado__Deployment_Flow_Step__c connection : pipelineConnections) {
            sourceEnvironments.add(connection.copado__Source_Environment__c);
            destinationEnvironments.add(connection.copado__Destination_Environment__c);
        }

        for (Id destEnvId : destinationEnvironments) {
            if (!sourceEnvironments.contains(destEnvId)) {
                return destEnvId;
            }
        }

        return null;
    }

    // INNER
    public class Request {
        @InvocableVariable(label='Pipeline Id' required=true)
        public String pipelineId;
        @InvocableVariable(label='Repository Id' required=true)
        public String repositoryId;
        @InvocableVariable(label='JobExecution Id')
        public String jobExecutionId;
    }

    public class Response {
        @InvocableVariable
        public Id sfpPipelineId;

        public Response(Id sfpPipelineId) {
            this.sfpPipelineId = sfpPipelineId;
        }
    }
}