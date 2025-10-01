public inherited sharing class SfpMigrationDetails {
    public Id gitRepositoryId;
    public Id sfpPipelineId;
    public Id gitSnapshotId;
    public String uri;
    public String repoName;
    public String provider;
    public Boolean refreshSandboxes;
    public Id classicGitRepositoryId;
    public Id credentialId;
    public String mainBranch;
    public String branches;
    public String connections;
    public Boolean hasWip;
    public String userStoryStatusValues;

    public inherited sharing class Connection {
        public Id sourceEnvId;
        public Id destinationEnvId;
        public Id sourceDefaultCredentialId;
        public Id destinationDefaultCredentialId;
        public String branchFrom;
        public String branchTo;
        public Integer order;
    }

    public inherited sharing class PipelineData {
        public String connections;
        public String status;
        public Id currentEnvironmentId;
        public Id migrationJobId;
        public Id classicPipelineId;
        public List<Id> jobIds;
        public List<Id> pendingEnvironmentIds;
        public String completedDate;
        public Id gitRepositoryId;
        public String userStoryStatusValues;
    }
}