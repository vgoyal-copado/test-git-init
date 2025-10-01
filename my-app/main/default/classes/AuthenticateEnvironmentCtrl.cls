@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.ExcessivePublicCount')
public with sharing class AuthenticateEnvironmentCtrl {
    private static final String READ_ACCESS_LEVEL = 'Read';
    private static final String EDIT_ACCESS_LEVEL = 'Edit';

    @TestVisible
    private static String mockResponse;

    @AuraEnabled
    public static AuthenticateEnvironmentData getData(Id environmentId) {
        AuthenticateEnvironmentData result = new AuthenticateEnvironmentData();
        result.hasPersonaPermissions = checkPersonaPermissions();
        List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(environmentId);
        copado__Org__c credential = !credentials.isEmpty() ? credentials[0] : null;
        result.credentialId = credential?.Id;
        Set<Id> publicGroupIds = new Set<Id>();
        for (copado__Persona_Definition__c personaDefinition : new PersonaDefinitionsSelector(false, false).getAll()) {
            PersonaOption option = new PersonaOption();
            option.value = personaDefinition.Id;
            option.label = personaDefinition.Name;
            result.personaOptions.add(option);
            PersonaDefinitionConfig config = (PersonaDefinitionConfig) JSON.deserialize(
                personaDefinition.copado__Config_JSON__c,
                PersonaDefinitionConfig.class
            );
            publicGroupIds.add(config.publicGroupId);
            if (config.credentialIds.contains(credential.Id)) {
                result.sharedWithPersonas.add(personaDefinition.Id);
            }
        }
        result.accessLevel = getAccessLevel(
            credential?.Id,
            publicGroupIds,
            result.sharedWithPersonas.isEmpty() ? EDIT_ACCESS_LEVEL : READ_ACCESS_LEVEL
        );
        return result;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    public static String authenticate(Id pipelineId, Id environmentId, List<Id> personaIds, String accessLevel) {
        List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(environmentId);
        copado__Org__c credential = !credentials.isEmpty() ? credentials[0] : null;
        Id credentialId = credential?.Id;
        for (Id personaId : personaIds) {
            copado.Persona.ShareCredentialRequest request = new copado.Persona.ShareCredentialRequest();
            request.personaId = personaId;
            request.credentialIds = new List<Id>{ credentialId };
            request.accessLevel = accessLevel;
            copado.Persona.CredentialService.share(request);
        }
        copado.Credentials.AuthenticateCredentialRequest request = new copado.Credentials.AuthenticateCredentialRequest();
        request.credentialId = credentialId;
        request.startUrl = getStartUrl(pipelineId, environmentId, credentialId);
        copado.Credentials.AuthenticateCredentialResult result = copado.Credentials.authenticate(request);
        return result.authenticateUrl;
    }

    @SuppressWarnings('PMD.CognitiveComplexity, PMD.NcssMethodCount')
    @AuraEnabled
    public static ValidationResult validationUponAuthentication(Id pipelineId, Id environmentId, Id credentialId) {
        ValidationResult result = new ValidationResult();
        List<copado__Org__c> credentials = new CredentialsSelector().byIds(new List<Id>{ credentialId });
        copado__Org__c credential = !credentials.isEmpty() ? credentials[0] : null;
        Set<Id> pipelineEnvironments = getPipelineEnvironments(pipelineId);
        copado__Deployment_Flow__c pipeline = new PipelinesSelector().byIdWithBuilderData(pipelineId);

        // Credential Environment match with selected Environment
        if (credential.copado__Environment__c == environmentId) {
            String sandboxOrgId;
            String selectedSandboxType;
            String selectedSandboxName;
            if (String.isNotBlank(pipeline.Builder_Data__c)) {
                PipelineBuilderData builderData = (PipelineBuilderData) JSON.deserialize(pipeline.Builder_Data__c, PipelineBuilderData.class);
                sandboxOrgId = builderData.selectedSandboxOrgId;
                selectedSandboxType = builderData.selectedSandboxType;
                selectedSandboxName = builderData.selectedSandboxName;
                
                // result.selectedSandboxName(selectedSandboxName).action('updateEnvironment'); Commented under US-0121873 (Reverting changes of US-0085043)
            }

            // 1. Salesforce org doesn't match with selected sandbox
            if (
                String.isNotBlank(sandboxOrgId) &&
                String.isNotBlank(credential.copado__SFDC_Org_ID__c) &&
                !credential.copado__SFDC_Org_ID__c.startsWithIgnoreCase(sandboxOrgId)
            ) {
                return result
                    .invalid()
                    .errorMessage(Label.Incorrect_Sandbox_Authenticated_Error)
                    .authenticationErrorBody(
                        String.format(Label.Incorrect_Sandbox_Authenticated_Error_Body, new List<String>{ selectedSandboxType, selectedSandboxName })
                    )
                    .errorVariant('warning')
                    .selectedSandboxOrgId(sandboxOrgId);
            }
        }  // Credential Environment mismatch with selected Environment
        else {
            // Platform Match
            if (credential.copado__Environment__r.copado__Platform__c == pipeline.copado__Platform__c) {
                // 2. Environment Exists in same pipeline
                if (pipelineEnvironments.contains(credential.copado__Environment__c)) {
                    return result
                        .invalid()
                        .errorMessage(Label.Credential_Already_Authenticated_Same_Pipeline)
                        .authenticationErrorBody(Label.Credential_Already_Authenticated_Error_Body)
                        .errorVariant('error')
                        .action('resetEnvironment');
                }  // 3. Environment Exists in different pipeline or standalone
                else {
                    /*String refreshDate;
                    if (credential.copado__Org_Type__c == 'Sandbox') {
                        List<copado__Environment__c> environments = new EnvironmentsSelector().byIds(new Set<Id>{ environmentId });
                        refreshDate = environments[0].copado__Last_Refresh_Date__c != null
                            ? environments[0].copado__Last_Refresh_Date__c.format()
                            : ''; 
                    }*/ // Decision under US-0611217
                    return result
                        .invalid()
                        .errorMessage(Label.Credential_Exists_Another_Pipeline)
                        .authenticationErrorBody(Label.Credential_Exists_Another_Pipeline_Error_Body)
                        .errorVariant('warning')
                        .existingEnvironmentId(credential.copado__Environment__c);
                    //.lastRefreshDate(refreshDate); // Decision under US-0611217
                }
            }  // 4. Platform mismatch
            else {
                List<String> parameters = new List<String>();
                parameters.add(credential.copado__Environment__r.copado__Platform__c);
                parameters.add(credential.copado__Environment__c);
                parameters.add(pipeline.copado__Platform__c);
                parameters.add(credential.copado__Environment__r.copado__Platform__c);

                String formattedString = String.format(Label.Credential_Exists_With_Another_Platform_Error_Body, parameters);
                return result
                    .invalid()
                    .errorMessage(Label.Credential_Exists_With_Another_Platform)
                    .authenticationErrorBody(formattedString)
                    .errorVariant('error')
                    .action('deleteCredential');
            }
        }
        return result;
    }

    @AuraEnabled
    public static List<SandboxData> getSandboxes(Id pipelineId) {
        List<SandboxData> result = new List<SandboxData>();
        copado__Environment__c production = new PipelineDescriptor(pipelineId).findFinalEnvironment();
        List<copado__Org__c> credentials = new CredentialsSelector().defaultCredential(production.Id);
        copado__Org__c productionCredential = !credentials.isEmpty() ? credentials[0] : null;
        copado.GlobalAPI.ProxyOrgRequest request = new copado.GlobalAPI.ProxyOrgRequest();
        request.endPointUrlService = getSandboxesEndpoint();
        request.orgCredentialId = productionCredential?.Id;
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
            sandbox.type = getSandboxTypeLabel(sandboxRecord.licenseType);
            sandbox.description = sandboxRecord.description;
            sandbox.refreshDate = sandboxRecord.endDate != null
                ? DateTime.valueOfGmt(sandboxRecord.endDate.replace('T', ' ')).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                : '';
            sandbox.clonedFrom = sandboxRecord.source != null ? sandboxRecord.source.sandboxName : Label.Production;
            result.add(sandbox);
        }
        result.sort();
        return result;
    }

    private static Set<Id> getPipelineEnvironments(Id pipelineId) {
        Set<Id> result = new Set<Id>();
        for (copado__Deployment_Flow_Step__c pipelineConnection : new PipelineConnectionsSelector().byPipelineId(pipelineId)) {
            result.add(pipelineConnection.copado__Source_Environment__c);
            result.add(pipelineConnection.copado__Destination_Environment__c);
        }
        return result;
    }

    private static String getSandboxTypeLabel(String licenseType) {
        switch on licenseType {
            when 'DEVELOPER' {
                return Label.Developer_Sandbox;
            }
            when 'DEVELOPER_PRO' {
                return Label.Developer_Pro_Sandbox;
            }
            when 'PARTIAL' {
                return Label.Partial_Copy_Sandbox;
            }
            when 'FULL' {
                return Label.Full_Sandbox;
            }
            when else {
                return '';
            }
        }
    }

    private static String getSandboxesEndpoint() {
        String toolingApiPath = Settings.TOOLING_API_ENDPOINT;
        String queryPath = '/query/?q=';
        String query = 'SELECT+Id,ActivatedDate,Description,EndDate,LicenseType,SandboxInfoId,SandboxName,SandboxOrganization,CreatedDate,Source.SandboxName+FROM+SandboxProcess+WHERE+Status=\'1\'';
        return toolingApiPath + queryPath + query;
    }

    private static Boolean checkPersonaPermissions() {
        return [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE AssigneeId = :Userinfo.getUserId() AND PermissionSet.Name = 'Persona_Management'
                WITH SYSTEM_MODE
            ] > 0;
    }

    private static String getAccessLevel(Id credentialId, Set<Id> publicGroupIds, String defaultAccessLevel) {
        String result = defaultAccessLevel;
        for (copado__Org__Share orgShare : [
            SELECT Id, AccessLevel
            FROM copado__Org__Share
            WHERE ParentId = :credentialId AND UserOrGroupId IN :publicGroupIds
            WITH SYSTEM_MODE
        ]) {
            if (orgShare.AccessLevel == EDIT_ACCESS_LEVEL) {
                result = EDIT_ACCESS_LEVEL;
                break;
            }
        }
        return result;
    }

    private static String getStartUrl(Id pipelineId, Id environmentId, Id credentialId) {
        String recordIdParameter = getParameterCopadoNamespace() + 'recordId=' + pipelineId;
        String environmentIdParameter = getParameterNamespace() + 'environmentId=' + environmentId;
        String credentialIdParameter = getParameterNamespace() + 'credentialId=' + credentialId;

        return Url.getOrgDomainUrl().getProtocol() +
            '://' +
            Url.getOrgDomainUrl().getHost() +
            '/lightning/n/' +
            getPageNamespace() +
            'Pipeline_Builder?' +
            recordIdParameter +
            '&' +
            environmentIdParameter +
            '&' +
            credentialIdParameter;
    }

    private static String getParameterNamespace() {
        return String.isBlank(PipelineBuilderHeader.NAMESPACE) ? 'c__' : PipelineBuilderHeader.ns;
    }

    private static String getParameterCopadoNamespace() {
        return String.isBlank(PipelineBuilderHeader.COPADO_NAMESPACE) ? 'c__' : PipelineBuilderHeader.copadoNs;
    }

    // Note: Namespace with __ appended
    private static String getPageNamespace() {
        return String.isBlank(PipelineBuilderHeader.NAMESPACE) ? '' : PipelineBuilderHeader.ns;
    }

    public with sharing class AuthenticateEnvironmentData {
        @AuraEnabled
        public Boolean hasPersonaPermissions;
        @AuraEnabled
        public List<PersonaOption> personaOptions;
        @AuraEnabled
        public Id credentialId;
        @AuraEnabled
        public List<Id> sharedWithPersonas;
        @AuraEnabled
        public String accessLevel;

        public AuthenticateEnvironmentData() {
            this.hasPersonaPermissions = false;
            this.personaOptions = new List<PersonaOption>();
            this.sharedWithPersonas = new List<Id>();
        }
    }

    public with sharing class PersonaOption {
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
    }

    public with sharing class PersonaDefinitionConfig {
        @AuraEnabled
        public List<Id> credentialIds;
        @AuraEnabled
        public Id publicGroupId;
    }

    public with sharing class ValidationResult {
        @AuraEnabled
        public Boolean isValid;
        @AuraEnabled
        public String errorMessage;
        @AuraEnabled
        public String authenticationErrorBody;
        @AuraEnabled
        public String errorVariant;
        @AuraEnabled
        public String existingEnvironmentId;
        @AuraEnabled
        public String lastRefreshDate;
        @AuraEnabled
        public String selectedSandboxOrgId;
        @AuraEnabled
        public String selectedSandboxName;
        @AuraEnabled
        public String action;

        public ValidationResult() {
            this.isValid = true;
            this.action = '';
        }

        public ValidationResult invalid() {
            this.isValid = false;
            return this;
        }

        public ValidationResult errorMessage(String errorMessage) {
            this.errorMessage = errorMessage;
            return this;
        }

        public ValidationResult authenticationErrorBody(String authenticationErrorBody) {
            this.authenticationErrorBody = authenticationErrorBody;
            return this;
        }

        public ValidationResult errorVariant(String errorVariant) {
            this.errorVariant = errorVariant;
            return this;
        }

        public ValidationResult existingEnvironmentId(String existingEnvironmentId) {
            this.existingEnvironmentId = existingEnvironmentId;
            return this;
        }

        public ValidationResult lastRefreshDate(String refreshDate) {
            this.lastRefreshDate = refreshDate;
            return this;
        }

        public ValidationResult selectedSandboxOrgId(String selectedSandboxOrgId) {
            this.selectedSandboxOrgId = selectedSandboxOrgId;
            return this;
        }

        public ValidationResult selectedSandboxName(String selectedSandboxName) {
            this.selectedSandboxName = selectedSandboxName;
            return this;
        }

        public ValidationResult action(String action) {
            this.action = action;
            return this;
        }
    }

    public with sharing class SandboxData implements Comparable {
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

        public Integer compareTo(Object compareWith) {
            SandboxData other = (SandboxData) compareWith;
            if (this.refreshDate == null) {
                return other.refreshDate == null ? -1 : 0;
            }

            if (other.refreshDate == null) {
                return -1;
            }

            // Use valueOfGmt to handle ISO 8601 with 'Z'
            DateTime thisDate = DateTime.valueOfGmt(this.refreshDate.replace('T', ' ').replace('Z', ''));
            DateTime otherDate = DateTime.valueOfGmt(other.refreshDate.replace('T', ' ').replace('Z', ''));
            if (thisDate > otherDate) {
                return -1;
            } else if (thisDate < otherDate) {
                return 1;
            } else {
                return 0;
            }
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

    public with sharing class PipelineBuilderData {
        public String selectedSandboxOrgId;
        public String selectedSandboxType;
        public String selectedSandboxName;
    }
}