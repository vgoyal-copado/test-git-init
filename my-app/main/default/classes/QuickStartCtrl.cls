@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.ExcessivePublicCount, PMD.ExcessiveClassLength')
public with sharing class QuickStartCtrl {

    private static final Map<String, String> ACCEPTANCE_CRITERIA_BY_TEST_TOOL = new Map<String, String> {
        'Apex Tests' => '{"testRunCoverage":{"input":"80","errorDescription":"Your user story code coverage is below the expected threshold of 80%. Please increase code coverage and execute the test run again.","operator":"Equals or Greater than","type":"Percent"},"failing":{"input":"0","errorDescription":"No unit test method can fail. Please update your code to make sure that no method is failing.","operator":"Equals","type":"Integer"}}',
        'PMD' => '{"Best Practices": {"priority": "1 - High", "violationFrequency": "Equals or Less than", "warning": 3, "errorDescription": "The number of high-priority best practices violations exceeds 3. Please review and address these violations to ensure adherence to best practices standards."}, "Security": {"priority": "All", "violationFrequency": "Less than", "warning": 1, "errorDescription": "There is more than 1 security violation. Immediate attention is required to address potential security risks in the code."}, "Design": {"priority": "1 - High", "violationFrequency": "Less than", "warning": 3, "errorDescription": "The number of high-priority design violations exceeds 3. Please correct the design issues to improve the system\'s architecture and maintainability."}, "Documentation": {"priority": "All", "violationFrequency": "Equals or Less than", "warning": 1, "errorDescription": "There is more than 1 documentation violation. Adequate documentation is crucial for maintainability and clarity of the codebase."}, "Code Style": {"priority": "All", "violationFrequency": "Equals or Less than", "warning": 1, "errorDescription": "There is more than 1 code style violation. Consistent code styling is essential for readability and quality of the code."}}'
    };
    private static final Map<String, String> SANDBOX_TYPE_BY_LICENSE = new Map<String, String> {
        'DEVELOPER' => Label.Developer_Sandbox,
        'DEVELOPER_PRO' => Label.Developer_Pro_Sandbox,
        'PARTIAL' => Label.Partial_Copy_Sandbox,
        'FULL' => Label.Full_Sandbox
    };
    private static final String PMD_GENERATE_RULESET_TEMPLATE = 'PMDGenerateRulesetTemplate';
    private static final Map<String, String> STAGE_BY_CATEGORY = new Map<String, String> {
        'Development' => 'Development',
        'Integration' => 'Development',
        'QA' => 'Testing',
        'UAT' => 'Testing',
        'Staging' => 'Production'
    };
    private static final List<String> DISCARD_USERS = new List<String>{ 'Integration User', 'Security User' };
    private static final String PERMISSION_SET_LABEL = 'Copado Governance Org Credential Access PS';

    @TestVisible
    private static String mockResponse;

    @AuraEnabled
    public static copado__Deployment_Flow__c getInProgressPipeline() {
        copado__Deployment_Flow__c result;

        try {
            for (copado__Deployment_Flow__c pipeline : new PipelinesSelector().all()) {
                if (isQuickStartInProgress(pipeline)) {
                    result = pipeline;
                    break;
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static List<ValidationStep> validateQuickStart() {
        try {
            return new QuickStartValidation().execute();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<SandboxData> getSandboxes(Id productionCredentialId) {
        List<SandboxData> result = new List<SandboxData>();

        copado.GlobalAPI.ProxyOrgRequest request = new copado.GlobalAPI.ProxyOrgRequest();
        request.endPointUrlService = getSandboxesEndpoint();
        request.orgCredentialId = productionCredentialId;
        request.logLabelIdentifier = 'Get Sandboxes - ToolingAPI';
        request.requestType = HttpMethod.GET.name();
        copado.GlobalAPI.ProxyOrgResponse response = !Test.isRunningTest()
            ? new copado.GlobalAPI().proxyOrgRequest(request)
            : TestUtilities.getMockedResponse(mockResponse);
        if (response.statusCode != 200) {
            String message = String.isNotBlank(response.errorMessage) ? response.errorMessage : 'Error getting sandboxes';
            throw new ApplicationException(message);
        }
        SandboxToolingApiResult toolingApiResult = (SandboxToolingApiResult) JSON.deserialize(response.content, SandboxToolingApiResult.class);
        for (SandboxRecord sandboxRecord : toolingApiResult.records) {
            SandboxData sandbox = new SandboxData();
            sandbox.id = sandboxRecord.sandboxOrganization;
            sandbox.name = sandboxRecord.sandboxName;
            sandbox.type = SANDBOX_TYPE_BY_LICENSE.containsKey(sandboxRecord.licenseType) ? SANDBOX_TYPE_BY_LICENSE.get(sandboxRecord.licenseType) : '';
            sandbox.description = sandboxRecord.description;
            sandbox.refreshDate = sandboxRecord.endDate != null ? DateTime.valueOfGmt(sandboxRecord.endDate.replace('T', ' ')).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') : '';
            sandbox.clonedFrom = sandboxRecord.source != null ? sandboxRecord.source.sandboxName : Label.Production;
            result.add(sandbox);
        }

        return result;
    }

    @AuraEnabled
    public static copado__Deployment_Flow__c createPipeline(Id repositoryId, String name, String initializationData) {
		try {
            copado__Deployment_Flow__c pipeline = new copado__Deployment_Flow__c();
            pipeline.Name = name;
            pipeline.copado__Platform__c = 'SFDX';
            pipeline.copado__Git_Repository__c = repositoryId;
            pipeline.Initialization_Data__c = initializationData;
            pipeline.copado__Main_Branch__c = 'main';
            insert as User pipeline;

            return pipeline;
        } catch (Exception e) {
            throw new ApplicationException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<copado__Org__c> getOrgs(List<Id> orgIds) {
        return [SELECT Id, copado__Validated_Status__c, copado__SFDC_Org_ID__c, copado__Username__c, copado__Environment__c, copado__Environment__r.copado__Platform__c, copado__Environment__r.Name, copado__Environment__r.copado__Type__c FROM copado__Org__c WHERE Id IN :orgIds WITH USER_MODE];
    }

    @AuraEnabled
    public static Map<Id, Integer> getCredentialCountByEnvironmentIds(List<Id> environmentIds) {
        Map<Id, Integer> result = new Map<Id, Integer>();

        List<AggregateResult> credentialCounts = [
            SELECT copado__Environment__c, COUNT(Id) credentialCount
            FROM copado__Org__c
            WHERE copado__Environment__c IN :environmentIds
            WITH USER_MODE
            GROUP BY copado__Environment__c
        ];

        for (AggregateResult cred : credentialCounts) {
            result.put((Id)cred.get('copado__Environment__c'), (Integer)cred.get('credentialCount'));
        }

        return result;
    }

    @AuraEnabled
    public static Map<String, Environment> createEnvironmentAndOrgs(List<EnvironmentRequest> requests) {
        try {
            List<copado__Environment__c> environments = new List<copado__Environment__c>();

            for(EnvironmentRequest request : requests) {
                environments.add(new copado__Environment__c(
                    Name = request.name,
                    copado__Platform__c = 'SFDX',
                    copado__Type__c = request.type
                ));
            }

            insert as User environments;

            return asEnvironmentWrapper(environments);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getCredentialOAuthEndpoint(Id credentialId, String startUrl) {
        try {
            copado.CopadoCredential.EndPointRequest request = new copado.CopadoCredential.EndPointRequest(startUrl, credentialId);

            return copado.CopadoCredential.getLoginUrl(request);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createPipelineConnection(Id pipelineId) {
        try {
            Integer connectionCount = [SELECT count() FROM copado__Deployment_Flow_Step__c WHERE copado__Deployment_Flow__c = :pipelineId WITH USER_MODE];
            if (connectionCount > 0) {
                return;
            }

            Map<String, Id> stageConnectionByDisplayName = new Map<String,Id>();
            for (copado__Stage_Connection__c stageConnection : [SELECT Id, copado__Stage__r.copado__Display_Name__c FROM copado__Stage_Connection__c WHERE copado__Pipeline__c = :pipelineId WITH USER_MODE]) {
                stageConnectionByDisplayName.put(stageConnection.copado__Stage__r.copado__Display_Name__c, stageConnection.Id);
            }

            copado__Deployment_Flow__c pipeline = [SELECT Id, Initialization_Data__c FROM copado__Deployment_Flow__c WHERE Id = :pipelineId WITH USER_MODE];
            PipelineInitializationDetails initializationData = (PipelineInitializationDetails) JSON.deserialize(pipeline.Initialization_Data__c, PipelineInitializationDetails.class);

            List<Stage> stages = (List<Stage>) JSON.deserialize(initializationData.quickStart.quickStartSteps[1].contextData, List<Stage>.class);

            List<copado__Deployment_Flow_Step__c> connections = new List<copado__Deployment_Flow_Step__c>();

            for(Integer i = 0; i < stages.size() - 1; i++) {
                Stage sourceStage = stages[i];
                Stage destinationStage = stages[i+1];
                Boolean isLastStage = (i == stages.size() - 2);

                for(Integer j = 0; j < sourceStage.environments.size(); j++) {
                    connections.add(new copado__Deployment_Flow_Step__c(
                        copado__Deployment_Flow__c = pipeline.Id,
                        copado__Branch__c = sourceStage.environments[j].environment.Name?.toLowerCase().replace(' ', '-'),
                        copado__Source_Environment__c = sourceStage.environments[j].environment.Id,
                        copado__Destination_Branch__c = isLastStage ? 'main' : destinationStage.environments[0].environment.Name?.toLowerCase().replace(' ', '-'),
                        copado__Destination_Environment__c = destinationStage.environments[0].environment.Id,
                        copado__Stage_Connection__c = stageConnectionByDisplayName.get(STAGE_BY_CATEGORY.get(sourceStage.label))
                    ));
                }
            }

            insert as User connections;
        } catch (Exception e) {
            throw new ApplicationException(e.getMessage());
        }
    }

    @AuraEnabled
    public static QualityChecksState getQualityChecksState() {
        try {
            Boolean isPmdEnabled = isQualityExtensionInstalled() && areQualityPermissionsAssigned() && isPmdExtensionConfigured();
            return new QualityChecksState(isApexExtensionConfigured(), isPmdEnabled);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createQualityGates(Id pipelineId, List<String> qualityTools) {
        try {
            Set<String> testTools = new Set<String> (qualityTools);

            List<copado__Quality_Gate_Rule__c> qualityGateRules = createQualityGateRules(testTools);
            createQualityGateRuleConditions(qualityGateRules, testTools, pipelineId);

            // NOTE : This update is required because QGRCs cannot be added to active QGRs
            for (copado__Quality_Gate_Rule__c qualityGateRule : qualityGateRules) {
                qualityGateRule.copado__Status__c = 'Active';
            }

            update as User qualityGateRules;
        } catch (Exception e) {
            throw new ApplicationException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void shareCredentialsWithPersona(List<String> allCredentialIds, List<String> developerCredentialIds) {
        try {
            Map<String, Id> personaIdByApiName = new Map<String, Id>();

            Map<String, Id> personaIdByRecordName = new Map<String, Id>();
            for (copado__Persona_Definition__c persona : [SELECT Id, Name FROM copado__Persona_Definition__c WHERE copado__Is_Standard__c = true WITH SYSTEM_MODE]) {
                personaIdByRecordName.put(persona.Name, persona.Id);
            }

            for (copado__Default_Persona__mdt metadata : copado__Default_Persona__mdt.getAll().values()) {
                if (personaIdByRecordName.containsKey(metadata.MasterLabel)) {
                    personaIdByApiName.put(metadata.DeveloperName, personaIdByRecordName.get(metadata.MasterLabel));
                }
            }

            copado.Persona.ShareCredentialRequest releaseManagerRequest = new copado.Persona.ShareCredentialRequest();
            releaseManagerRequest.credentialIds = allCredentialIds;
            releaseManagerRequest.personaId = personaIdByApiName.get('Release_Manager');
            releaseManagerRequest.accessLevel = 'Edit';
            copado.Persona.CredentialService.share(releaseManagerRequest);

            copado.Persona.ShareCredentialRequest developerRequest = new copado.Persona.ShareCredentialRequest();
            developerRequest.credentialIds = developerCredentialIds;
            developerRequest.personaId = personaIdByApiName.get('Developer');
            developerRequest.accessLevel = 'Edit';
            copado.Persona.CredentialService.share(developerRequest);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean checkPermissionsForAddUsers() {
        try {
            List<UserPermissionAccess> permissionAccesses = [
                SELECT
                    PermissionsManageProfilesPermissionsets,
                    PermissionsManageUsers,
                    PermissionsAssignPermissionSets,
                    PermissionsResetPasswords,
                    PermissionsViewSetup
                FROM UserPermissionAccess
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return !permissionAccesses.isEmpty() &&
                permissionAccesses[0].PermissionsManageProfilesPermissionsets &&
                permissionAccesses[0].PermissionsManageUsers &&
                permissionAccesses[0].PermissionsAssignPermissionSets &&
                permissionAccesses[0].PermissionsResetPasswords &&
                permissionAccesses[0].PermissionsViewSetup;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PersonaData> getUserCountByPersona() {
        try {
            List<PersonaData> result = new List<PersonaData>();

            Map<Id, copado__Persona_Definition__c> personaById = new Map<Id, copado__Persona_Definition__c>(
                [SELECT Id, Name FROM copado__Persona_Definition__c WHERE copado__Is_Standard__c = true WITH SYSTEM_MODE]
            );

            Map<Id, Integer> personaCountById = new Map<Id, Integer>();
            for (AggregateResult userAggregate : [
                SELECT
                    copado__Persona_Id__c,
                    COUNT(Id) userCount
                FROM User
                WHERE
                    copado__Persona_Id__c IN :personaById.keySet()
                WITH SYSTEM_MODE
                GROUP BY copado__Persona_Id__c
            ]) {
                personaCountById.put((Id) userAggregate.get('copado__Persona_Id__c'), (Integer) userAggregate.get('userCount'));
            }

            for (Id personaId : personaById.keySet()) {
                Integer count = personaCountById.get(personaId) != null ? personaCountById.get(personaId) : 0;
                result.add(new PersonaData(personaId, personaById.get(personaId).Name, count));
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<PersonaUser> getUsers() {
        try {
            List<PersonaUser> result = new List<PersonaUser>();

            Map<Id, copado__Persona_Definition__c> personaDefinitionById = new Map<Id, copado__Persona_Definition__c>(
                [SELECT Name FROM copado__Persona_Definition__c WITH SYSTEM_MODE]
            );
            for (User user : [
                SELECT Name, Email, IsActive, copado__Persona_Id__c, Username
                FROM User
                WHERE UserType = 'Standard' AND Name NOT IN :DISCARD_USERS AND IsActive = TRUE
                WITH SYSTEM_MODE LIMIT 2000
            ]) {
                PersonaUser personaUser = new PersonaUser();
                personaUser.user = user;
                personaUser.persona = personaDefinitionById.get(user.copado__Persona_Id__c);
                result.add(personaUser);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<PersonaUser> getUsersWithSearchTerm(String searchTerm) {
        List<PersonaUser> result = new List<PersonaUser>();
        Map<Id, copado__Persona_Definition__c> personaDefinitionById = new Map<Id, copado__Persona_Definition__c>(
            [SELECT Name FROM copado__Persona_Definition__c WITH USER_MODE]
        );

        List<List<User>> users = [FIND :searchTerm IN ALL FIELDS RETURNING User(Id, Name, Email, IsActive, copado__Persona_Id__c, Username, UserType)];
        for (List<User> lUsers : users) {
            for (User user : lUsers) {
                if (user.UserType == 'Standard' && user.IsActive == true && !DISCARD_USERS.contains(user.Name)) {
                    PersonaUser personaUser = new PersonaUser();
                    personaUser.user = user;
                    personaUser.persona = personaDefinitionById.get(user.copado__Persona_Id__c);
                    result.add(personaUser);
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static Boolean isRecalculatingPermissions() {
        try {
            return Test.isRunningTest() ? false : [SELECT COUNT() FROM PermissionSetGroup WHERE Status != 'Updated'] > 0;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void addUser1(String personaId, List<String> userIds) {
        copado.Persona.AddUserRequest request = new copado.Persona.AddUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().add1(request);
    }

    @AuraEnabled
    public static void addUser2(String personaId, List<String> userIds) {
        copado.Persona.AddUserRequest request = new copado.Persona.AddUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().add2(request);
    }

    @AuraEnabled
    public static void addUser3(String personaId, List<String> userIds) {
        copado.Persona.AddUserRequest request = new copado.Persona.AddUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().add3(request);
    }

    @AuraEnabled
    public static void addUser4(String personaId, List<String> userIds) {
        copado.Persona.AddUserRequest request = new copado.Persona.AddUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().add4(request);
    }

    @AuraEnabled
    public static void addUser5(String personaId, List<String> userIds) {
        try {
            copado.Persona.AddUserRequest request = new copado.Persona.AddUserRequest();
            request.personaId = personaId;
            request.userIds = userIds;
            new copado.Persona.UserService().add5(request);
        } catch (Exception ex) {
            throw new ApplicationException(Label.Org_Is_Not_Valid);
        }
    }

    @AuraEnabled
    public static void addUser6(String personaId, List<String> userIds) {
        copado.Persona.AddUserRequest request = new copado.Persona.AddUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().add6(request);
    }

    @AuraEnabled
    public static void removeUser1(String personaId, List<String> userIds) {
        copado.Persona.RemoveUserRequest request = new copado.Persona.RemoveUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().remove1(request);
    }

    @AuraEnabled
    public static void removeUser2(String personaId, List<String> userIds) {
        copado.Persona.RemoveUserRequest request = new copado.Persona.RemoveUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().remove2(request);
    }

    @AuraEnabled
    public static void removeUser3(String personaId, List<String> userIds) {
        copado.Persona.RemoveUserRequest request = new copado.Persona.RemoveUserRequest();
        request.personaId = personaId;
        request.userIds = userIds;
        new copado.Persona.UserService().remove3(request);
    }

    @AuraEnabled
    public static StageInformation getCopadoStages(Id pipelineId) {
        try {
            StageInformation stageInformation = new StageInformation();

            Set<String> stageNames = new Set<String>{ 'Development', 'Testing', 'Production' };
            stageInformation.copadoStages = [SELECT Id, Name, copado__Display_Name__c, copado__Meta_Stage__c FROM copado__Stage__c WHERE copado__Display_Name__c IN :stageNames WITH USER_MODE];
            stageInformation.stageConnections = [SELECT Id FROM copado__Stage_Connection__c WHERE copado__Pipeline__c = :pipelineId WITH USER_MODE];

            return stageInformation;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static ConnectedAppStatus getConnectedAppStatus(){
        try {
            ConnectedAppStatus result = new ConnectedAppStatus();

            result.isFeatureUsable = copado.Feature.isAutomateGovOrgEnabled();

            if (result.isFeatureUsable) {
                List<ConnectedApplication> connectedApps = [SELECT Id, Name, OptionsAllowAdminApprovedUsersOnly FROM ConnectedApplication WHERE Name LIKE 'Copado DevOps%' WITH USER_MODE];
                if (connectedApps.isEmpty()) {
                    return result;
                }

                result.isInstalled = true;
                result.hasPolicies = hasPolicies(connectedApps);

                String permissionSetName = PERMISSION_SET_LABEL.replaceAll('[^a-zA-Z0-9]+', '_');
                List<Id> connectedAppIds = new List<Id>();
                for (ConnectedApplication connectedApp : connectedApps) {
                    connectedAppIds.add(connectedApp.Id);
                }

                List<SetupEntityAccess> setupEntitiesAccess = [
                    SELECT Id, ParentId, SetupEntityId
                    FROM SetupEntityAccess
                    WHERE
                        ParentId IN (SELECT Id FROM PermissionSet WHERE Name = :permissionSetName)
                        AND SetupEntityId IN :connectedAppIds
                    WITH USER_MODE
                ];
                result.hasPermissionSets = !setupEntitiesAccess.isEmpty();
            }

            return result;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void removePsFromConnectedApp() {
        try {
            String permissionSetName = PERMISSION_SET_LABEL.replaceAll('[^a-zA-Z0-9]+', '_');

            List<SetupEntityAccess> setupEntitiesAccess = [
                SELECT Id, ParentId, SetupEntityId
                FROM SetupEntityAccess
                WHERE
                    ParentId IN (SELECT Id FROM PermissionSet WHERE Name = :permissionSetName)
                    AND SetupEntityId IN (SELECT Id FROM ConnectedApplication WHERE Name LIKE 'Copado DevOps%')
                WITH USER_MODE
            ];

            if (setupEntitiesAccess.isEmpty()) {
                return;
            }
            delete as System setupEntitiesAccess;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static JWTSettingStatus govOrgEnable1() {
        copado.Feature.JWTSettingStatusResult response = copado.Feature.JWTSetting.createPermissions();
        return new JWTSettingStatus(response);
    }

    @AuraEnabled
    public static JWTSettingStatus govOrgEnable2(String sRequest) {
        JWTSettingStatus request = (JWTSettingStatus) JSON.deserialize(sRequest, JWTSettingStatus.class);
        copado.Feature.JWTSettingStatusResult response = copado.Feature.JWTSetting.assignPermissionToConnectedApp(convertRequest(request));
        return new JWTSettingStatus(response);
    }

    @AuraEnabled
    public static JWTSettingStatus govOrgEnable3(String sRequest) {
        JWTSettingStatus request = (JWTSettingStatus) JSON.deserialize(sRequest, JWTSettingStatus.class);
        copado.Feature.JWTSettingStatusResult response = copado.Feature.JWTSetting.assignPermissionToPersonas1(convertRequest(request));
        return new JWTSettingStatus(response);
    }

    @AuraEnabled
    public static JWTSettingStatus govOrgEnable4(String sRequest) {
        JWTSettingStatus request = (JWTSettingStatus) JSON.deserialize(sRequest, JWTSettingStatus.class);
        copado.Feature.JWTSettingStatusResult response = copado.Feature.JWTSetting.assignPermissionToPersonas2(convertRequest(request));
        return new JWTSettingStatus(response);
    }

    @AuraEnabled
    public static JWTSettingStatus govOrgEnable5(String sRequest) {
        JWTSettingStatus request = (JWTSettingStatus) JSON.deserialize(sRequest, JWTSettingStatus.class);
        copado.Feature.JWTSettingStatusResult response = copado.Feature.JWTSetting.assignPermissionToExistingUsers(convertRequest(request));
        return new JWTSettingStatus(response);
    }

    @AuraEnabled
    public static JWTSettingStatus govOrgEnable6(String sRequest) {
        JWTSettingStatus request = (JWTSettingStatus) JSON.deserialize(sRequest, JWTSettingStatus.class);
        copado.Feature.JWTSettingStatusResult response = copado.Feature.JWTSetting.execute(convertRequest(request));
        return new JWTSettingStatus(response);
    }

    // PRIVATE

    private static Map<String, Environment> asEnvironmentWrapper(List<copado__Environment__c> environments) {
        List<Environment> result = new List<Environment>();

        Map<Id, copado__Org__c> orgByEnvironmentId = orgByEnvironmentId(environments);
        for(copado__Environment__c environment : environments) {
            result.add(new Environment(environment, orgByEnvironmentId.get(environment.Id)));
        }

        return asMap(result);
    }

    private static Map<String, Environment> asMap(List<Environment> environments) {
        Map<String, Environment> result = new Map<String, Environment>();

        for(Environment environment : environments) {
            result.put(environment.environment.Name, environment);
        }

        return result;
    }

    private static Map<Id, copado__Org__c> orgByEnvironmentId(List<copado__Environment__c> environments) {
        Map<Id, copado__Org__c> result = new Map<Id, copado__Org__c>();

        for(copado__Org__c org: [SELECT Id, Name, copado__Org_Type__c, copado__Environment__c FROM copado__Org__c WHERE copado__Environment__c IN : environments WITH USER_MODE]) {
            result.put(org.copado__Environment__c, org);
        }

        return result;
    }

    private static Boolean isQuickStartInProgress(copado__Deployment_Flow__c pipeline) {
        if (String.isBlank(pipeline?.Initialization_Data__c)) {
            return false;
        } else {
            PipelineInitializationDetails initializationData = (PipelineInitializationDetails) JSON.deserialize(pipeline.Initialization_Data__c, PipelineInitializationDetails.class);
            if (initializationData?.quickStart == null) {
                return false;
            }
            for (PipelineInitializationDetails.QuickStartStep step : initializationData?.quickStart?.quickStartSteps) {
                if (step.isActive) {
                    return true;
                }
            }
            return false;
        }
    }

    private static List<copado__Quality_Gate_Rule__c> createQualityGateRules(Set<String> testTools) {
        List<copado__Quality_Gate_Rule__c> result = new List<copado__Quality_Gate_Rule__c>();

        for (String testTool : testTools) {
            result.add(new copado__Quality_Gate_Rule__c(
                copado__Tool__c = testTool,
                copado__Actions__c = 'Commit',
                copado__Execution_sequence__c = 'After',
                Name = testTool + ' - ' + Label.After + ' ' + Label.Commit
            ));
        }

        insert as User result;

        return result;
    }

    private static Map<String, copado__ExtensionConfiguration__c> getExtensionsByTestTool(Set<String> testTools) {
        Map<String, copado__ExtensionConfiguration__c> result = new Map<String, copado__ExtensionConfiguration__c>();

        Set<String> namePatterns = new Set<String>();
        for (String testTool : testTools) {
            namePatterns.add(Label.QuickStart + ' - ' + testTool);
        }
        for (copado__ExtensionConfiguration__c extensionConfiguration : [
            SELECT Id, copado__ExtensionTool__c
            FROM copado__ExtensionConfiguration__c
            WHERE copado__ExtensionTool__c IN :testTools
                AND Name IN :namePatterns
                AND copado__Active__c = true
            WITH USER_MODE
        ]) {
            result.put(extensionConfiguration.copado__ExtensionTool__c, extensionConfiguration);
        }

        Set<String> missingTools = new Set<String>(testTools);
        missingTools.removeAll(result.keySet());

        List<copado__ExtensionConfiguration__c> extensionConfigurations = new List<copado__ExtensionConfiguration__c>();
        for (String testTool : missingTools) {
            copado__ExtensionConfiguration__c configuration = new copado__ExtensionConfiguration__c(
                Name = 'Quick Start - '+ testTool,
                copado__Active__c = true,
                copado__ExtensionTool__c = testTool,
                copado__ExtensionApplication__c = 'Test',
                copado__AcceptanceCriteria__c = ACCEPTANCE_CRITERIA_BY_TEST_TOOL.get(testTool)
            );

            extensionConfigurations.add(configuration);
            result.put(testTool, configuration);
        }

        insert as User extensionConfigurations;

        if (missingTools.contains('PMD')) {
            executeJob(result.get('PMD').Id);
        }

        return result;
    }

    private static List<copado__Quality_Gate_Rule_Condition__c> createQualityGateRuleConditions(List<copado__Quality_Gate_Rule__c> qualityGateRules, Set<String> testTools, Id pipelineId) {
        List<copado__Quality_Gate_Rule_Condition__c> result = new List<copado__Quality_Gate_Rule_Condition__c>();

        Map<String, copado__ExtensionConfiguration__c> extensionsByTestTool = getExtensionsByTestTool(testTools);

        for (copado__Quality_Gate_Rule__c qualityGateRule : qualityGateRules) {
            if (extensionsByTestTool.containsKey(qualityGateRule.copado__Tool__c)) {
                result.add(new copado__Quality_Gate_Rule_Condition__c(
                    copado__Extension_Configuration__c = extensionsByTestTool.get(qualityGateRule.copado__Tool__c).Id,
                    copado__Quality_Gate_Rule__c = qualityGateRule.Id,
                    copado__Pipeline__c = pipelineId,
                    copado__Platform__c = 'SFDX',
                    copado__Tests_From__c = 'User Story',
                    copado__Filter_Criteria__c = '{$Changes.Type.contains("Apex")} || {$Changes.Type.contains("Trigger")}'
                ));
            }
        }

        insert as User result;
        return result;
    }

    private static void executeJob(Id parentId) {
        copado.Jobs.ExecutionCreateFromTemplateRequest jobRequest = new copado.Jobs.ExecutionCreateFromTemplateRequest();
        jobRequest.parentId = parentId;
        jobRequest.templateAPIName = getJobTemplateFor(PMD_GENERATE_RULESET_TEMPLATE);
        jobRequest.dataJson = JSON.serialize(new Map<String, Object>{ 'ruleLanguage' => 'apex' });

        Id jobId = copado.Jobs.Execution.createFromTemplate(jobRequest).jobExecution.Id;
        copado.Jobs.Execution.execute(new copado.Jobs.ExecutionRequest(jobId));
    }

    private static String getJobTemplateFor(String key) {
        List<copado__ExtensionKeyValueSetting__mdt> templateApiNames = new ExtensionKeyValueSettingsSelector().byKey(key);
        return !templateApiNames.isEmpty() ? templateApiNames[0].copado__Value__c : '';
    }

    private static Boolean isApexExtensionConfigured() {
        try {
            String testTool = copado__TestTool__mdt.getInstance('ApexTests')?.MasterLabel;

            return Utilities.getPicklistValues('copado__ExtensionConfiguration__c', 'copado__ExtensionTool__c').contains(testTool)
                && Utilities.getPicklistValues('copado__Quality_Gate_Rule__c', 'copado__Tool__c').contains(testTool);
        } catch (Exception ex) {
            return false;
        }
    }

    private static Boolean isQualityExtensionInstalled() {
        try {
            return Schema.getGlobalDescribe().containsKey('copadoQuality__Compliance_Rule__c');
        } catch (Exception ex) {
            return true;
        }
    }

    private static Boolean areQualityPermissionsAssigned() {
        try {
            Set<String> permissionSetNames = new Set<String>{
                'Configure_AQF',
                'PMD_Admin'
            };

            return Utilities.areAllPermissionSetsAssigned(permissionSetNames, UserInfo.getUserId());
        } catch (Exception ex) {
            return false;
        }
    }

    private static Boolean isPmdExtensionConfigured() {
        try {
            copado__TestTool__mdt testTool = copado__TestTool__mdt.getInstance('PMD');

            Set<String> templateNames = new Set<String>{ testTool.copado__JobTemplate__c, getJobTemplateFor(PMD_GENERATE_RULESET_TEMPLATE)};
            Integer templateCount = [SELECT COUNT() FROM copado__JobTemplate__c WHERE copado__ApiName__c IN :templateNames WITH USER_MODE];

            return templateCount == 2
                && Utilities.getPicklistValues('copado__ExtensionConfiguration__c', 'copado__ExtensionTool__c').contains(testTool?.MasterLabel)
                && Utilities.getPicklistValues('copado__Quality_Gate_Rule__c', 'copado__Tool__c').contains(testTool?.MasterLabel);
        } catch (Exception ex) {
            return false;
        }
    }

    private static String getSandboxesEndpoint() {
        String toolingApiPath = Settings.TOOLING_API_ENDPOINT;
        String queryPath = '/query/?q=';
        String query = 'SELECT+Id,ActivatedDate,Description,EndDate,LicenseType,SandboxInfoId,SandboxName,SandboxOrganization,CreatedDate,Source.SandboxName+FROM+SandboxProcess+WHERE+Status=\'1\'';
        return toolingApiPath + queryPath + query;
    }

    private static copado.Feature.JWTSettingStatusRequest convertRequest(JWTSettingStatus request) {
        copado.Feature.JWTSettingStatusRequest copadoRequest = new copado.Feature.JWTSettingStatusRequest();

        copadoRequest.permissionSetGroupId = request.permissionSetGroupId;
        copadoRequest.permissionSetId = request.permissionSetId;
        copadoRequest.userIds = request.userIds;

        return copadoRequest;
    }

    private static Boolean hasPolicies(List<ConnectedApplication> connectedApps) {
        if (connectedApps == null || connectedApps.isEmpty()) {
            return false;
        }

        for (ConnectedApplication connectedApp : connectedApps) {
            if (connectedApp.OptionsAllowAdminApprovedUsersOnly) {
                return true;
            }
        }

        return false;
    }

    // INNER

    public with sharing class Stage {
        @AuraEnabled
        public String label {get; set;}

        @AuraEnabled
        public List<Environment> environments {get; set;}

        public Stage(String label, List<Environment> environments) {
            this.label = label;
            this.environments = environments;
        }
    }

    public with sharing class EnvironmentRequest {
        @AuraEnabled
        public String name {get; set;}
        @AuraEnabled
        public String type {get; set;}
    }

    public with sharing class Environment {
        @AuraEnabled
        public copado__Environment__c environment {get; set;}


        @AuraEnabled
        public copado__Org__c defaultOrg {get; set;}

        public Environment(copado__Environment__c environment, copado__Org__c defaultOrg) {
            this.environment = environment;
            this.defaultOrg = defaultOrg;
        }
    }

    public with sharing class QuickStartValidation {

        public List<ValidationStep> execute() {
            List<ValidationStep> result = new List<ValidationStep>();

            result.add(new ValidationStep('License assigned', isCopadoLicenseAssigned(), true));
            result.add(new ValidationStep('Credential authenticated', isCredentialAuthenticated(), true));
            result.add(new ValidationStep('API Key created', isApiKeyCreated(), true));
            result.add(new ValidationStep('Run Flows permission', isFlowPermissionAssigned(), true));
            result.add(new ValidationStep('Permission Sets assigned', arePermissionSetsAssigned(), true));
            result.add(new ValidationStep('Standard Persona created', arePersonaDefinitionsCreated(), true));
            result.add(new ValidationStep('Apex Extension Configured', QuickStartCtrl.isApexExtensionConfigured(), false));
            result.add(new ValidationStep('Quality Extension Installed', QuickStartCtrl.isQualityExtensionInstalled(), false));
            result.add(new ValidationStep('Quality Permission Sets assigned', QuickStartCtrl.areQualityPermissionsAssigned(), false));
            result.add(new ValidationStep('PMD Quality Tool configured', QuickStartCtrl.isPmdExtensionConfigured(), false));

            return result;
        }


        private Boolean isCopadoLicenseAssigned() {
            Id loggedInUserId = UserInfo.getUserId();

            try {
                for(copado.GlobalAPI.UserLicense userLicense : new copado.GlobalAPI().listCopadoLicenses()) {
                    if(userLicense.userId == loggedInUserId) {
                        return userLicense.isCopadoEnabled;
                    }
                }
                return false;
            } catch(Exception ex) {
                return false;
            }
        }


        private Boolean isCredentialAuthenticated() {
            try {
                List<copado__Org__c> credentials = new CredentialsSelector().bySfdcOrgIdAndValidationCheck(new Set<String> { UserInfo.getOrganizationId() + '_' + UserInfo.getUserId() });
                return !credentials.isEmpty();
            } catch (Exception ex) {
                return false;
            }
        }


        private Boolean isApiKeyCreated() {
            try {
                String result;
                if (SObjectType.copado__Personal_Settings__c.fields.copado__API_Key__c.isAccessible()) {
                    result = copado__Personal_Settings__c.getInstance().copado__API_Key__c;
                }
                return String.isNotBlank(result);
            } catch (Exception ex) {
                return false;
            }
        }


        private Boolean isFlowPermissionAssigned() {
            try {
                Id userId = UserInfo.getUserId();
                User userRecord = [
                        SELECT Profile.PermissionsRunFlow, UserPermissionsInteractionUser
                        FROM User
                        WHERE Id = :userId
                        WITH SYSTEM_MODE
                        LIMIT 1
                    ];

                if (userRecord.UserPermissionsInteractionUser || userRecord.Profile.PermissionsRunFlow) {
                    return true;
                } else {
                    Set<Id> permissionSetIds = new Set<Id>();
                    for (PermissionSetAssignment assignment : [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :userId WITH SYSTEM_MODE]) {
                        permissionSetIds.add(assignment.PermissionSetId);
                    }

                    List<PermissionSet> permissionSets = [
                        SELECT PermissionsRunFlow
                        FROM PermissionSet
                        WHERE Id IN :permissionSetIds WITH SYSTEM_MODE
                    ];

                    for (PermissionSet ps : permissionSets) {
                        if (ps.PermissionsRunFlow) {
                            return true;
                        }
                    }

                    return false;
                }
            } catch (Exception ex) {
                return false;
            }
        }


        private Boolean arePermissionSetsAssigned() {
            try {
                Set<String> permissionSetNames = new Set<String>{
                    'CMC_SFDX_Admin',
                    'Copado_Job_Engine',
                    'Copado_User',
                    'Configure_Snapshot',
                    'Persona_Management' // Required for credential share service
                };

                Set<String> withFunctionsUser = new Set<String>(permissionSetNames);
                withFunctionsUser.add('Copado_Functions_User');

                if (Utilities.areAllPermissionSetsAssigned(withFunctionsUser, UserInfo.getUserId())) {
                    return true;
                }

                Set<String> withFunctionsAdmin = new Set<String>(permissionSetNames);
                withFunctionsAdmin.add('Copado_Functions');

                return Utilities.areAllPermissionSetsAssigned(withFunctionsAdmin, UserInfo.getUserId());
            } catch (Exception ex) {
                return false;
            }
        }

        private Boolean arePersonaDefinitionsCreated() {
            try {
                Integer standardPersona = [SELECT COUNT() FROM copado__Persona_Definition__c WHERE copado__Is_Standard__c = true WITH SYSTEM_MODE];
                return standardPersona == 3;
            } catch (Exception ex) {
                return false;
            }
        }
    }

    public with sharing class ValidationStep {
        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public Boolean isValid {get; set;}

        @AuraEnabled
        public Boolean isMandatory {get; set;}

        ValidationStep(String name, Boolean isValid, Boolean isMandatory)
        {
            this.name = name;
            this.isValid = isValid;
            this.isMandatory = isMandatory;
        }
    }

    public with sharing class QualityChecksState {
        @AuraEnabled
        public Boolean apexTestState { get; set; }
        @AuraEnabled
        public Boolean pmdState { get; set; }

        public QualityChecksState(Boolean apexTestState, Boolean pmdState) {
            this.apexTestState = apexTestState;
            this.pmdState = pmdState;
        }
    }

    public with sharing class PersonaUser {
        @AuraEnabled
        public User user;
        @AuraEnabled
        public copado__Persona_Definition__c persona;
    }

    public with sharing class PersonaData {
        @AuraEnabled
        public String personaId;
        @AuraEnabled
        public String personaName;
        @AuraEnabled
        public Integer personaCount;

        public PersonaData(String personaId, String personaName, Integer personaCount) {
            this.personaId = personaId;
            this.personaName = personaName;
            this.personaCount = personaCount;
        }
    }

    public with sharing class SandboxToolingApiResult {
        public List<SandboxRecord> records { get; set; }
    }

    public with sharing class SandboxRecord {
        public String id { get; set; }
        public String activatedDate { get; set; }
        public String description { get; set; }
        public String endDate { get; set; }
        public String licenseType { get; set; }
        public String sandboxInfoId { get; set; }
        public String sandboxName { get; set; }
        public String sandboxOrganization { get; set; }
        public String createdDate { get; set; }
        public SandboxSource source { get; set; }
    }

    public with sharing class SandboxSource {
        public String id { get; set; }
        public String sandboxName { get; set; }
    }

    public with sharing class SandboxData {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public String refreshDate;
        @AuraEnabled
        public String clonedFrom;
    }

    public with sharing class StageInformation {
        @AuraEnabled
        public List<copado__Stage__c> copadoStages;
        @AuraEnabled
        public List<copado__Stage_Connection__c> stageConnections;
    }

    public with sharing class ConnectedAppStatus {
        @AuraEnabled
        public Boolean isFeatureUsable = false;
        @AuraEnabled
        public Boolean isInstalled = false;
        @AuraEnabled
        public Boolean hasPolicies = false;
        @AuraEnabled
        public Boolean hasPermissionSets = false;
    }

    public with sharing class PersonaDefinitionConfig {
        public List<ConfigEntry> permissionSets;
    }

    public with sharing class ConfigEntry {
        public String name;
        public Boolean isStandard;
    }

    public with sharing class JWTSettingStatus {
        @AuraEnabled
        public Id permissionSetId;
        @AuraEnabled
        public Id permissionSetGroupId;
        @AuraEnabled
        public List<Id> userIds;
        @AuraEnabled
        public Boolean status;

        @SuppressWarnings('PMD.EmptyStatementBlock')
        public JWTSettingStatus() {}

        public JWTSettingStatus (copado.Feature.JWTSettingStatusResult result) {
            this.permissionSetId = result.permissionSetId;
            this.permissionSetGroupId = result.permissionSetGroupId;
            this.userIds = result.userIds;
            this.status = result.status;
        }
    }
}