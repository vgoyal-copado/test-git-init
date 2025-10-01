public with sharing class ExecuteCommitJob implements SchedulerCallback {
    Id userStoryId;
    @TestVisible
    public static UserStoryBundleOperationReconciliation.Request testRequest;

    public ExecuteCommitJob(Id userStoryId) {
        this.userStoryId = userStoryId;
    }
    public void execute() {
        System.debug('### ExecuteCommitJob - execute() INVOKED');
        Id packageVersionId = getPackageVersionId();
        if (packageVersionId == null) {
            throw new ApplicationException('Unable to find the package version id');
        }
        UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
        request.bundleUserStory = new copado__User_Story__c(Id = this.userStoryId);
        request.packageVersionId = packageVersionId;
        if(!Test.isRunningTest()) {
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });
        } else {
            testRequest = request;
        }

        System.debug('### ExecuteCommitJob - testRequest: ' + testRequest);

      
    }

    public Id getPackageVersionId() {
        List<copado__Artifact_Version__c> packageVersions = new PackageVersionsSelector()
            .byUserStoryIdsAndStatus(new Set<Id>{ this.userStoryId }, new Set<String>{ 'Locked' });
        return packageVersions?.size() > 0 ? packageVersions[0].Id : null;
    }
}