@IsTest
private class PollCopadoNotificationTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void copadoNotificationRecordIdNotFinished() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id credentialId = getCredentialId();
            String backendJobId = '85632824-27ae-4e83-9ec4-700a9bad3b84';
            CopadoNotification copadoNotification = new CopadoNotification()
                .parentId(credentialId)
                .isFinished(false)
                .isSuccess(false)
                .parent2Id(backendJobId);
            copadoNotification.persist();

            // EXERCISE
            Test.startTest();
            String nextFireCron = calculateNextFireCron();
            System.schedule('Test 1 ' + nextFireCron, nextFireCron, new PollCopadoNotification(backendJobId, getResultId(), 0, credentialId));
            Test.stopTest();

            // VERIFY
            List<CronTrigger> cronTriggerAssertion = [
                SELECT Id
                FROM CronTrigger
                WHERE CronExpression = :nextfireCron
            ];
            Integer cronTriggerAssertionSize = cronTriggerAssertion.size();
            // Depending on the workload SF enques one or two jobs. Both scenarios are correct.
            Assert.isTrue(cronTriggerAssertionSize >= 1 && cronTriggerAssertionSize <= 2, 'Jobs are not enqueued correctly');
        }
    }

    @IsTest
    private static void copadoNotificationRecordIdIsSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id credentialId = getCredentialId();
            String backendJobId = '85632824-27ae-4e83-9ec4-700a9bad3b84';
            CopadoNotification copadoNotification = new CopadoNotification()
                .parentId(credentialId)
                .isFinished(true)
                .isSuccess(true)
                .status('done')
                .parent2Id(backendJobId);
            copadoNotification.persist();
            createContentVersion(
                PollCopadoNotification.METADATA_FILE_NAME,
                PollCopadoNotification.METADATA_FILE_NAME + '.json',
                credentialId,
                getMetaDataFileContent(2)
            );

            // EXERCISE
            Test.startTest();
            String nextFireCron = calculateNextFireCron();
            System.schedule('Test 2 ' + nextFireCron, nextFireCron, new PollCopadoNotification(backendJobId, getResultId(), 0, credentialId));
            Test.stopTest();

            // VERIFY
            List<CronTrigger> cronTriggerAssertion = [
                SELECT Id
                FROM CronTrigger
                WHERE CronExpression = :nextfireCron
            ];
            Integer cronTriggerAssertionSize = cronTriggerAssertion.size();
            // Depending on the workload SF enques one or two jobs. Both scenarios are correct.
            Assert.isTrue(cronTriggerAssertionSize >= 1 && cronTriggerAssertionSize <= 2, 'Jobs are not enqueued correctly');
        }
    }

    @IsTest
    private static void copadoNotificationRecordIdIsNotSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id credentialId = getCredentialId();
            String backendJobId = '1b576190-0ac6-4fe9-af35-bdb605e4c43c';
            CopadoNotification copadoNotification = new CopadoNotification()
                .parentId(credentialId)
                .isFinished(true)
                .isSuccess(false)
                .parent2Id(backendJobId)
                .status('done')
                .message(
                    '{"messages":["could not upsert Attachment file MetaData on parentId: aKp4M0000008OIASA2"],"copadoJobId":"1b576190-0ac6-4fe9-af35-bdb605e4c43c","type":"MetadataRetriever","isFinished":true,"status":"done","isSuccess":false}'
                );
            copadoNotification.persist();

            // EXERCISE
            Test.startTest();
            String nextFireCron = calculateNextFireCron();
            System.schedule('Test 2 ' + nextFireCron, nextFireCron, new PollCopadoNotification(backendJobId, getResultId(), 0, credentialId));
            Test.stopTest();

            // VERIFY
            List<CronTrigger> cronTriggerAssertion = [
                SELECT Id
                FROM CronTrigger
                WHERE CronExpression = :nextfireCron
            ];
            Integer cronTriggerAssertionSize = cronTriggerAssertion.size();
            // Depending on the workload SF enques one or two jobs. Both scenarios are correct.
            Assert.isTrue(cronTriggerAssertionSize >= 1 && cronTriggerAssertionSize <= 2, 'Jobs are not enqueued correctly');
        }
    }
    
    @IsTest
    private static void copadoNotificationRecordIdIsNotSuccess_ErrorMessageNotDeserializable() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id credentialId = getCredentialId();
            String backendJobId = '1b576190-0ac6-4fe9-af35-bdb605e4c43c';
            CopadoNotification copadoNotification = new CopadoNotification()
                .parentId(credentialId)
                .isFinished(true)
                .isSuccess(false)
                .parent2Id(backendJobId)
                .status('done')
                .message(
                    'Execution failed: payload could not be deserialized.'
                );
            copadoNotification.persist();

            // EXERCISE
            Test.startTest();
            String nextFireCron = calculateNextFireCron();
            System.schedule('Test 2 ' + nextFireCron, nextFireCron, new PollCopadoNotification(backendJobId, getResultId(), 0, credentialId));
            Test.stopTest();

            // VERIFY
            List<CronTrigger> cronTriggerAssertion = [
                SELECT Id
                FROM CronTrigger
                WHERE CronExpression = :nextfireCron
            ];
            List<copado__Copado_Notification__c> notifications = [
                SELECT Id, copado__Message__c
                FROM copado__Copado_Notification__c
                WHERE copado__Parent2Id__c = :backendJobId
                LIMIT 1
            ];
            Integer cronTriggerAssertionSize = cronTriggerAssertion.size();
            String expectedMessage = 'Execution failed: payload could not be deserialized.';
            // Depending on the workload SF enques one or two jobs. Both scenarios are correct.
            Assert.isTrue(cronTriggerAssertionSize >= 1 && cronTriggerAssertionSize <= 2, 'Jobs are not enqueued correctly');
            System.assertEquals(expectedMessage, notifications[0].copado__Message__c, 'The message should indicate a deserialization failure');
        }
    }

    @IsTest
    private static void itearationExceeded() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id credentialId = getCredentialId();
            String backendJobId = '1b576190-0ac6-4fe9-af35-bdb605e4c43c';
            // EXERCISE
            Test.startTest();
            String nextFireCron = calculateNextFireCron();
            String jobId = System.schedule(
                'Iteration exceeded ' + nextFireCron,
                nextFireCron,
                new PollCopadoNotification(backendJobId, getResultId(), 121, credentialId)
            );
            Test.stopTest();

            // VERIFY
            List<CronTrigger> cronTriggerAssertion = [
                SELECT Id
                FROM CronTrigger
                WHERE Id = :jobId
            ];
            Assert.isTrue(!cronTriggerAssertion.isEmpty(), 'A new job must be enqueued');
        }
    }

    @IsTest
    private static void testgetStatusByParent2IdWhenRecordExists() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id credentialId = getCredentialId();
            String copadoJobId = 'copado-job-id';
            new CopadoNotification().parentId(credentialId).isFinished(true).isSuccess(true).status('done').parent2Id(copadoJobId).persist();

            // EXERCISE

            PollCopadoNotification.ProgressStatus result = PollCopadoNotification.getStatusByParent2Id(copadoJobId);

            // VERIFY

            Assert.areEqual('done', result.status, 'The status should be done and not ' + result.status);
            Assert.areEqual(true, result.isFinished, 'isFinished should be true');
        }
    }

    @IsTest
    private static void testgetStatusByParent2IdWhenRecordDoesNotExist() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            String copadoJobId = 'copado-job-id';

            // EXERCISE

            PollCopadoNotification.ProgressStatus result = PollCopadoNotification.getStatusByParent2Id(copadoJobId);

            // VERIFY
            Assert.areEqual('', result.status, 'The status should be blank and not ' + result.status);
            Assert.areEqual(false, result.isFinished, 'isFinished should be false');
        }
    }

    private static void createData() {
        Credential credential = new Credential(new Environment().type('Production/Developer')).type('Production/Developer');
        new Attachment_t().name('MetaData').parent(credential).body(Blob.valueOf(''));
        new Result().type('Integration').status('Success').data('{"commitId":"sampleCommitId"}').persist();
    }

    private static Id getCredentialId() {
        return [SELECT Id FROM copado__Org__c LIMIT 1][0].Id;
    }

    private static Id getResultId() {
        return [SELECT Id FROM copado__Result__c LIMIT 1][0].Id;
    }

    private static String calculateNextFireCron() {
        CronCalculator result = new CronCalculator();
        return result.nextFireCron(5);
    }

    private static Blob getMetaDataFileContent(Integer count) {
        List<MetaDataItem> metaDataItems = new List<MetaDataItem>();
        for (Integer i = 0; i < count; i++) {
            metaDataItems.add(TestDataFactory.getMetadataItem('ApexClass', 'SampleClass' + 1, 'Test Test', '1900-01-01'));
        }
        return Blob.valueOf(JSON.serialize(metaDataItems));
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void createContentVersion(String title, String pathOnClient, Id firstPublishLocationId, Blob data) {
        new ContentVersion_t().title(title).pathOnClient(pathOnClient).firstPublishLocationId(firstPublishLocationId).versionData(data).persist();
    }
}