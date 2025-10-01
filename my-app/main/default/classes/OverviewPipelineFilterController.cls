public with sharing class OverviewPipelineFilterController {
    private static final String SFDX = 'SFDX';
    private static final String PIPELINE_ID_NULL = 'PIPELINE_ID_NULL';
    private static final String ERROR_FETCHING_PROJECTS = 'ERROR_FETCHING_PROJECTS';
    private static final String ERROR_FETCHING_RELEASES = 'ERROR_FETCHING_RELEASES';

    @AuraEnabled(cacheable=true)
    public static List<copado__Deployment_Flow__c> getPipelines() {
        try {
            return new PipelinesSelector().byActiveAndPlatform(true, SFDX);
        } catch (Exception ex) {
            throw new AuraHandledException(System.Label.GenericError);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<copado__Project__c> getProjects(Id pipelineId) {
        try {
            validatePipelineId(pipelineId);
            return new ProjectsSelector().byPipelineId(pipelineId);
        } catch (PipelineFilterException pfe) {
            throw new AuraHandledException(PIPELINE_ID_NULL);
        } catch (Exception ex) {
            throw new AuraHandledException(ERROR_FETCHING_PROJECTS);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<copado__Release__c> getReleases(Id pipelineId, Id projectId) {
        try {
            validatePipelineId(pipelineId);
            ReleasesSelector selector = new ReleasesSelector();
            return projectId != null ? 
                   selector.byPipelineIdAndProjectId(pipelineId, projectId) :
                   selector.byPipelineId(pipelineId);
        } catch (PipelineFilterException pfe) {
            throw new AuraHandledException(PIPELINE_ID_NULL);
        } catch (Exception ex) {
            throw new AuraHandledException(ERROR_FETCHING_RELEASES);
        }
    }

    private static void validatePipelineId(Id pipelineId) {
        if (pipelineId == null) {
            throw new PipelineFilterException(PIPELINE_ID_NULL);
        }
    }

    public class PipelineFilterException extends Exception {}
}