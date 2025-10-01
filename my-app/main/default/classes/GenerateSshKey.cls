public with sharing class GenerateSshKey {
    @TestVisible
    private static String testkeyResponse = '{"ok": "Keys created"}';

    @InvocableMethod(label='Generate SSH Key for GitRepository' description='This will generate SSH key for a Git repo' category='SFP Migration')
    public static List<Response> execute(List<Request> requests) {
        String createKeyResponse;
        if (Test.isRunningTest()) {
            createKeyResponse = testkeyResponse;
        } else {
            createKeyResponse = copado.RepositoryOAuth.createSSHKey(requests[0].gitRepositoryId);
        }

        Map<String, Object> createResponseByKeys = (Map<String, Object>) JSON.deserializeUntyped(createKeyResponse);
        if (createResponseByKeys.containsKey('ok')) {
            String getKeyResponse = copado.RepositoryOAuth.getSSHKey(requests[0].gitRepositoryId);
            KeyResponse sshKeyByHeader = (KeyResponse) JSON.deserialize(getKeyResponse, KeyResponse.class);

            return new List<Response>{ new Response(sshKeyByHeader.key) };
        }
        return new List<Response>{ new Response(null) };
    }

    // INNER
    public class Request {
        @InvocableVariable(label='Git Repository Id' required=true)
        public String gitRepositoryId;
    }

    public class Response {
        @InvocableVariable(required=true)
        public String sshKey;

        Response(String sshKey) {
            this.sshKey = sshKey;
        }
    }

    private class KeyResponse {
        String key;
    }
}