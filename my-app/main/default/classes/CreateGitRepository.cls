public with sharing class CreateGitRepository {
    @InvocableMethod(label='Create SFP Git Repository' category='SFP Migration')
    public static List<Response> execute(List<Request> requests) {
        Id pipelineId = requests[0].classicPipelineId;
        copado__Deployment_Flow__c pipeline = [
            SELECT Id, copado__Git_Repository__c
            FROM copado__Deployment_Flow__c
            WHERE Id = :pipelineId
            WITH USER_MODE
        ];
        copado__Git_Repository__c classicRepo = [
            SELECT Id, Name, copado__Git_Provider__c
            FROM copado__Git_Repository__c
            WHERE Id = :pipeline.copado__Git_Repository__c
            WITH USER_MODE
        ];

        Id sfRepositoryId = createGitRepositoryRecord(requests[0], classicRepo);
        return new List<Response>{ new Response(sfRepositoryId) };
    }

    // PRIVATE

    private static Id createGitRepositoryRecord(Request req, copado__Git_Repository__c classicRepo) {
        copado__Git_Repository__c repository = new copado__Git_Repository__c(
            Name = 'SFP - ' + classicRepo.Name,
            copado__URI__c = req.repositoryUri,
            copado__Git_Provider__c = classicRepo.copado__Git_Provider__c
        );

        List<SObject> sanitizedRecords = Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ repository }).getRecords();
        
        Utilities.performDML(sanitizedRecords, 'insert', AccessLevel.USER_MODE);

        return ((copado__Git_Repository__c) sanitizedRecords[0]).Id;
    }

    // INNER
    public class Request {
        @InvocableVariable(label='Classic Pipeline Id' required=true)
        public Id classicPipelineId;

        @InvocableVariable(label='Sfp Git Repository URI' required=true)
        public String repositoryUri;
    }

    public class Response {
        @InvocableVariable(required=true)
        public Id sfpRepositoryId;

        Response(Id sfpRepositoryId) {
            this.sfpRepositoryId = sfpRepositoryId;
        }
    }
}