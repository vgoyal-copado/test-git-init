@IsTest
private class GitSizerJobTemplateTest {
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }
    @IsTest
    private static void testResultRecordIsCreatedSuccessfully() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Git_Repository__c repository = [SELECT Id FROM copado__Git_Repository__c LIMIT 1];

            // EXERCISE
            Test.startTest();
            Id resultJobId = GitSizerJobTemplate.execute(repository.Id);
            Test.stopTest();

            // VERIFY
            List<copado__JobExecution__c> executions = [
                SELECT Id
                FROM copado__JobExecution__c
                WHERE copado__ParentRecord_Id__c = :repository.Id
                WITH SYSTEM_MODE
            ];
            System.assert(!executions.isEmpty(), 'Execution must be created');
            System.assert(resultJobId != null, 'Result record should be created');
        }
    }

    @IsTest
    static void testExecuteWithInvalidRepoId() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Test.startTest();
            try {
                GitSizerJobTemplate.execute('invalidId');
                System.assert(false, 'Should have thrown an exception');
            } catch (Exception ex) {
                System.assert(ex.getMessage().length() > 0, 'Error message should not be empty');
            }
            Test.stopTest();
        }
    }

    private static void createData() {
        Repository repository = new Repository().name('Test Repository').uri('https://github.com/test/repo.git');
        new Pipeline(repository).name('Test Pipeline').persist();

        JobTemplate jobTemplate = new JobTemplate().name('Git_Sizer').type('Custom');
        new JobStep(jobTemplate).name('SFDX Deploy').type('Function').persist();
    }
}