@isTest
private with sharing class MigrationGitInitializerStatusCheckTest {
    private static final String SFDX_GIT_INITIALIZATION = 'SFDX Git Initialization_1';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void executeWithErroredJob() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(copado__Status__c = 'Error', copado__Template__c = templateId);
            insert job;
            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__Type__c = 'Flow',
                copado__ConfigJson__c = '{"flowName" : "MockedFlow"}',
                Name = 'Take logs',
                copado__JobExecution__c = job.Id
            );
            insert jobStep;
            copado__Result__c result = new copado__Result__c(
                copado__Job_Type__c = 'Integration',
                copado__Status__c = 'Failed',
                copado__JobStep__c = jobStep.Id
            );
            insert result;
            jobStep.copado__Result__c = result.Id;
            update jobStep;

            // EXERCISE
            MigrationGitInitializerStatusCheck.Request request = new MigrationGitInitializerStatusCheck.Request();
            request.jobId = job.Id;
            request.jobStatus = 'Error';
            List<MigrationGitInitializerStatusCheck.Request> requests = new List<MigrationGitInitializerStatusCheck.Request>{ request };
            List<MigrationGitInitializerStatusCheck.Response> responses = MigrationGitInitializerStatusCheck.execute(requests);

            // VERIFY
            Assert.isFalse(responses[0].isProjectInitialized, 'The property in response is true');
        }
    }

    @IsTest
    private static void executeWithErroredJobAndFailedResultData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id templateId = [SELECT Id FROM copado__JobTemplate__c].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(copado__Status__c = 'Error', copado__Template__c = templateId);
            insert job;
            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__Type__c = 'Flow',
                copado__ConfigJson__c = '{"flowName" : "MockedFlow"}',
                Name = 'Take logs',
                copado__JobExecution__c = job.Id
            );
            insert jobStep;
            copado__Result__c result = new copado__Result__c(
                copado__Job_Type__c = 'Integration',
                copado__Status__c = 'Failed',
                copado__JobStep__c = jobStep.Id,
                copado__Result_Data__c = '{"projectInitialized" : false}'
            );
            insert result;
            jobStep.copado__Result__c = result.Id;
            update jobStep;

            // EXERCISE
            MigrationGitInitializerStatusCheck.Request request = new MigrationGitInitializerStatusCheck.Request();
            request.jobId = job.Id;
            request.jobStatus = 'Error';
            List<MigrationGitInitializerStatusCheck.Request> requests = new List<MigrationGitInitializerStatusCheck.Request>{ request };
            List<MigrationGitInitializerStatusCheck.Response> responses = MigrationGitInitializerStatusCheck.execute(requests);

            // VERIFY
            Assert.isFalse(responses[0].isProjectInitialized, 'The property in response is true');
        }
    }

    @IsTest
    private static void executeWithErroredJobAndTrueResultData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Id templateId = [SELECT Id FROM copado__JobTemplate__c WHERE Name = 'SFDX Git Initialization'].Id;
            copado__JobExecution__c job = new copado__JobExecution__c(copado__Status__c = 'Error', copado__Template__c = templateId);
            insert job;
            copado__JobStep__c jobStep = new copado__JobStep__c(
                copado__Type__c = 'Flow',
                copado__ConfigJson__c = '{"flowName" : "MockedFlow"}',
                Name = 'Take logs',
                copado__JobExecution__c = job.Id
            );
            insert jobStep;
            copado__Result__c result = new copado__Result__c(
                copado__Job_Type__c = 'Integration',
                copado__Status__c = 'Failed',
                copado__JobStep__c = jobStep.Id,
                copado__Result_Data__c = '{"projectInitialized" : true}'
            );
            insert result;
            jobStep.copado__Result__c = result.Id;
            update jobStep;

            // EXERCISE
            Test.startTest();

            System.debug('This is a test');

            MigrationGitInitializerStatusCheck.Request request = new MigrationGitInitializerStatusCheck.Request();
            request.jobId = job.Id;
            request.jobStatus = 'Error';
            List<MigrationGitInitializerStatusCheck.Request> requests = new List<MigrationGitInitializerStatusCheck.Request>{ request };
            List<MigrationGitInitializerStatusCheck.Response> responses = MigrationGitInitializerStatusCheck.execute(requests);

            Test.stopTest();

            // VERIFY
            Assert.isTrue(responses[0].isProjectInitialized, 'The property in response is false');
        }
    }

    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            JobTemplate jobTemplate = new JobTemplate().name('SFDX Git Initialization');
            new JobStep(jobTemplate).name('Initialize').type('Function');

            new Project();

            new Repository().name('DX');
            Environment dev1 = new Environment().name('Dev1');
            Environment staging = new Environment().name('Staging');
            new Credential(dev1).default(true).orgId('a00X');
            new Credential(staging).default(true).orgId('a00Y').persist();

            copado__JobTemplate__c template = [SELECT Id, Name, copado__ApiName__c FROM copado__JobTemplate__c LIMIT 1];
            template.copado__ApiName__c = SFDX_GIT_INITIALIZATION;
            update template;
        }
    }
}