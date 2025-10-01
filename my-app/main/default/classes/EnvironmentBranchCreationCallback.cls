@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidDeeplyNestedIfStmts,PMD.StdCyclomaticComplexity,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
global with sharing class EnvironmentBranchCreationCallback implements copado.JobExecutionCallback {

    private static final Set<String> VALID_ATTACHMENT_TYPES = new Set<String>{
        'Delete MetaData',
        'RetrieveOnly MetaData',
        'Full Profile Permission Set',
        'Git MetaData'
    };

    private static final Map<String, String> SFP_ACTIONS = new Map<String, String>{
        'Git MetaData' => 'Add',
        'RetrieveOnly MetaData' => 'RetrieveOnly',
        'Full Profile Permission Set' => 'Full',
        'Delete MetaData' => 'Delete'
    };

    // Conflict resolution priority order (lowest to highest)
    private static final List<String> OPERATIONS_IN_ORDER_OF_RECONCILIATION = new List<String>{ 
        'RetrieveOnly', 'SelectiveCommit', 'Add', 'Full'
    };

    private static final String DELETE_OPERATION = 'Delete';

    // CONSTRUCTOR
    @SuppressWarnings('PMD.EmptyStatementBlock')
    global EnvironmentBranchCreationCallback() {
        // Empty constructor needed so callback function can be called
    }

    // GLOBAL - EXECUTION CALLBACK
    global void execute(copado__JobExecution__c job, String status) {
        try {
            if (job.copado__Pipeline__c == null) {
                return;
            }
            copado__JobExecution__c jobExecution = new JobExecutionsSelector().byIds(new Set<Id>{ job.Id })[0];

            List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byId(new Set<Id>{ jobExecution?.copado__Pipeline__c });
            if (pipelines.isEmpty()) {
                throw new ApplicationException(Label.NoPipelineFound);
            }

            copado__Deployment_Flow__c pipeline = pipelines[0];

            SfpMigrationDetails.PipelineData pipelineData;
            if (String.isNotBlank(pipeline.Initialization_Data__c)) {
                pipelineData = (SfpMigrationDetails.PipelineData)JSON.deserialize(
                    pipeline.Initialization_Data__c,
                    SfpMigrationDetails.PipelineData.class
                );
            }

            if (status == 'Successful') {
                String environmentId = pipelineData?.currentEnvironmentId;
                String classicPipelineId = pipelineData?.classicPipelineId;
                String userStoryStatusValues = pipelineData?.userStoryStatusValues;

                List<String> statusValues = userStoryStatusValues.split(';');

                List<copado__User_Story__c> userStories = [
                    SELECT Id, Name, copado__Status__c,
                        copado__Environment__c, copado__Environment__r.Name,
                        copado__Project__c, copado__Project__r.Name,
                        copado__Project__r.copado__Deployment_Flow__c,
                        copado__Project__r.copado__Deployment_Flow__r.Name
                    FROM copado__User_Story__c
                    WHERE copado__Environment__c = :environmentId
                    AND copado__Project__r.copado__Deployment_Flow__c = :classicPipelineId
                    AND copado__Project__r.copado__Deployment_Flow__r.copado__Platform__c = 'Salesforce'
                    AND copado__Status__c IN :statusValues
                    WITH USER_MODE
                    ORDER BY Name ASC
                ];

                if (userStories.isEmpty()) {
                    updateInitializationDataWithNextEnvironment(pipelineData, job, pipeline);
                    new HandleWorkInProgressMigration().createBranches(pipeline);
                } else {
                    Map<Id, List<Attachment>> userStoryAttachments = new Map<Id, List<Attachment>>();
                    for (Attachment att : [
                        SELECT Id, Name, Body, ParentId
                        FROM Attachment
                        WHERE ParentId IN :userStories
                        AND Name IN :VALID_ATTACHMENT_TYPES
                        AND BodyLength > 2
                        WITH USER_MODE
                    ]) {
                        if (!userStoryAttachments.containsKey(att.ParentId)) {
                            userStoryAttachments.put(att.ParentId, new List<Attachment>());
                        }
                        userStoryAttachments.get(att.ParentId).add(att);
                    }
                    List<copado__Project__c> projects = [
                        SELECT Id FROM copado__Project__c
                        WHERE copado__Deployment_Flow__c = :pipeline.Id
                        WITH USER_MODE
                        LIMIT 1
                    ];
                    Id projectId = projects.isEmpty() ? null : projects[0].Id;

                    Id credentialId = null;
                    if (String.isNotBlank(pipelineData?.connections) && environmentId != null) {
                        List<SfpMigrationDetails.Connection> connections =
                            (List<SfpMigrationDetails.Connection>)JSON.deserialize(
                                pipelineData.connections,
                                List<SfpMigrationDetails.Connection>.class
                            );

                        for (SfpMigrationDetails.Connection conn : connections) {
                            if (conn.destinationEnvId == environmentId) {
                                credentialId = conn.destinationDefaultCredentialId;
                                break;
                            }
                        }
                    }

                    // Create new SFP User Story
                    copado__User_Story__c sfpUS = new copado__User_Story__c(
                        copado__User_Story_Title__c = 'MFP2SFP User Story',
                        copado__Project__c = projectId,
                        copado__Status__c = 'Development In Progress',
                        copado__Org_Credential__c = credentialId,
                        RecordTypeId = getUSRecordTypeId()
                    );
                    insert as system sfpUS;

                    List<MetadataComponent> allComponents = new List<MetadataComponent>();

                    for (copado__User_Story__c us : userStories) {
                        List<Attachment> attachments = userStoryAttachments.get(us.Id);
                        if (attachments == null) {
                            continue;
                        }

                        for (Attachment att : attachments) {
                            String jsonBody = att.Body.toString();
                            List<Object> components = (List<Object>)JSON.deserializeUntyped(jsonBody);

                            for (Object comp : components) {
                                Map<String, Object> metadata = (Map<String, Object>)comp;
                                
                                MetadataComponent component = new MetadataComponent();
                                component.type = String.valueOf(metadata.get('t'));
                                component.name = String.valueOf(metadata.get('n'));
                                component.action = SFP_ACTIONS.get(att.Name);
                                component.moduleDirectory = 'force-app/main/default';
                                component.category = 'SFDX';

                                allComponents.add(component);
                            }
                        }
                    }

                    // Apply conflict resolution
                    Map<String, MetadataComponent> reconciledComponents = reconcileComponents(allComponents);

                    List<copado.Actions.CommitChange> commitChanges = new List<copado.Actions.CommitChange>();

                    for (MetadataComponent component : reconciledComponents.values()) {
                        copado.Actions.CommitChange change = new copado.Actions.CommitChange();
                        change.t = component.type;
                        change.n = component.name;
                        change.m = component.moduleDirectory;
                        change.a = component.action;
                        change.c = component.category;

                        commitChanges.add(change);
                    }

                    copado.Actions.CommitRequest request = new copado.Actions.CommitRequest();

                    request.changes = commitChanges;
                    request.otherInformation = JSON.serialize(new CommitOtherInformation(environmentId, pipeline.Id));
                    request.message = sfpUS.copado__User_Story_Title__c;
                    request.userStoryId = sfpUS.Id;
                    request.actionCallback = HandleWorkInProgressMigration.class.getName();

                    copado.Actions.CommitResult commitResult = copado.Actions.CommitService.execute(request);

                    updateDataWithCommitJobAndNextEnv(pipelineData, commitResult.jobExecution.Id, pipeline.Id);
                }
            } else {
                updateBranchCreationFailure(pipelineData, status, job);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // PRIVATE

    private Map<String, MetadataComponent> reconcileComponents(List<MetadataComponent> allComponents) {
        Map<String, MetadataComponent> reconciledComponentsByTypeAndName = new Map<String, MetadataComponent>();
        Set<String> conflictingComponentsTypeAndName = new Set<String>();
        Set<String> destructiveComponents = new Set<String>();
        Set<String> otherOperationComponents = new Set<String>();
        String key = '';

        for (MetadataComponent currentComponent : allComponents) {
            key = getUniqueKey(currentComponent);
            handleChange(
                reconciledComponentsByTypeAndName,
                conflictingComponentsTypeAndName,
                destructiveComponents,
                otherOperationComponents,
                currentComponent
            );
            
            if (!conflictingComponentsTypeAndName.contains(key)) {
                if (reconciledComponentsByTypeAndName.containsKey(key)) {
                    MetadataComponent previousComponent = reconciledComponentsByTypeAndName.get(key);
                    reconciledComponentsByTypeAndName.put(key, reconcile(previousComponent, currentComponent));
                } else {
                    reconciledComponentsByTypeAndName.put(key, currentComponent);
                }
            }
        }
        return reconciledComponentsByTypeAndName;
    }

    private Boolean isDestructiveChange(MetadataComponent component) {
        return component.action == DELETE_OPERATION;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private void handleChange(
        Map<String, MetadataComponent> reconciledComponentsByTypeAndName,
        Set<String> conflictingComponentsTypeAndName,
        Set<String> destructiveComponents,
        Set<String> otherOperationComponents,
        MetadataComponent component
    ) {
        String key = getUniqueKey(component);
        if (!conflictingComponentsTypeAndName.contains(key)) {
            if (isDestructiveChange(component)) {
                destructiveComponents.add(key);
                if (otherOperationComponents.contains(key)) {
                    conflictingComponentsTypeAndName.add(key);
                    reconciledComponentsByTypeAndName.remove(key);
                }
            } else {
                otherOperationComponents.add(key);
                if (destructiveComponents.contains(key)) {
                    conflictingComponentsTypeAndName.add(key);
                    reconciledComponentsByTypeAndName.remove(key);
                }
            }
        }
    }

    private String getUniqueKey(MetadataComponent component) {
        return component.type + '/' + component.name;
    }

    private MetadataComponent reconcile(MetadataComponent previousComponent, MetadataComponent currentComponent) {
        MetadataComponent result = previousComponent;
        Integer positionOfPreviousOperation = OPERATIONS_IN_ORDER_OF_RECONCILIATION.indexOf(previousComponent.action);
        Integer positionOfCurrentOperation = OPERATIONS_IN_ORDER_OF_RECONCILIATION.indexOf(currentComponent.action);
        
        if (positionOfCurrentOperation > positionOfPreviousOperation) {
            result = currentComponent;
        }
        
        return result;
    }

    private Id getUSRecordTypeId() {
        return Schema.SObjectType.copado__User_Story__c.getRecordTypeInfosByDeveloperName()
            .get('User_Story')
            .getRecordTypeId();
    }

    private void updateBranchCreationFailure(SfpMigrationDetails.PipelineData currentPipelineData, String status, copado__JobExecution__c job) {
        currentPipelineData.status = Label.BranchesCreationFailed;
        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = job.copado__Pipeline__c,
            Initialization_Data__c = JSON.serialize(currentPipelineData)
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }

    private void updateInitializationDataWithNextEnvironment(SfpMigrationDetails.PipelineData currentPipelineData, copado__JobExecution__c job, copado__Deployment_Flow__c pipeline) {
        if (!currentPipelineData.pendingEnvironmentIds.isEmpty()) {
            currentPipelineData.pendingEnvironmentIds.remove(0);
            currentPipelineData.currentEnvironmentId = !currentPipelineData.pendingEnvironmentIds.isEmpty() ? currentPipelineData.pendingEnvironmentIds[0] : null;
        }
        if (currentPipelineData.pendingEnvironmentIds.isEmpty()) {
            currentPipelineData.status = Label.BranchesCreated;
            currentPipelineData.completedDate = System.now().toString();
        }

        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = job.copado__Pipeline__c,
            Initialization_Data__c = JSON.serialize(currentPipelineData)
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }

    private void updateDataWithCommitJobAndNextEnv(SfpMigrationDetails.PipelineData currentPipelineData, Id commitJobId, Id pipelineId) {
        if (!currentPipelineData.pendingEnvironmentIds.isEmpty()) {
            currentPipelineData.pendingEnvironmentIds.remove(0);
            currentPipelineData.currentEnvironmentId = !currentPipelineData.pendingEnvironmentIds.isEmpty() ? currentPipelineData.pendingEnvironmentIds[0] : null;
        }
        if (currentPipelineData.pendingEnvironmentIds.isEmpty()) {
            currentPipelineData.status = Label.BranchesCreated;
            currentPipelineData.completedDate = System.now().toString();
        }

        if (currentPipelineData.jobIds == null) {
            currentPipelineData.jobIds = new List<Id>();
        }

        currentPipelineData.jobIds.add(commitJobId);

        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = pipelineId,
            Initialization_Data__c = JSON.serialize(currentPipelineData)
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }

    // INNER

    private class CommitOtherInformation {
        public Id environmentId;
        public Id pipelineId;

        public CommitOtherInformation(Id environmentId, Id pipelineId) {
            this.environmentId = environmentId;
            this.pipelineId = pipelineId;
        }
    }

    private class MetadataComponent {
        public String type;
        public String name;
        public String action;
        public String moduleDirectory;
        public String category;
    }
}