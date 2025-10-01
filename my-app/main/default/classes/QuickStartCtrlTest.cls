@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.ExcessiveClassLength')
@IsTest
private class QuickStartCtrlTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    private static final String PERMISSION_SET_LABEL = 'Copado Governance Org Credential Access';

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser('username-admin@myemail.com');
    }

    @IsTest
    private static void getInProgressPipelineTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            PipelineInitializationDetails initializationDetails1 = new PipelineInitializationDetails();
            initializationDetails1.initializationType = 'WIP Full';
            initializationDetails1.status = 'Main Initialized';

            PipelineInitializationDetails initializationDetails2 = new PipelineInitializationDetails();
            PipelineInitializationDetails.QuickStartStep step1 = new PipelineInitializationDetails.QuickStartStep();
            step1.label = 'Create Git Repository';
            step1.isActive = true;
            PipelineInitializationDetails.QuickStartConfig config = new PipelineInitializationDetails.QuickStartConfig();
            config.quickStartSteps = new List<PipelineInitializationDetails.QuickStartStep>{ step1 };
            initializationDetails2.quickStart = config;

            new Pipeline().name('MyPipeline1').mainBranch('main').platform('SFDX').initializationData(JSON.serializePretty(initializationDetails1));
            new Pipeline()
                .name('MyPipeline2')
                .mainBranch('main')
                .platform('SFDX')
                .initializationData(JSON.serializePretty(initializationDetails2))
                .persist();

            // EXERCISE
            copado__Deployment_Flow__c inProgressPipeline = QuickStartCtrl.getInProgressPipeline();

            // VERIFY
            Assert.isNotNull(inProgressPipeline, 'There is no in progress pipeline');
            Assert.areEqual('MyPipeline2', inProgressPipeline.Name, 'The name does not match');
        }
    }

    @IsTest
    private static void getNoProgressPipelineTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            PipelineInitializationDetails initializationDetails1 = new PipelineInitializationDetails();
            initializationDetails1.initializationType = 'WIP Full';
            initializationDetails1.status = 'Main Initialized';

            new Pipeline().name('MyPipeline1').mainBranch('main').platform('SFDX').initializationData(JSON.serializePretty(initializationDetails1));
            new Pipeline().name('MyPipeline2').mainBranch('main').platform('SFDX').persist();

            // EXERCISE
            copado__Deployment_Flow__c inProgressPipeline = QuickStartCtrl.getInProgressPipeline();

            // VERIFY
            Assert.isNull(inProgressPipeline, 'There is an in progress pipeline');
        }
    }

    @IsTest
    private static void getProgressPipelineException() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Exception ex;
            new Pipeline().name('MyPipeline1').mainBranch('main').platform('SFDX').initializationData('HelloWorld').persist();

            // EXERCISE
            try {
                QuickStartCtrl.getInProgressPipeline();
            } catch (Exception exc) {
                ex = exc;
            }

            // VERIFY
            Assert.isNotNull(ex, 'There is no exception');
        }
    }

    @IsTest
    private static void validateQuickStart() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            List<QuickStartCtrl.ValidationStep> validations = QuickStartCtrl.validateQuickStart();

            // VERIFY
            Assert.areEqual('License assigned', validations[0].name, 'The name does not match');
            Assert.areEqual('Run Flows permission', validations[3].name, 'The name does not match');
            Assert.areEqual('Apex Extension Configured', validations[6].name, 'The name does not match');
            Assert.isTrue(validations[0].isValid, 'The licenses are not assigned');
            Assert.isTrue(validations[3].isValid, 'The user does not have run flows permission');
            Assert.isFalse(validations[6].isMandatory, 'This check is not mandatory');
        }
    }

    @IsTest
    private static void getSandboxes() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Environment dev1 = new Environment().name('Dev1');
            copado__Org__c credential = (copado__Org__c) new Credential(dev1).default(true).orgId(fflib_IDGenerator.generate('00D')).persist();

            QuickStartCtrl.mockResponse = JSON.serialize(
                new ProxyOrgResponse(
                    200,
                    '{"records" : [{ "id" : "sandboxId", "licenseType" : "DEVELOPER", "endDate" : "2024-11-18T07:36:38.000+0000" }] }',
                    null,
                    null
                )
            );

            // EXERCISE
            Test.startTest();
            List<QuickStartCtrl.SandboxData> sandboxes = QuickStartCtrl.getSandboxes(credential.Id);
            Test.stopTest();

            // VERIFY
            Assert.areEqual(1, sandboxes.size(), 'One sandbox should be returned');
            Assert.areEqual('2024-11-18T07:36:38Z', sandboxes[0].refreshDate, 'Date should be in ISO 8601 format');
        }
    }

    @IsTest
    private static void getSandboxesException() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Exception ex;
            Environment dev1 = new Environment().name('Dev1');
            copado__Org__c credential = (copado__Org__c) new Credential(dev1).default(true).orgId(fflib_IDGenerator.generate('00D')).persist();

            // EXERCISE
            Test.startTest();
            try {
                QuickStartCtrl.getSandboxes(credential.Id);
            } catch (Exception exc) {
                ex = exc;
            }
            Test.stopTest();

            // VERIFY
            Assert.areEqual('Error getting sandboxes', ex.getMessage(), 'The message does not match');
        }
    }

    @IsTest
    private static void createPipeline() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            new Repository().name('TestRepo').persist();
            Id gitRepoId = [SELECT Id FROM copado__Git_Repository__c LIMIT 1].Id;

            PipelineInitializationDetails initializationDetails1 = new PipelineInitializationDetails();
            initializationDetails1.initializationType = 'WIP Full';
            initializationDetails1.status = 'Main Initialized';

            String initData = JSON.serialize(initializationDetails1);

            // EXERCISE
            Test.startTest();
            copado__Deployment_Flow__c pipeline = QuickStartCtrl.createPipeline(gitRepoId, 'MyPipeline', initData);
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(pipeline, 'A pipeline is not created');
            Assert.areEqual('SFDX', pipeline.copado__Platform__c, 'The platform does not match');
            Assert.areEqual(gitRepoId, pipeline.copado__Git_Repository__c, 'The git repo does not match');
            Assert.areEqual(initData, pipeline.Initialization_Data__c, 'The initialization data does not match');
            Assert.areEqual(false, pipeline.copado__Active__c, 'The pipeline is active');
            Assert.areEqual('main', pipeline.copado__Main_Branch__c, 'The main branch does not match');
        }
    }

    @IsTest
    private static void getOrgs() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Environment dev1 = new Environment().name('Dev1');
            copado__Org__c credential = (copado__Org__c) new Credential(dev1)
                .default(true)
                .username('test@copado.com')
                .orgId(fflib_IDGenerator.generate('00D'))
                .persist();

            // EXERCISE
            Test.startTest();
            List<copado__Org__c> credentials = QuickStartCtrl.getOrgs(new List<Id>{ credential.Id });
            Test.stopTest();

            // VERIFY
            Assert.areEqual(1, credentials.size(), 'The size does not match');
        }
    }

    @IsTest
    private static void isRecalculatingPermissions() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Test.startTest();
            Boolean isRecalculatingPermissions = QuickStartCtrl.isRecalculatingPermissions();
            Test.stopTest();

            // VERIFY
            Assert.isFalse(isRecalculatingPermissions, 'The response does not match');
        }
    }

    @IsTest
    private static void checkPermissionsForAddUsers() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // EXERCISE
            Test.startTest();
            Boolean checkPermissionsForAddUsers = QuickStartCtrl.checkPermissionsForAddUsers();
            Test.stopTest();

            // VERIFY
            Assert.isTrue(checkPermissionsForAddUsers, 'The response does not match');
        }
    }

    @IsTest
    private static void getQualityChecksState() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Test.startTest();
            QuickStartCtrl.QualityChecksState result = QuickStartCtrl.getQualityChecksState();
            Test.stopTest();

            // VERIFY
            Assert.isFalse(result.pmdState, 'The response does not match');
        }
    }

    @IsTest
    private static void createEnvironmentAndOrgs() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            QuickStartCtrl.EnvironmentRequest request1 = new QuickStartCtrl.EnvironmentRequest();
            request1.name = 'Production';
            request1.type = 'Production/Developer';

            QuickStartCtrl.EnvironmentRequest request2 = new QuickStartCtrl.EnvironmentRequest();
            request2.name = 'UAT';
            request2.type = 'Sandbox';

            QuickStartCtrl.EnvironmentRequest request3 = new QuickStartCtrl.EnvironmentRequest();
            request3.name = 'Dev';
            request3.type = 'Sandbox';

            List<QuickStartCtrl.EnvironmentRequest> requests = new List<QuickStartCtrl.EnvironmentRequest>{ request1, request2, request3 };

            // EXERCISE
            Test.startTest();
            Map<String, QuickStartCtrl.Environment> result = QuickStartCtrl.createEnvironmentAndOrgs(requests);
            Test.stopTest();

            // VERIFY
            Assert.areEqual(3, result.size(), 'The response size does not match');
            Assert.isTrue(result.containsKey('Production'), 'The name is not present');
            Assert.isTrue(result.containsKey('UAT'), 'The name is not present');
            Assert.isTrue(result.containsKey('Dev'), 'The name is not present');
        }
    }

    @IsTest
    private static void getLoginUrl() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            copado__Org__c credential = (copado__Org__c) new Credential().name('testCred').persist();
            String startUrl = 'https://salesforce.com/starturl';

            // Exercise
            Test.startTest();
            String result = QuickStartCtrl.getCredentialOAuthEndpoint(credential.Id, startUrl);
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'The result is null');
        }
    }

    @IsTest
    private static void getLoginUrlWithInvalidRequest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Exception expectedException = null;

            // Exercise
            try {
                QuickStartCtrl.getCredentialOAuthEndpoint(null, null);
            } catch (Exception ex) {
                expectedException = ex;
            }

            // Verify
            Assert.isNotNull(expectedException, 'There is no exception');
        }
    }

    @IsTest
    private static void createPipelineConnections() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            PipelineInitializationDetails initializationDetails = new PipelineInitializationDetails();

            PipelineInitializationDetails.QuickStartStep step1 = new PipelineInitializationDetails.QuickStartStep();
            step1.label = 'Create Git Repository';
            step1.isActive = false;
            PipelineInitializationDetails.QuickStartStep step2 = new PipelineInitializationDetails.QuickStartStep();
            step2.label = 'Create Your Pipeline';
            step2.isActive = true;
            step2.contextData = getContextData();

            PipelineInitializationDetails.QuickStartConfig config = new PipelineInitializationDetails.QuickStartConfig();
            config.quickStartSteps = new List<PipelineInitializationDetails.QuickStartStep>{ step1, step2 };
            initializationDetails.quickStart = config;

            copado__Deployment_Flow__c pipeline = (copado__Deployment_Flow__c) new Pipeline()
                .name('MyPipeline1')
                .mainBranch('main')
                .platform('SFDX')
                .initializationData(JSON.serializePretty(initializationDetails))
                .persist();

            // EXERCISE
            Test.startTest();
            QuickStartCtrl.createPipelineConnection(pipeline.Id);
            Test.stopTest();

            // VERIFY
            Integer connectionCount = [SELECT COUNT() FROM copado__Deployment_Flow_Step__c WHERE copado__Deployment_Flow__c = :pipeline.Id];
            Assert.areEqual(3, connectionCount, 'The connection count does not match');
        }
    }

    @IsTest
    private static void createPipelineConnectionsWithExistingConnections() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Environment dev1 = new Environment().name('Dev1');
            Environment staging = new Environment().name('Staging');
            new Credential(dev1).default(true).orgId('a00X');
            new Credential(staging).default(true).orgId('a00Y');

            copado__Deployment_Flow__c pipeline = (copado__Deployment_Flow__c) new Pipeline()
                .name('ValidPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('staging'))
                .persist();

            Integer connectionCountBefore = [SELECT COUNT() FROM copado__Deployment_Flow_Step__c WHERE copado__Deployment_Flow__c = :pipeline.Id];
            Assert.areEqual(1, connectionCountBefore, 'The connection count does not match');

            // EXERCISE
            Test.startTest();
            QuickStartCtrl.createPipelineConnection(pipeline.Id);
            Test.stopTest();

            // VERIFY
            Integer connectionCountAfter = [SELECT COUNT() FROM copado__Deployment_Flow_Step__c WHERE copado__Deployment_Flow__c = :pipeline.Id];
            Assert.areEqual(1, connectionCountAfter, 'The connection count does not match');
        }
    }

    @IsTest
    private static void createPipelineConnectionsException() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Exception ex;
            copado__Deployment_Flow__c pipeline = (copado__Deployment_Flow__c) new Pipeline()
                .name('MyPipeline1')
                .mainBranch('main')
                .platform('SFDX')
                .initializationData('Test Data')
                .persist();

            // EXERCISE
            Test.startTest();
            try {
                QuickStartCtrl.createPipelineConnection(pipeline.Id);
            } catch (Exception exc) {
                ex = exc;
            }
            Test.stopTest();

            // VERIFY
            Integer connectionCount = [SELECT COUNT() FROM copado__Deployment_Flow_Step__c WHERE copado__Deployment_Flow__c = :pipeline.Id];
            Assert.areEqual(0, connectionCount, 'The connection count does not match');
            Assert.isNotNull(ex, 'There is no exception');
            Assert.isTrue(ex.getMessage().containsIgnoreCase('Unexpected character'), 'The exception message does not match');
        }
    }

    // @IsTest
    // private static void shareCredentials() {
    //     System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
    //         // Setup
    //         Exception ex;
    //         createPersona('Release Manager', false);
    //         createPersona('Developer', false);

    //         Environment dev = new Environment().name('Dev');
    //         Environment integration = new Environment().name('Int');
    //         Environment staging = new Environment().name('Staging');
    //         Environment prod = new Environment().name('Production');

    //         new Credential(dev).default(true).orgId(fflib_IDGenerator.generate('00D'));
    //         new Credential(integration).default(true).orgId(fflib_IDGenerator.generate('00D'));
    //         new Credential(staging).default(true).orgId(fflib_IDGenerator.generate('00D'));
    //         new Credential(prod).default(true).orgId(fflib_IDGenerator.generate('00D')).persist();

    //         Map<Id, copado__Org__c> credentialsById = new Map<Id, copado__Org__c>(
    //         [   SELECT Id, Name FROM copado__Org__c]
    //         );
    //         List<String> allCredIds = new List<String>();
    //         List<String> devCredIds = new List<String>();
    //         for (Id credId : credentialsById.keySet()) {
    //             allCredIds.add(credId);
    //             if (devCredIds.size() == 1) {
    //                 devCredIds.add(credId);
    //             }
    //         }

    //         // Exercise
    //         Test.startTest();
    //         try {
    //             QuickStartCtrl.shareCredentialsWithPersona(allCredIds, devCredIds);
    //         } catch (Exception e) {
    //             ex = e;
    //         }
    //         Test.stopTest();

    //         // Verify
    //         Assert.isNull(ex, 'There is no exception');
    //         List<copado__Org__Share> orgShares = [SELECT Id FROM copado__Org__Share];
    //         Assert.isTrue(orgShares.size() > 0, 'Credentials should be shared with the public group');
    //     }
    // }

    @IsTest
    private static void shareCredentialsException() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            copado__Persona_Definition__c persona = new copado__Persona_Definition__c(
                Name = 'Release Manager',
                copado__Is_Standard__c = true,
                copado__Config_Json__c = ''
            );
            insert persona;
        }

        System.runAs(TestUtilities.getRunAsUser()) {
            Exception ex;
            Environment dev = new Environment().name('Dev');
            Environment integration = new Environment().name('Int');
            Environment staging = new Environment().name('Staging');
            Environment prod = new Environment().name('Production');

            new Credential(dev).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(integration).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(staging).default(true).orgId(fflib_IDGenerator.generate('00D'));
            new Credential(prod).default(true).orgId(fflib_IDGenerator.generate('00D')).persist();

            Map<Id, copado__Org__c> credentialsById = new Map<Id, copado__Org__c>([SELECT Id, Name FROM copado__Org__c]);
            List<String> allCredIds = new List<String>();
            for (Id credId : credentialsById.keySet()) {
                allCredIds.add(credId);
            }

            // Exercise
            Test.startTest();
            try {
                QuickStartCtrl.shareCredentialsWithPersona(allCredIds, new List<String>{});
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();

            // Verify
            Assert.isNotNull(ex, 'There is an exception');
            Assert.areEqual('Script-thrown exception', ex.getMessage(), 'The message does not match');
        }
    }

    @IsTest
    private static void getUserCount() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            createPersona('Release Manager', false);
            createPersona('Developer', false);
            createPersona('Quality Engineer', false);
        }

        System.runAs(TestUtilities.getRunAsUser()) {
            // Exercise
            Test.startTest();
            List<QuickStartCtrl.PersonaData> personaData = QuickStartCtrl.getUserCountByPersona();
            Test.stopTest();

            // Verify
            List<String> personaNames = new List<String>();
            for (QuickStartCtrl.PersonaData data : personaData) {
                personaNames.add(data.personaName);
            }
            Assert.areEqual(3, personaData.size(), 'The size does not match');
            Assert.isTrue(personaNames.contains('Developer'), 'The persona is not present');
            Assert.isTrue(personaNames.contains('Release Manager'), 'The persona is not present');
            Assert.isTrue(personaNames.contains('Quality Engineer'), 'The persona is not present');
            Assert.areEqual(0, personaData[0].personaCount, 'The count does not match');
            Assert.areEqual(0, personaData[1].personaCount, 'The count does not match');
            Assert.areEqual(0, personaData[2].personaCount, 'The count does not match');
        }
    }

    @IsTest
    private static void getUsers() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            createPersona('Release Manager', false);
            createPersona('Developer', false);
            createPersona('Quality Engineer', false);
        }

        System.runAs(TestUtilities.getRunAsUser()) {
            // Exercise
            Test.startTest();
            List<QuickStartCtrl.PersonaUser> personaData = QuickStartCtrl.getUsers();
            Test.stopTest();

            // Verify
            Assert.isNotNull(personaData, 'The size does not match');
        }
    }

    // @IsTest
    // private static void getUsersWithSearchTerm() {
    //     User user = TestUtilities.getRunAsUser(ADMIN_USERNAME);
    //     System.runAs(user) {
    //         // Setup
    //         createPersona('Release Manager', false);
    //         createPersona('Developer', false);
    //         createPersona('Quality Engineer', false);
    //         List<Id> fixedSearchResults = new List<Id>{ user.Id };
    //         Test.setFixedSearchResults(fixedSearchResults);
    //     }

    //     System.runAs(TestUtilities.getRunAsUser()) {
    //         // Exercise
    //         Test.startTest();
    //         List<QuickStartCtrl.PersonaUser> personaData = QuickStartCtrl.getUsersWithSearchTerm('search');
    //         Test.stopTest();

    //         // Verify
    //         Assert.isNotNull(personaData, 'The size does not match');
    //     }
    // }

    @IsTest
    private static void addUser() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            copado__Persona_Definition__c devPersona = createPersona('Developer', true);
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Complete', '{"ok": "Response created"}', null));

            // Exercise
            Test.startTest();
            QuickStartCtrl.addUser1(devPersona.Id, new List<String>{ UserInfo.getUserId() });
            QuickStartCtrl.addUser2(devPersona.Id, new List<String>{ UserInfo.getUserId() });
            QuickStartCtrl.addUser3(devPersona.Id, new List<String>{ UserInfo.getUserId() });
            QuickStartCtrl.addUser4(devPersona.Id, new List<String>{ UserInfo.getUserId() });

            Test.stopTest();

            // Verify
            User updatedUser = [SELECT Id, copado__Persona_Id__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            Assert.areEqual(devPersona.Id, updatedUser.copado__Persona_Id__c, 'User record should be linked to persona record');
            Boolean userInGroup = [SELECT COUNT() FROM GroupMember WHERE Group.Name = 'Developer' AND UserOrGroupId = :UserInfo.getUserId()] > 0;
            Assert.isTrue(userInGroup, 'User should be part of the public group of the persona');
        }
    }

    @IsTest
    private static void addUser5() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            Exception ex;
            copado__Persona_Definition__c devPersona = createPersona('Developer', true);
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Complete', '{"ok": "Response created"}', null));
            QuickStartCtrl.addUser4(devPersona.Id, new List<String>{ UserInfo.getUserId() });

            // Exercise
            Test.startTest();
            try {
                QuickStartCtrl.addUser5(devPersona.Id, new List<String>{ UserInfo.getUserId() });
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();

            // Verify
            Assert.isNotNull(ex, 'There is no exception');
        }
    }

    @IsTest
    private static void addUser6() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            Exception ex;
            copado__Persona_Definition__c devPersona = createPersona('Developer', true);
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Complete', '{"ok": "Response created"}', null));
            QuickStartCtrl.addUser4(devPersona.Id, new List<String>{ UserInfo.getUserId() });

            // Exercise
            Test.startTest();
            try {
                QuickStartCtrl.addUser6(devPersona.Id, new List<String>{ UserInfo.getUserId() });
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();

            // Verify
            Assert.isNotNull(ex, 'There is no exception');
        }
    }

    @IsTest
    private static void removeUser() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            copado__Persona_Definition__c devPersona = createPersona('Developer', true);
            User otherUser = TestUtilities.getRunAsUser();
            QuickStartCtrl.addUser1(devPersona.Id, new List<String>{ otherUser.Id });
            QuickStartCtrl.addUser2(devPersona.Id, new List<String>{ otherUser.Id });
            QuickStartCtrl.addUser3(devPersona.Id, new List<String>{ otherUser.Id });

            // Exercise
            Test.startTest();
            QuickStartCtrl.removeUser1(devPersona.Id, new List<String>{ otherUser.Id });
            QuickStartCtrl.removeUser2(devPersona.Id, new List<String>{ otherUser.Id });
            QuickStartCtrl.removeUser3(devPersona.Id, new List<String>{ otherUser.Id });
            Test.stopTest();

            // Verify
            User updatedUser = [SELECT Id, copado__Persona_Id__c FROM User WHERE Id = :otherUser.Id LIMIT 1];
            Assert.areEqual(null, updatedUser.copado__Persona_Id__c, 'User record should be linked to persona record');
            Boolean userInGroup = [SELECT COUNT() FROM GroupMember WHERE Group.Name = 'Developer' AND UserOrGroupId = :otherUser.Id] > 0;
            Assert.isFalse(userInGroup, 'User should be part of the public group of the persona');
        }
    }

    @IsTest
    private static void createQualityGates() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // SETUP
            copado__Deployment_Flow__c pipeline = (copado__Deployment_Flow__c) new Pipeline()
                .name('MyPipeline2')
                .mainBranch('main')
                .platform('SFDX')
                .persist();

            // EXERCISE
            Test.startTest();
            QuickStartCtrl.createQualityGates(pipeline.Id, new List<String>());
            Test.stopTest();

            // VERIFY
            Assert.areEqual(0, [SELECT COUNT() FROM copado__Quality_Gate_Rule__c], 'The count does not match');
        }
    }

    @IsTest
    private static void createQualityGatesException() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // SETUP
            Exception ex;

            copado__Deployment_Flow__c pipeline = (copado__Deployment_Flow__c) new Pipeline()
                .name('MyPipeline2')
                .mainBranch('main')
                .platform('SFDX')
                .persist();

            // EXERCISE
            Test.startTest();
            try {
                QuickStartCtrl.createQualityGates(pipeline.Id, new List<String>{ 'None' });
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();

            // VERIFY
            Assert.areEqual(0, [SELECT COUNT() FROM copado__Quality_Gate_Rule__c], 'The count does not match');
            Assert.isNotNull(ex, 'There is no exception');
            Assert.isTrue(ex.getMessage().containsIgnoreCase('Insert failed'), 'The message does not match');
        }
    }

    @IsTest
    private static void getCopadoStages() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = (copado__Deployment_Flow__c) new Pipeline()
                .name('MyPipeline2')
                .mainBranch('main')
                .platform('SFDX')
                .persist();

            // EXERCISE
            QuickStartCtrl.StageInformation stageInformation = QuickStartCtrl.getCopadoStages(pipeline.Id);

            // VERIFY
            Assert.areEqual(0, stageInformation.copadoStages.size(), 'The count does not match');
            Assert.areEqual(0, stageInformation.stageConnections.size(), 'The count does not match');
        }
    }

    @IsTest
    private static void getCredentialCountTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Environment devEnv = new Environment().name('Dev Env');
            new Credential(devEnv).default(true).orgId(fflib_IDGenerator.generate('00D')).name('Dev Env').persist();

            Id environmentId = [SELECT Id FROM copado__Environment__c LIMIT 1].Id;

            // EXERCISE
            Map<Id, Integer> credentialCount = QuickStartCtrl.getCredentialCountByEnvironmentIds(new List<Id>{ environmentId });

            // VERIFY
            Assert.areEqual(1, credentialCount.size(), 'The count does not match');
            Assert.areEqual(2, credentialCount.get(environmentId), 'The count does not match');
        }
    }

    @IsTest
    private static void govOrgEnable1Test() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            String permissionSetName = PERMISSION_SET_LABEL.replaceAll('[^a-zA-Z0-9]+', '_') + '_PS';
            String permissionSetGroupName = PERMISSION_SET_LABEL.replaceAll('[^a-zA-Z0-9]+', '_');

            // Exercise
            Test.startTest();
            QuickStartCtrl.JWTSettingStatus result = QuickStartCtrl.govOrgEnable1();
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'The result is null');
            Assert.areEqual(
                [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName].Id,
                result.permissionSetId,
                'The Permission Set Id does not match'
            );
            Assert.areEqual(
                [SELECT Id FROM PermissionSetGroup WHERE DeveloperName = :permissionSetGroupName].Id,
                result.permissionSetGroupId,
                'The Permission Set Group Id does not match'
            );
        }
    }

    @IsTest
    private static void govOrgEnable2Test() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            QuickStartCtrl.JWTSettingStatus request = new QuickStartCtrl.JWTSettingStatus();
            request.permissionSetId = [SELECT Id FROM PermissionSet LIMIT 1].Id;

            // Exercise
            Test.startTest();
            QuickStartCtrl.JWTSettingStatus result = QuickStartCtrl.govOrgEnable2(JSON.serialize(request));
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'The result is null');
            Assert.areEqual(request.permissionSetId, result.permissionSetId, 'The Id does not match');
        }
    }

    @IsTest
    private static void govOrgEnable3Test() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            createPersona('Developer', true);
            QuickStartCtrl.JWTSettingStatus request = new QuickStartCtrl.JWTSettingStatus();
            request.permissionSetGroupId = createPermissionSetGroup();

            // Exercise
            Boolean jobIsSuccess = false;
            Test.startTest();
            try {
                QuickStartCtrl.govOrgEnable3(JSON.serialize(request));
                jobIsSuccess = true;
            } catch (Exception e) {
                jobIsSuccess = false;
            }
            Test.stopTest();

            // Verify
            Assert.isTrue(jobIsSuccess, 'Error in adding permission');
        }
    }

    @IsTest
    private static void govOrgEnable4Test() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            createPersona('Developer', true);
            QuickStartCtrl.JWTSettingStatus request = new QuickStartCtrl.JWTSettingStatus();

            // Exercise
            Boolean jobIsSuccess = false;
            Test.startTest();
            try {
                QuickStartCtrl.govOrgEnable4(JSON.serialize(request));
                jobIsSuccess = true;
            } catch (Exception e) {
                jobIsSuccess = false;
            }
            Test.stopTest();

            // Verify
            Assert.isTrue(jobIsSuccess, 'Error in adding permission');
        }
    }

    @IsTest
    private static void govOrgEnable5Test() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            QuickStartCtrl.JWTSettingStatus request = new QuickStartCtrl.JWTSettingStatus();
            request.permissionSetGroupId = createPermissionSetGroup();

            // Exercise
            Test.startTest();
            QuickStartCtrl.JWTSettingStatus result = QuickStartCtrl.govOrgEnable5(JSON.serialize(request));
            Test.stopTest();

            // Verify
            Assert.isNotNull(result, 'The response is null');
        }
    }

    @IsTest
    private static void govOrgEnable6Test() {
        User user = TestUtilities.getRunAsUser(ADMIN_USERNAME);
        System.runAs(user) {
            // Setup
            QuickStartCtrl.JWTSettingStatus request = new QuickStartCtrl.JWTSettingStatus();
            request.userIds = new List<Id>{ user.Id };
            Exception ex;
            Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Complete', '{"ok": "Response created"}', null));

            // Exercise
            Test.startTest();
            try {
                QuickStartCtrl.govOrgEnable6(JSON.serialize(request));
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();

            // Verify
            Assert.isNotNull(ex, 'There is an exception.');
        }
    }

    @IsTest
    private static void removePsFromConnectedAppTest() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            Exception ex;

            // Exercise
            Test.startTest();
            try {
                QuickStartCtrl.removePsFromConnectedApp();
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();

            // Verify
            Assert.isNull(ex, 'There is an exception.');
        }
    }

    @IsTest
    private static void getConnectedAppStatusTest() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            // Setup
            Exception ex;

            // Exercise
            Test.startTest();
            try {
                QuickStartCtrl.getConnectedAppStatus();
            } catch (Exception e) {
                ex = e;
            }
            Test.stopTest();

            // Verify
            Assert.isNull(ex, 'There is an exception.');
        }
    }

    // HELPER

    private static String getContextData() {
        Environment a = new Environment().name('A');
        Environment b = new Environment().name('B');
        Environment c = new Environment().name('C');
        Environment d = new Environment().name('D');

        new Credential(a).default(true).orgId(fflib_IDGenerator.generate('00D')).name('A');
        new Credential(b).default(true).orgId(fflib_IDGenerator.generate('00D')).name('B');
        new Credential(c).default(true).orgId(fflib_IDGenerator.generate('00D')).name('C');
        new Credential(d).default(true).orgId(fflib_IDGenerator.generate('00D')).name('D').persist();

        List<copado__Environment__c> environments = [SELECT Id FROM copado__Environment__c ORDER BY Name ASC];
        List<copado__Org__c> credentials = [SELECT Id FROM copado__Org__c ORDER BY Name ASC];

        copado__Org__c dev1Org = new copado__Org__c(
            Id = credentials[0].Id,
            Name = 'A',
            copado__Org_Type__c = 'Production/Developer',
            copado__Environment__c = environments[0].Id
        );
        copado__Environment__c dev1Env = new copado__Environment__c(
            Id = environments[0].Id,
            Name = 'A',
            copado__Platform__c = 'SFDX',
            copado__Type__c = 'Production/Developer'
        );

        copado__Org__c qaOrg = new copado__Org__c(
            Id = credentials[1].Id,
            Name = 'B',
            copado__Org_Type__c = 'Production/Developer',
            copado__Environment__c = environments[1].Id
        );
        copado__Environment__c qaEnv = new copado__Environment__c(
            Id = environments[1].Id,
            Name = 'B',
            copado__Platform__c = 'SFDX',
            copado__Type__c = 'Production/Developer'
        );

        copado__Org__c uatOrg = new copado__Org__c(
            Id = credentials[2].Id,
            Name = 'C',
            copado__Org_Type__c = 'Production/Developer',
            copado__Environment__c = environments[2].Id
        );
        copado__Environment__c uatEnv = new copado__Environment__c(
            Id = environments[2].Id,
            Name = 'C',
            copado__Platform__c = 'SFDX',
            copado__Type__c = 'Production/Developer'
        );

        copado__Org__c prodOrg = new copado__Org__c(
            Id = credentials[3].Id,
            Name = 'D',
            copado__Org_Type__c = 'Production/Developer',
            copado__Environment__c = environments[3].Id
        );
        copado__Environment__c prodEnv = new copado__Environment__c(
            Id = environments[3].Id,
            Name = 'D',
            copado__Platform__c = 'SFDX',
            copado__Type__c = 'Production/Developer'
        );

        QuickStartCtrl.Environment dev1 = new QuickStartCtrl.Environment(dev1Env, dev1Org);
        QuickStartCtrl.Environment qa = new QuickStartCtrl.Environment(qaEnv, qaOrg);
        QuickStartCtrl.Environment uat = new QuickStartCtrl.Environment(uatEnv, uatOrg);
        QuickStartCtrl.Environment prod = new QuickStartCtrl.Environment(prodEnv, prodOrg);

        List<QuickStartCtrl.Environment> devEnvironments = new List<QuickStartCtrl.Environment>{ dev1 };
        List<QuickStartCtrl.Environment> qaEnvironments = new List<QuickStartCtrl.Environment>{ qa };
        List<QuickStartCtrl.Environment> uatEnvironments = new List<QuickStartCtrl.Environment>{ uat };
        List<QuickStartCtrl.Environment> prodEnvironments = new List<QuickStartCtrl.Environment>{ prod };

        QuickStartCtrl.Stage devStage = new QuickStartCtrl.Stage('Development', devEnvironments);
        QuickStartCtrl.Stage qaStage = new QuickStartCtrl.Stage('QA', qaEnvironments);
        QuickStartCtrl.Stage uatStage = new QuickStartCtrl.Stage('UAT', uatEnvironments);
        QuickStartCtrl.Stage prodStage = new QuickStartCtrl.Stage('Production', prodEnvironments);

        List<QuickStartCtrl.Stage> stages = new List<QuickStartCtrl.Stage>{ devStage, qaStage, uatStage, prodStage };

        return JSON.serialize(stages);
    }

    private static copado__Persona_Definition__c createPersona(String name, Boolean createPsg) {
        Group personaGroup = new Group(Name = name, Type = 'Regular');
        insert personaGroup;

        PersonaDefinitionConfig config = new PersonaDefinitionConfig();
        config.publicGroupId = personaGroup.Id;

        if (createPsg) {
            PermissionSetGroup permissionSetGroup = new PermissionSetGroup(DeveloperName = name, MasterLabel = name);
            insert permissionSetGroup;

            PersonaDefinitionConfig.ConfigEntry configEntry = new PersonaDefinitionConfig.ConfigEntry();
            configEntry.isStandard = true;
            configEntry.name = name;

            config.permissionSetGroups = new List<PersonaDefinitionConfig.ConfigEntry>{ configEntry };

            PersonaDefinitionConfig.ConfigEntry licenseConfigEntry = new PersonaDefinitionConfig.ConfigEntry();
            licenseConfigEntry.isStandard = true;
            licenseConfigEntry.name = 'CCM_Licenses_Enabled';

            config.licenses = new List<PersonaDefinitionConfig.ConfigEntry>{ licenseConfigEntry };

            PersonaDefinitionConfig.ConfigEntry packageLicenseConfigEntry = new PersonaDefinitionConfig.ConfigEntry();
            packageLicenseConfigEntry.isStandard = true;
            packageLicenseConfigEntry.name = 'copado';

            config.licenses = new List<PersonaDefinitionConfig.ConfigEntry>{ packageLicenseConfigEntry };

            PersonaDefinitionConfig.ConfigEntry permissionSetsConfigEntry = new PersonaDefinitionConfig.ConfigEntry();
            permissionSetsConfigEntry.isStandard = true;
            permissionSetsConfigEntry.name = name + '_PS';

            config.permissionSets = new List<PersonaDefinitionConfig.ConfigEntry>{ permissionSetsConfigEntry };
        }

        copado__Persona_Definition__c persona = new copado__Persona_Definition__c(
            Name = name,
            copado__Is_Standard__c = true,
            copado__Config_Json__c = JSON.serialize(config)
        );
        insert persona;
        return persona;
    }

    private static Id createPermissionSetGroup() {
        String permissionSetGroupName = PERMISSION_SET_LABEL.replaceAll('[^a-zA-Z0-9]+', '_') + 'TestClass';
        PermissionSetGroup permissionSetGroup = new PermissionSetGroup(
            DeveloperName = permissionSetGroupName,
            MasterLabel = PERMISSION_SET_LABEL + 'TestClass'
        );

        insert permissionSetGroup;
        return permissionSetGroup.Id;
    }
}