public inherited sharing class PollPipelineInitializerRefreshMetadata implements Schedulable {
    private Set<Id> parentIds;
    private Integer iteration;
    private Id pipelineId;
    private Datetime inputDate;

    // CONSTRUCTOR

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public PollPipelineInitializerRefreshMetadata(Set<Id> credentialIds, Integer iteration, Id pipelineId, Datetime inputDate) {
        this.parentIds = credentialIds;
        this.iteration = iteration;
        this.pipelineId = pipelineId;
        this.inputDate = inputDate;
    }

    // PUBLIC

    public void execute(SchedulableContext sc) {
        try {
            List<copado__Copado_Notification__c> copadoNotifications = new CopadoNotificationSelector()
                .byParentIdsFinishedAndCreatedDate( parentIds, true, inputDate);

            if (!copadoNotifications.isEmpty() && copadoNotifications.size() == parentIds.size()) {
                runDifferenceAnalysis();
            } else {
                if (iteration > 120) {
                    updateInitializationData(pipelineId, getLatestInitializationData(pipelineId));
                    return;
                }
                iteration++;
                scheduleJob(parentIds, iteration, pipelineId, inputDate);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + '_' + ex.getStackTraceString());
        }
    }

    // PRIVATE

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private void scheduleJob(Set<Id> credentialIds, Integer iteration, Id pipelineId, Datetime inputDate) {
        String nextFireCron = calculateNextFireCron();
        System.schedule(
            'Poll for Refresh Metadata ' + String.valueOf(Datetime.now().getTime()) + ' ' + nextFireCron,
            nextFireCron,
            new PollPipelineInitializerRefreshMetadata(credentialIds, iteration, pipelineId, inputDate)
        );
    }

    private String calculateNextFireCron() {
        CronCalculator result = new CronCalculator();
        return result.nextFireCron(5);
    }

    private void runDifferenceAnalysis() {
        if (pipelineId != null) {
            PipelineInitializer.PreSteps.runDifferenceAnalysis(pipelineId);
        }
    }

    private String getLatestInitializationData(Id pipelineId) {
        copado__Deployment_Flow__c pipeline = getPipeline(pipelineId);
        PipelineInitializationDetails currentInitializationData = getCurrentInitializationData(pipeline?.Initialization_Data__c);

        Boolean isFirstDiffTimeout = true;

        if (currentInitializationData.activityLog == null || currentInitializationData.activityLog.isEmpty()) {
            currentInitializationData.activityLog = new List<PipelineInitializationDetails.ActivityLog>();
        } else {
            for (PipelineInitializationDetails.ActivityLog log : currentInitializationData.activityLog) {
                if (String.isNotBlank(log.title) && log.title.equalsIgnoreCase(Label.CalculatingDifferences) && log.status.equalsIgnoreCase('Error')) {
                    isFirstDiffTimeout = false;
                    break;
                }
            }
        }

        if (isFirstDiffTimeout) {
            PipelineInitializationDetails.ActivityLog logEntry = new PipelineInitializationDetails.ActivityLog();
            logEntry.status = 'Error';
            logEntry.timestamp = System.now().getTime();
            logEntry.title = Label.CalculatingDifferences;

            currentInitializationData.activityLog.add(logEntry);
            currentInitializationData.diffAnalysisStatus = 'Error';
        }

        return JSON.serializePretty(currentInitializationData);
    }

    private copado__Deployment_Flow__c getPipeline(Id pipelineId) {
        List<copado__Deployment_Flow__c> pipelines = new PipelinesSelector().byId(new Set<Id>{ pipelineId });
        if (pipelines.isEmpty()) {
            throw new ApplicationException(Label.NoPipelineFound);
        }

        return pipelines[0];
    }

    private PipelineInitializationDetails getCurrentInitializationData(String initializationData) {
        if (String.isBlank(initializationData)) {
            throw new ApplicationException(String.format(Label.MissingRequiredParameters, new List<String> { Label.PipelineInitializationData }));
        }

        return (PipelineInitializationDetails) JSON.deserialize(initializationData, PipelineInitializationDetails.class);
    }

    private void updateInitializationData(Id pipelineId, String latestInitializationData) {
        copado__Deployment_Flow__c pipelineWithInitializationData = new copado__Deployment_Flow__c(
            Id = pipelineId,
            Initialization_Data__c = latestInitializationData
        );
        Utilities.performDML(new List<copado__Deployment_Flow__c>{ pipelineWithInitializationData }, 'update', AccessLevel.USER_MODE);
    }
}