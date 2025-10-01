public with sharing class ConvertGitSshToRepositoryDetails {
    @InvocableMethod(label='Get Git Repository converted details' category='SFP Migration')
    public static List<Response> execute(List<Request> requests) {
        try {
            Response response = new Response();
            if(String.isNotBlank(requests[0].uri)) {
                
                GitUrlUtils.GitRepoUrls details = GitUrlUtils.getUrlsFromSsh(requests[0].uri);
                 if (details != null) {
                    response.baseUrl = details.baseUrl;
                    response.commitUrl = details.commitUrl;
                    response.pullRequestUrl = details.pullRequestUrl;
                    response.tagUrl = details.tagUrl;
                }
            }
             return new List<Response>{ response };
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    public class Request {
        @InvocableVariable(required=true)
        public String uri;
    }

    public class Response {
        @InvocableVariable
        public String baseUrl;
        @InvocableVariable
        public String commitUrl;
        @InvocableVariable
        public String tagUrl;
        @InvocableVariable
        public String pullRequestUrl;

        @SuppressWarnings('PMD.EmptyStatementBlock')
        public Response() {
        }

        public Response(String baseUrl) {
            this.baseUrl = baseUrl;
        }
    }
}