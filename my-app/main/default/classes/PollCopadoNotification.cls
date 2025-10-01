public with sharing class PollCopadoNotification implements Schedulable {
    private String backendJobId;
    private Id recordId;
    private Id resultId;
    private Id credentialId;
    private Integer iteration;

    @TestVisible
    private static final String METADATA_FILE_NAME = 'MetaData';

    // CTR
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public PollCopadoNotification(String backendJobId, Id resultId, Integer iteration, Id credentialId) {
        this.backendJobId = backendJobId;
        this.resultId = resultId;
        this.credentialId = credentialId;
        this.iteration = iteration;
    }

    // PUBLIC
    public void execute(SchedulableContext sc) {
        try {
            List<copado__Copado_Notification__c> copadoNotifications = new CopadoNotificationSelector().byParent2Ids(new Set<String>{ backendJobId });

            if (copadoNotifications.isEmpty()) {
                // 120 iterations are 10 minutes not receiving Copado Notification RecordId
                if (iteration > 120) {
                    publishFailureEvent('Time Out', resultId);
                    return;
                }
                iteration++;
                scheduleJob(backendJobId, resultId, iteration, credentialId);
            } else {
                String status = getJobStatus(copadoNotifications[0]);
                switch on status {
                    when 'Success' {
                        List<ContentDocumentLink> contentDocumentLinks = getContentDocumentLinks(
                            copadoNotifications[0].copado__ParentId__c,
                            METADATA_FILE_NAME
                        );
                        if (contentDocumentLinks.isEmpty()) {
                            throw new ApplicationException(Label.No_Metadata_File_Found);
                        } else if (contentDocumentLinks.size() > 1) {
                            UserStoryMetadataListCtlr.executeFunctionToFindDeletedMetadata(copadoNotifications[0].copado__ParentId__c);
                        }
                        List<ContentVersion> contentVersions = getContentVersions(contentDocumentLinks[0].ContentDocumentId);
                        publishSuccessEvent(contentVersions[0].Id, resultId);
                    }
                    when 'Error' {
                        String errorMessage = getErrorMessages(copadoNotifications[0].copado__Message__c);
                        publishFailureEvent(errorMessage, resultId);
                    }
                    when else {
                        scheduleJob(backendJobId, resultId, 0, credentialId);
                    }
                }
            }
        } catch (Exception ex) {
            publishFailureEvent('Error: ' + ex.getMessage() + ' ' + ex.getStackTraceString(), resultId);
        }
    }

    @AuraEnabled
    public static ProgressStatus getStatusByParent2Id(String copadoJobId) {
        try {
            List<copado__Copado_Notification__c> copadoNotifications = new CopadoNotificationSelector().byParent2Ids(new Set<String>{ copadoJobId });
            if (copadoNotifications.isEmpty()) {
                return new ProgressStatus(false, '');
            }
            return new ProgressStatus(copadoNotifications[0].copado__isFinished__c, copadoNotifications[0].copado__status__c);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    // PRIVATE

    private String getJobStatus(copado__Copado_Notification__c notification) {
        Set<String> errorStatuses = new Set<String>{ 'done', 'error' };
        String result = 'In Progress';
        if (notification.copado__isFinished__c == true && notification.copado__status__c == 'done' && notification.copado__isSuccess__c == true) {
            result = 'Success';
        } else if (
            notification.copado__isFinished__c == true &&
            notification.copado__isSuccess__c == false &&
            errorStatuses.contains(notification.copado__status__c)
        ) {
            result = 'Error';
        }
        return result;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private void scheduleJob(String backendJobId, Id resultId, Integer iteration, Id credentialId) {
        String nextFireCron = calculateNextFireCron();
        System.schedule(
            'Poll Notification.Refresh Metadata ' + credentialId + ' ' + nextFireCron,
            nextFireCron,
            new PollCopadoNotification(backendJobId, resultId, iteration, credentialId)
        );
    }

    private String calculateNextFireCron() {
        CronCalculator result = new CronCalculator();
        return result.nextFireCron(5);
    }

    private void publishFailureEvent(String message, Id resultId) {
        new EventPayload(false, message).publish(resultId);
    }

    private void publishSuccessEvent(Id contentVersionId, Id resultId) {
        new EventPayload(true, '', '{\"contentVersionId\": \"' + contentVersionId + '\"}').publish(resultId);
    }

    private String getErrorMessages(String payload) {
        try {
            List<String> messages = ((Notification) JSON.deserialize(payload, Notification.class)).messages;
            return String.join(messages, '\r\n');
        } catch (Exception ex) {
            return payload;
        }
    }

    private static List<ContentDocumentLink> getContentDocumentLinks(Id linkedEntityId, String title) {
        List<ContentDocumentLink> result = new ContentDocumentLinksSelector()
            .byLinkedEntityIdAndTitles(new Set<Id>{ linkedEntityId }, new Set<String>{ title });
        return result;
    }

    private static List<ContentVersion> getContentVersions(Id contentDocumentId) {
        List<ContentVersion> result = new ContentVersionsSelector().byContentDocumentId(new Set<Id>{ contentDocumentId });
        return result;
    }

    // INNER

    public class ProgressStatus {
        @AuraEnabled
        public Boolean isFinished;
        @AuraEnabled
        public String status;

        public ProgressStatus(Boolean isFinished, String status) {
            this.isFinished = isFinished;
            this.status = status;
        }
    }
    private class Notification {
        public List<String> messages;
    }
}