public inherited sharing class PipelineInitializationDetails {
    public String initializationType;
    public String status;
    public String completedDate;
    public List<Id> pendingEnvironmentIds;
    public Id currentEnvironmentId;
    public List<ActivityLog> activityLog;
    public Id latestJobExecutionId;
    public Boolean areChangesSelected = false;
    public Boolean pipelineBuilder = false;
    public Long lastDiffAnalysis;
    public String diffAnalysisStatus;
    public List<Id> diffAnalysisJobs;
    public String message;
    public QuickStartConfig quickStart;
    public Boolean skipOrgSnapshot = false;

    public inherited sharing class ActivityLog {
        public Long timestamp;
        public String status;
        public String title;
        public String jobId;
    }

    public inherited sharing class QuickStartConfig {
        public List<QuickStartStep> quickStartSteps;
    }

    public inherited sharing class QuickStartStep {
        public String label;
        public String componentRef;
        public Boolean isActive;
        public Boolean isCompleted;
        public String contextData;
    }
}