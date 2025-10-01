public with sharing class AuthenticateGitRepository {
    @InvocableMethod(label='Authenticate GitRepository In SF' description='This will authenticate the git repo in backend' category='SFP Migration')
    public static void execute(List<Request> requests) {
        Request request = requests[0];

        if (request.repositoryUri.startsWith('https')) {
            copado.RepositoryOAuth.RepositoryAuthenticationRequest authRequest = new copado.RepositoryOAuth.RepositoryAuthenticationRequest();
            authRequest.repositoryId = request.sfRepositoryId;
            authRequest.authType = 'HTTPS';
            authRequest.username = request.userName;
            authRequest.password = request.password;
            authRequest.extraHeaders = request.extraHeaders;

            copado.RepositoryOAuth.authenticate(authRequest);
        }
    }

    // INNER
    public class Request {
        @InvocableVariable(label='Git Repository Id' required=true)
        public Id sfRepositoryId;

        @InvocableVariable(label='Https Username')
        public String userName;

        @InvocableVariable(label='Https Password')
        public String password;

        @InvocableVariable(label='Https Extra Headers')
        public String extraHeaders;

        @InvocableVariable(label='Git Repository Uri' required=true)
        public String repositoryUri;
    }
}