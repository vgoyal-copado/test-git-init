public with sharing class PipelineRequirementValidations {
    private static final String SFDX_DIFFERENCE_ANALYSIS = 'SFDX_Difference_Analysis_1';

    @AuraEnabled(cacheable=false)
    public static Requirements getRequirements(Id pipelineId) {
        try {
            copado__Deployment_Flow__c pipeline = new PipelinesSelector().byId(new Set<Id>{ pipelineId })[0];

            return new Requirements(pipeline);
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=false)
    public static copado__Result__c getResultDetails(Id recordId) {
        try {
            return new ResultsSelector().byId(recordId);
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=false)
    public static void initializeMainBranch(Id recordId, Boolean isVlocityEnabled) {
        try {
            PipelineSettings.EnableVlocitySettingResult result;

            if (isVlocityEnabled) {
                PipelineSettings.EnableVlocitySettingRequest request = new PipelineSettings.EnableVlocitySettingRequest();
                request.pipelineId = recordId;

                result = PipelineSettings.VlocitySetting.enable(request);
            }
            if (!isVlocityEnabled || (result != null && result.status)) {
                PipelineInitializer.InitializeMainBranchRequest request = new PipelineInitializer.InitializeMainBranchRequest();
                request.pipelineId = recordId;

                PipelineInitializer.PreSteps.initializeMainBranch(request);
            }
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getInitializationData(Id pipelineId) {
        try {
            return new PipelinesSelector().byId(new Set<Id>{ pipelineId })[0]?.Initialization_Data__c;
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ' ' + ex.getStackTraceString());
        }
    }

    @AuraEnabled
    public static void clearJobs(Id pipelineId) {
        try {
            List<copado__JobExecution__c> jobs = new JobExecutionsSelector()
                .byPipelineAndStatus(pipelineId, new Set<String>{ 'Successful', 'Error', 'Canceled' });
            if (jobs.isEmpty()) {
                return;
            }

            List<copado__JobExecution__c> jobsToUpdate = new List<copado__JobExecution__c>();
            for (copado__JobExecution__c job : jobs) {
                if (job.copado__Template__r.copado__ApiName__c != SFDX_DIFFERENCE_ANALYSIS) {
                    copado.Jobs.Execution.cancel(job.Id);
                }

                jobsToUpdate.add(new copado__JobExecution__c(Id = job.Id, copado__Pipeline__c = null));
            }

            update as User jobsToUpdate;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    // INNER

    public class Requirements {
        @AuraEnabled
        public Boolean hasConnections;
        @AuraEnabled
        public Boolean hasDefaultAuthCredentials;
        @AuraEnabled
        public String mainBranch;
        @AuraEnabled
        public Id gitRepositoryId;
        @AuraEnabled
        public String gitRepositoryName;
        @AuraEnabled
        public Id repositoryFunctionResultId; // NOTE: This result Id is of a function that is executed to check the Git repository authentication status, count of branches, name of main branch

        public Requirements(copado__Deployment_Flow__c pipeline) {
            PipelineDescriptor pipelineDescriptor = new PipelineDescriptor(pipeline.Id);
            Set<Id> environmentIds = pipelineDescriptor.getEnvironments().keySet();

            this.hasConnections = this.hasPipelineConnections(pipeline.Id);
            this.mainBranch = pipeline.copado__Main_Branch__c;
            this.gitRepositoryId = pipeline?.copado__Git_Repository__c;
            this.gitRepositoryName = pipeline?.copado__Git_Repository__r?.Name;
            this.hasDefaultAuthCredentials = pipelineDescriptor.areCredentialsAuthenticated(environmentIds);
            this.repositoryFunctionResultId = this.areAllConditionsMet() ? this.getRepositoryFunctionResultId(pipeline.Id) : null;
        }

        private Boolean hasPipelineConnections(Id pipelineId) {
            List<copado__Deployment_Flow_Step__c> pipelineConnections = new PipelineConnectionsSelector().byPipelineId(pipelineId);
            return !pipelineConnections.isEmpty();
        }

        private Boolean areAllConditionsMet() {
            return hasConnections && String.isNotBlank(mainBranch) && gitRepositoryId != null && hasDefaultAuthCredentials;
        }

        private Id getRepositoryFunctionResultId(Id pipelineId) {
            List<copado.CopadoFunctions.FunctionParameter> functionParameters = new List<copado.CopadoFunctions.FunctionParameter>();
            functionParameters.add(new copado.CopadoFunctions.FunctionParameter('git_json', '{$Context.Repository.Credential}'));
            functionParameters.add(new copado.CopadoFunctions.FunctionParameter('mainBranch', '{$Context.Main_Branch__c}'));

            copado.CopadoFunctions.ExecuteRequest request = new copado.CopadoFunctions.ExecuteRequest();
            request.functionApiName = 'sfdx_git_repository_validation';
            request.contextId = pipelineId;
            request.parameters = functionParameters;

            return copado.CopadoFunctions.execute(request)?.result?.Id;
        }
    }
}