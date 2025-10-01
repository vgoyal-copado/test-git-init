@IsTest
private class AuthenticateEnvironmentCtrlTest {
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        Group personaGroup = new Group(Name = 'TestGroup', Type = 'Regular');
        insert personaGroup;
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void getData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Environment__c environment = getEnvironmentByName('devenv1');

            // EXERCISE
            Test.startTest();
            AuthenticateEnvironmentCtrl.AuthenticateEnvironmentData data = AuthenticateEnvironmentCtrl.getData(environment.Id);
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(data.credentialId, 'Credential Id should be returned');
            Assert.isNotNull(data.accessLevel, 'Access Level should be returned');
        }
    }

    @IsTest
    private static void authenticate() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c environment = getEnvironmentByName('devenv1');
            copado__Persona_Definition__c persona = getPersona();

            // EXERCISE
            Test.startTest();
            String authUrl = AuthenticateEnvironmentCtrl.authenticate(pipeline.Id, environment.Id, new List<Id>{persona.Id}, 'Read');
            Test.stopTest();

            // VERIFY
            Assert.isNotNull(authUrl, 'Authorize Url should be returned');
        }
    }

    @IsTest
    private static void validationUponAuthentication() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c environment1 = getEnvironmentByName('devenv1');
            copado__Org__c credential = getCredential(environment1.Id);

            copado__Environment__c environment2 = getEnvironmentByName('devenv2');

            // EXERCISE
            Test.startTest();
            AuthenticateEnvironmentCtrl.ValidationResult validationResult = AuthenticateEnvironmentCtrl.validationUponAuthentication(
                pipeline.Id,
                environment2.Id,
                credential.Id
            );
            Test.stopTest();

            // VERIFY
            Assert.areEqual(false, validationResult.isValid, 'Validation result should be returned');
        }
    }

    @IsTest
    private static void validationUponExistingCredentialAuthentication() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            AuthenticateEnvironmentCtrl.PipelineBuilderData builderData = new AuthenticateEnvironmentCtrl.PipelineBuilderData();
            builderData.selectedSandboxName = 'Test';
            builderData.selectedSandboxOrgId = 'testordid';
            builderData.selectedSandboxType = 'DEVELOPER';
            pipeline.Builder_Data__c = JSON.serialize(builderData);
            update pipeline;
            
            updateCredentialSFDCOrgId('devenv1', 'testordid');
            copado__Environment__c environment1 = getEnvironmentByName('devenv1');
            copado__Org__c credential = getCredential(environment1.Id);

            copado__Environment__c environment2 = getEnvironmentByName('devenv2');

            // EXERCISE
            Test.startTest();
            AuthenticateEnvironmentCtrl.ValidationResult validationResult = AuthenticateEnvironmentCtrl.validationUponAuthentication(
                pipeline.Id,
                environment2.Id,
                credential.Id
            );
            Test.stopTest();

            // VERIFY
            Assert.areEqual(false, validationResult.isValid, 'Validation result should be returned');
            Assert.areEqual(Label.Credential_Already_Authenticated_Same_Pipeline, validationResult.errorMessage, 'Validation result should have error message.');
        }
    }

    @IsTest
    private static void validationUponIncorrectSandboxAuthentication() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            AuthenticateEnvironmentCtrl.PipelineBuilderData builderData = new AuthenticateEnvironmentCtrl.PipelineBuilderData();
            builderData.selectedSandboxName = 'Test';
            builderData.selectedSandboxOrgId = 'testordid1';
            builderData.selectedSandboxType = 'DEVELOPER';
            pipeline.Builder_Data__c = JSON.serialize(builderData);
            update pipeline;

            updateCredentialSFDCOrgId('devenv1', UserInfo.getOrganizationId() + '_' + UserInfo.getUserId());
            copado__Environment__c environment = getEnvironmentByName('devenv1');
            copado__Org__c credential = getCredential(environment.Id);

            // EXERCISE
            Test.startTest();
            AuthenticateEnvironmentCtrl.ValidationResult validationResult = AuthenticateEnvironmentCtrl.validationUponAuthentication(
                pipeline.Id,
                environment.Id,
                credential.Id
            );
            Test.stopTest();

            // VERIFY
            Assert.areEqual(false, validationResult.isValid, 'Validation result should be returned');
            Assert.areEqual(Label.Incorrect_Sandbox_Authenticated_Error, validationResult.errorMessage, 'Validation result should have error message.');
        }
    }

    @IsTest
    private static void validationUponPlatformMismatchAuthentication() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            AuthenticateEnvironmentCtrl.PipelineBuilderData builderData = new AuthenticateEnvironmentCtrl.PipelineBuilderData();
            builderData.selectedSandboxName = 'Test';
            builderData.selectedSandboxOrgId = 'testordid1';
            builderData.selectedSandboxType = 'DEVELOPER';
            pipeline.Builder_Data__c = JSON.serialize(builderData);
            update pipeline;

            updateCredentialSFDCOrgId('devenv1', UserInfo.getOrganizationId() + '_' + UserInfo.getUserId());
            copado__Environment__c environment = getEnvironmentByName('devenv1');
            
            copado__Environment__c sfEnvironment = getEnvironmentByName('sfdevenv1');
            copado__Org__c sfCredential = getCredential(sfEnvironment.Id);

            // EXERCISE
            Test.startTest();
            AuthenticateEnvironmentCtrl.ValidationResult validationResult = AuthenticateEnvironmentCtrl.validationUponAuthentication(
                pipeline.Id,
                environment.Id,
                sfCredential.Id
            );
            Test.stopTest();

            // VERIFY
            Assert.areEqual(false, validationResult.isValid, 'Validation result should be returned');
            Assert.areEqual(Label.Credential_Exists_With_Another_Platform, validationResult.errorMessage, 'Validation result should have error message.');
        }
    }

    @IsTest
    private static void validationUponExistingEnvironmentAuthentication() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            copado__Environment__c environment = getEnvironmentByName('devenv1');
    
            copado__Environment__c sfdxEnvironment = getEnvironmentByName('sfdxdevenv1');
            copado__Org__c sfdxCredential = getCredential(sfdxEnvironment.Id);

            // EXERCISE
            Test.startTest();
            AuthenticateEnvironmentCtrl.ValidationResult validationResult = AuthenticateEnvironmentCtrl.validationUponAuthentication(
                pipeline.Id,
                environment.Id,
                sfdxCredential.Id
            );
            Test.stopTest();

            // VERIFY
            Assert.areEqual(false, validationResult.isValid, 'Validation result should be returned');
            Assert.areEqual(Label.Credential_Exists_Another_Pipeline, validationResult.errorMessage, 'Validation result should have error message.');
        }
    }


    @IsTest
    private static void getSandboxes() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            copado__Deployment_Flow__c pipeline = getPipeline();
            AuthenticateEnvironmentCtrl.mockResponse = JSON.serialize(
                new ProxyOrgResponse(200, '{"records" : [{ "id" : "sandboxId", "licenseType" : "DEVELOPER", "endDate" : "2024-11-18T07:36:38.000+0000" }] }', null, null)
            );

            // EXERCISE
            Test.startTest();
            List<AuthenticateEnvironmentCtrl.SandboxData> sandboxes = AuthenticateEnvironmentCtrl.getSandboxes(pipeline.Id);
            Test.stopTest();

            // VERIFY
            Assert.areEqual(1, sandboxes.size(), 'One sandbox should be returned');
            Assert.areEqual('2024-11-18T07:36:38Z', sandboxes[0].refreshDate, 'Date should be in ISO 8601 format');
        }
    }

    // HELPER

    private static void createData() {
        Stage devStage = new Stage().name('Dev').metaStage('Build');
        Stage testStage = new Stage().name('Test').metaStage('Test');
        Stage productionStage = new Stage().name('Production').metaStage('Production');

        new Environment().name('sfdevenv1').type('Sandbox').platform('Salesforce').add(new Credential());
        new Environment().name('sfdxdevenv1').type('Sandbox').platform('Other').add(new Credential());

        Environment dev1 = new Environment().name('devenv1').type('Sandbox').platform('Other').add(new Credential());
        Environment dev2 = new Environment().name('devenv2').type('Sandbox').platform('Other').add(new Credential());
        Environment integration = new Environment().name('int').type('Sandbox').platform('Other').add(new Credential());
        Environment uat = new Environment().name('uat').type('Sandbox').platform('Other').add(new Credential());
        Environment prod = new Environment().name('prod').type('Sandbox').platform('Other').add(new Credential());

        StageConnection devStageConnection = new StageConnection().stage(devStage);
        StageConnection testStageConnection = new StageConnection().stage(testStage);
        StageConnection productionStageConnection = new StageConnection().stage(productionStage);

        new Pipeline()
            .active(true)
            .mainBranch('main')
            .platform('Other')
            .add(
                new PipelineConnection()
                    .sourceEnvironment(dev1)
                    .destinationEnvironment(integration)
                    .branch('dev1')
                    .stageConnection(devStageConnection)
            )
            .add(
                new PipelineConnection()
                    .sourceEnvironment(dev2)
                    .destinationEnvironment(integration)
                    .branch('dev2')
                    .stageConnection(devStageConnection)
            )
            .add(
                new PipelineConnection().sourceEnvironment(integration).destinationEnvironment(uat).branch('int').stageConnection(devStageConnection)
            )
            .add(new PipelineConnection().sourceEnvironment(uat).destinationEnvironment(prod).branch('uat').stageConnection(testStageConnection))
            .add(devStageConnection)
            .add(testStageConnection)
            .add(productionStageConnection)
            .persist();

        copado__Stage_Connection__c devStageConnectionRecord = getStageConnections('Dev');
        copado__Stage_Connection__c testStageConnectionRecord = getStageConnections('Test');
        copado__Stage_Connection__c prodStageConnectionRecord = getStageConnections('Production');
        devStageConnectionRecord.copado__Next_Stage_Connection__c = testStageConnectionRecord.Id;
        testStageConnectionRecord.copado__Next_Stage_Connection__c = prodStageConnectionRecord.Id;
        update new List<copado__Stage_Connection__c>{ devStageConnectionRecord, testStageConnectionRecord };

        createPersona();
        assignPermissionSet(UserInfo.getUserId());
    }

    private static copado__Deployment_Flow__c getPipeline() {
        return [SELECT Id, Builder_Data__c FROM copado__Deployment_Flow__c LIMIT 1];
    }

    private static copado__Environment__c getEnvironment() {
        return [SELECT Id FROM copado__Environment__c LIMIT 1];
    }

    private static copado__Org__c getCredential(String environmentId) {
        return [SELECT Id FROM copado__Org__c WHERE copado__Environment__c =: environmentId LIMIT 1];
    }

    private static copado__Environment__c getEnvironmentByName(String name) {
        return [SELECT Id FROM copado__Environment__c WHERE Name =:name LIMIT 1];
    }

    private static copado__Org__c getCredentialByName(String name) {
        return [SELECT Id, copado__SFDC_Org_ID__c FROM copado__Org__c WHERE Name =:name LIMIT 1];
    }

    private static void updateCredentialSFDCOrgId(String name, String sfdcOrgId) {
        copado__Org__c credential = getCredentialByName(name);
        credential.copado__SFDC_Org_ID__c = sfdcOrgId;
        update credential;
    }

    private static copado__Stage_Connection__c getStageConnections(String stageName) {
        return [SELECT Id FROM copado__Stage_Connection__c WHERE copado__Stage__r.Name = :stageName LIMIT 1];
    }

    private static copado__Persona_Definition__c getPersona() {
        return [SELECT Id FROM copado__Persona_Definition__c LIMIT 1];
    }

    private static copado__Persona_Definition__c createPersona() {
        Group personaGroup = [SELECT Id FROM Group WHERE Name =: 'TestGroup' Limit 1];
        copado__Persona_Definition__c personaDefinition = new copado__Persona_Definition__c(
                Name = 'TestPersona',
                copado__Config_JSON__c = '{"publicGroupId":"' + personaGroup.Id + '","permissionSets":[{"name":"TestPSGPS","isStandard":true}],"permissionSetGroups":[{"name":"TestPSG","isStandard":true}],"licenses":[{"name":"TestLicense","isStandard":true}],"defaultCredentialAccessLevel":"TestAccessLevel","credentialIds":[]}'
            );
        insert personaDefinition;
        return personaDefinition;
    }

    public static void assignPermissionSet(Id userId) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        Set<String> permissions = new Set<String>{
            'Persona_Management'
        };

        for (PermissionSet permission : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permissions]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permission.Id));
        }
        insert assignments;
    }
}