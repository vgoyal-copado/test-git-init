public class CMMetaCacheServiceProto {
    @AuraEnabled
    public static String getDependencies(Id credentialId, Id userStoryId, String retrieveMode, List<CMMetadata> selectedMetadata) {
        if(selectedMetadata == null || selectedMetadata.isEmpty()) {
            return '';
        }
        
        // I'm locating the org information
        copado__User_Story__c userStory = [SELECT Id, copado__Project__r.copado__Deployment_Flow__c, 
                                          copado__Environment__r.copado__Org_ID__c 
                                          FROM copado__User_Story__c 
                                          WHERE Id = :userStoryId LIMIT 1];
                                          
        Id pipelineId = userStory.copado__Project__r.copado__Deployment_Flow__c;
        Id sourceOrgId = userStory.copado__Environment__r.copado__Org_ID__c;
        
        copado__Deployment_Flow_Step__c connection = [SELECT copado__Destination_Environment__r.copado__Org_ID__c 
                                                     FROM copado__Deployment_Flow_Step__c 
                                                     WHERE copado__Deployment_Flow__c = :pipelineId 
                                                     AND copado__Source_Environment__r.copado__Org_ID__c = :sourceOrgId 
                                                     LIMIT 1];
                                                     
        Id destinationOrgId = connection.copado__Destination_Environment__r.copado__Org_ID__c;

        // Create metadata selections
        List<CMMetadata> selections = new List<CMMetadata>();
        for(CMMetadata metadata : selectedMetadata) {
            selections.add(new CMMetadata(
                (String)metadata.type,
                (String)metadata.name
            ));
        }

        // Build request object
        DependencyRequest request = new DependencyRequest(
            pipelineId,
            selections,
            sourceOrgId,
            destinationOrgId,
            retrieveMode
        );

        try {

            System.debug('meta cache -request');
            System.debug(request);
            // I'm making the changes
            HttpResponse response = copado.MetaCacheAPIProxy.callMetaCacheService(
                'api/v3/search-mtdt-dependencies/',
                'POST',
                JSON.serialize(request)
            );
            
            if(response.getStatusCode() == 200) {
                return response.getBody();
            } else {
                throw new ApplicationException(response.getBody());
            }
        } catch (Exception e) {
            String fullErrorMessage = e.getMessage();
            Map<String, Object> errorMap = (Map<String, Object>) JSON.deserializeUntyped(fullErrorMessage);

            String errorMessage = String.isEmpty((String)errorMap.get('message')) 
                ? fullErrorMessage 
                : (String) errorMap.get('message');

            throw new AuraHandledException(errorMessage);
        }
    }

        public class DependencyRequest {
        public String pipelineId;
        public List<CMMetadata> metadataSelections;
        public CompareOptions compareOptions;
        
        public DependencyRequest(String pipelineId, List<CMMetadata> selections, String sourceOrgId, String targetOrgId, String retrieveMode) {
            this.pipelineId = pipelineId;
            this.metadataSelections = selections;
            this.compareOptions = new CompareOptions(retrieveMode, sourceOrgId, targetOrgId);
        }
    }
    
    public class CompareOptions {
        public String retrieveMode;
        public String sourceOrgId; 
        public String targetOrgId;
        
        public CompareOptions(String retrieveMode, String sourceOrgId, String targetOrgId) {
            this.retrieveMode = retrieveMode;
            this.sourceOrgId = sourceOrgId;
            this.targetOrgId = targetOrgId;
        }
    }

}