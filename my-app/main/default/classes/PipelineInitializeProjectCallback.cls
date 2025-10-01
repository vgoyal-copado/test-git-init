@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.CyclomaticComplexity')
global inherited sharing class PipelineInitializeProjectCallback implements copado.JobExecutionCallback {
    private static final String ERROR = 'Error';
    private static final String SUCCESS = 'Success';
    private static final String CANCELLED = 'Cancelled';
    private static final String IN_PROGRESS = 'In Progress';
    private static final String MAIN_INITIALIZED = 'Main Initialized';
    private static final String ERROR_INITIALIZING_MAIN = 'Error initializing main';

    private String snapshotErrorMessage;

    // CONSTRUCTOR
    @SuppressWarnings('PMD.EmptyStatementBlock')
    global PipelineInitializeProjectCallback() {
        // Empty constructor needed so callback function can be called
    }

    // Execution callback
    global void execute(copado__JobExecution__c job, String status) {
        try {
            if (job.copado__Pipeline__c == null) {
                return;
            }
            copado__Deployment_Flow__c pipeline = getPipeline(job?.copado__Pipeline__c);

            if (String.isBlank(pipeline.Initialization_Data__c)) {
                throw new ApplicationException(String.format(Label.MissingRequiredParameters, new List<String>{ Label.PipelineInitializationData }));
            }

            if (status == 'Successful' || (status == 'Error' && isProjectInitialized(job.Id))) {
                executeProjectInit(pipeline);
            } else {
                String initializationData = getInitializationDataByStatus(status, pipeline.Initialization_Data__c, null);
                updateInitializationData(pipeline, initializationData);
                notifyViaEmail(job);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    // PRIVATE

    private void executeProjectInit(copado__Deployment_Flow__c pipeline) {
        String initializationData;

        PipelineInitializationDetails initData = (PipelineInitializationDetails) JSON.deserialize(
            pipeline.Initialization_Data__c,
            PipelineInitializationDetails.class
        );
        if (initData.skipOrgSnapshot != null && initData.skipOrgSnapshot) {
            initializationData = getInitializationDataByStatus('Skip snapshot', pipeline.Initialization_Data__c, null);
        } else {
            Id snapshotJobId = getSnapshotId(pipeline);
            if (snapshotJobId == null) {
                initializationData = getInitializationDataByStatus('Snapshot record failure', pipeline.Initialization_Data__c, null);
            } else {
                initializationData = getInitializationDataByStatus('Successful', pipeline.Initialization_Data__c, snapshotJobId);
            }
        }

        updateInitializationData(pipeline, initializationData);
    }

    private void updateInitializationData(copado__Deployment_Flow__c pipeline, String initializationData) {
        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = pipeline.Id,
            Initialization_Data__c = initializationData
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }

    private String getInitializationDataByStatus(String status, String initializationData, Id jobId) {
        String result;

        switch on status {
            when 'Successful' {
                result = getInitializationDataForSuccess(initializationData, jobId);
            }
            when 'Error' {
                result = getInitializationDataForFailure(initializationData, status);
            }
            when 'Snapshot record failure' {
                result = getInitializationDataForSnapshotFailure(initializationData);
            }
            when 'Canceled' {
                result = getInitializationDataForFailure(initializationData, status);
            }
            when 'Skip snapshot' {
                result = getInitializationDataForSkipSnapshot(initializationData);
            }
        }

        return result;
    }

    private String getInitializationDataForSuccess(String initializationData, Id jobId) {
        PipelineInitializationDetails currentInitializationData = (PipelineInitializationDetails) JSON.deserialize(
            initializationData,
            PipelineInitializationDetails.class
        );

        currentInitializationData.latestJobExecutionId = jobId;

        PipelineInitializationDetails.ActivityLog logEntryForSnapshot = new PipelineInitializationDetails.ActivityLog();
        logEntryForSnapshot.status = IN_PROGRESS;
        logEntryForSnapshot.timestamp = System.now().getTime();
        logEntryForSnapshot.title = Label.SnapshotMessage;
        logEntryForSnapshot.jobId = jobId;

        if (currentInitializationData.activityLog == null || currentInitializationData.activityLog.isEmpty()) {
            currentInitializationData.activityLog = new List<PipelineInitializationDetails.ActivityLog>();
        } else {
            updateGitInitLogEntry(currentInitializationData.activityLog, SUCCESS);
        }

        currentInitializationData.activityLog.add(logEntryForSnapshot);

        return JSON.serializePretty(currentInitializationData);
    }

    private String getInitializationDataForSkipSnapshot(String initializationData) {
        PipelineInitializationDetails currentInitializationData = (PipelineInitializationDetails) JSON.deserialize(
            initializationData,
            PipelineInitializationDetails.class
        );

        if (currentInitializationData.activityLog == null || currentInitializationData.activityLog.isEmpty()) {
            currentInitializationData.activityLog = new List<PipelineInitializationDetails.ActivityLog>();
        } else {
            updateGitInitLogEntry(currentInitializationData.activityLog, SUCCESS);
        }

        currentInitializationData.status = MAIN_INITIALIZED;

        return JSON.serializePretty(currentInitializationData);
    }

    private String getInitializationDataForFailure(String initializationData, String status) {
        PipelineInitializationDetails currentInitializationData = (PipelineInitializationDetails) JSON.deserialize(
            initializationData,
            PipelineInitializationDetails.class
        );

        if (!currentInitializationData.activityLog.isEmpty()) {
            updateGitInitLogEntry(currentInitializationData.activityLog, status == ERROR ? ERROR : CANCELLED);
        }

        currentInitializationData.status = ERROR_INITIALIZING_MAIN;

        return JSON.serializePretty(currentInitializationData);
    }

    private String getInitializationDataForSnapshotFailure(String initializationData) {
        PipelineInitializationDetails currentInitializationData = (PipelineInitializationDetails) JSON.deserialize(
            initializationData,
            PipelineInitializationDetails.class
        );

        PipelineInitializationDetails.ActivityLog logEntryForSnapshot = new PipelineInitializationDetails.ActivityLog();
        logEntryForSnapshot.status = ERROR;
        logEntryForSnapshot.timestamp = System.now().getTime();
        logEntryForSnapshot.title = Label.SnapshotCreationError;

        if (currentInitializationData.activityLog == null || currentInitializationData.activityLog.isEmpty()) {
            currentInitializationData.activityLog = new List<PipelineInitializationDetails.ActivityLog>();
        } else {
            updateGitInitLogEntry(currentInitializationData.activityLog, SUCCESS);
        }

        currentInitializationData.activityLog.add(logEntryForSnapshot);
        currentInitializationData.message = snapshotErrorMessage;

        return JSON.serializePretty(currentInitializationData);
    }

    private void updateGitInitLogEntry(List<PipelineInitializationDetails.ActivityLog> activityLog, String status) {
        for (PipelineInitializationDetails.ActivityLog log : activityLog) {
            if (String.isNotBlank(log.title) && log.title.equalsIgnoreCase(Label.InitializeProject)) {
                log.status = status;
                log.timestamp = System.now().getTime();
                break;
            }
        }
    }

    private Id getSnapshotId(copado__Deployment_Flow__c pipeline) {
        Id mainCredentialId;
        String snapshotRecordName;

        copado__Environment__c finalEnvironment = new PipelineDescriptor(pipeline?.Id).findFinalEnvironment();
        if (finalEnvironment != null) {
            List<copado__Org__c> credentials = new CredentialsSelector().byEnvironmentIdAndValidationCheck(new Set<Id>{ finalEnvironment.Id });
            mainCredentialId = credentials.isEmpty() ? '' : credentials[0].Id;
            snapshotRecordName = String.format(Label.PipelineInitializerGitSnapshotMessage, new List<String>{ finalEnvironment.Name });
        }

        List<copado__Git_Backup__c> existingSnapshots = new GitSnapshotsSelector()
            .byPipelineCredentialAndName(pipeline, mainCredentialId, snapshotRecordName);

        if (existingSnapshots.isEmpty()) {
            return configureAndTakeSnapshot(pipeline, mainCredentialId, snapshotRecordName);
        } else {
            return takeSnapshot(existingSnapshots[0].Id)?.jobExecution?.Id;
        }
    }

    private copado.Actions.TakeGitSnapshotResult takeSnapshot(Id snapshotId) {
        copado.Actions.TakeGitSnapshotRequest request = new copado.Actions.TakeGitSnapshotRequest();
        request.snapshotId = snapshotId;
        request.message = String.format(Label.PipelineInitializerGitSnapshotMessage, new List<String>{ System.now().format('yyyy-MM-dd') });
        request.actionCallback = PipelineInitializeMainCallback.class.getName();
        return copado.Actions.GitSnapshotService.takeSnapshot(request);
    }

    private Id configureAndTakeSnapshot(copado__Deployment_Flow__c pipeline, Id mainCredentialId, String snapshotRecordName) {
        copado.Actions.TakeGitSnapshotResult result;
        try {
            copado.Actions.ConfigureGitSnapshotRequest configureSnapshotRequest = new copado.Actions.ConfigureGitSnapshotRequest();
            configureSnapshotRequest.name = snapshotRecordName;
            configureSnapshotRequest.branch = pipeline?.copado__Main_Branch__c;
            configureSnapshotRequest.credentialId = mainCredentialId;
            configureSnapshotRequest.repositoryId = pipeline?.copado__Git_Repository__c;
            configureSnapshotRequest.pipelineId = pipeline?.Id;
            configureSnapshotRequest.additionalInformation = '{"bypassActivePipelineValidation": true}';
            configureSnapshotRequest.scope = new DefaultSnapshotScopeConfiguration(pipeline?.Id).generate();
            copado__Git_Backup__c snapshot = copado.Actions.GitSnapshotService.configure(configureSnapshotRequest).snapshot;

            result = takeSnapshot(snapshot.Id);
        } catch (Exception ex) {
            snapshotErrorMessage = ex.getMessage();
            return null;
        }

        return result.jobExecution.Id;
    }

    private Boolean isProjectInitialized(Id jobId) {
        Boolean result = false;

        List<copado__Result__c> jobStepResults = new ResultsSelector().byJobExecutionId(jobId);

        if (!jobStepResults.isEmpty() && String.isNotBlank(jobStepResults[0].copado__Result_Data__c)) {
            ResultData resultData = (ResultData) JSON.deserialize(jobStepResults[0].copado__Result_Data__c, ResultData.class);
            result = resultData.projectInitialized;
        }

        return result;
    }

    private copado__Deployment_Flow__c getPipeline(Id pipelineId) {
        return new PipelinesSelector().byId(new Set<Id>{ pipelineId })[0];
    }

    private void notifyViaEmail(copado__JobExecution__c job) {
        copado.CopadoNotifications.SendRequest request = new copado.CopadoNotifications.SendRequest();

        request.name = 'Failed_Git_Initialization';
        request.recipientIds = new Set<Id>{ UserInfo.getUserId() };
        request.mergeData = new Map<String, String>{
            'JobExecutionName' => job.Name,
            'JobExecutionLink' => getExternalLink(job.Id),
            'UserName' => UserInfo.getName()
        };

        copado.CopadoNotifications.send(request);
    }

    private String getExternalLink(Id recordId) {
        return URL.getOrgDomainUrl().toExternalForm() + '/' + recordId;
    }

    // INNER

    private class ResultData {
        Boolean projectInitialized;
    }
}