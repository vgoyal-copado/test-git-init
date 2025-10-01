@SuppressWarnings('PMD.CognitiveComplexity')
public with sharing class QuickStartGitRepositoryCtrl {

    private static final String REPOSITORIES = 'Repositories';

    @AuraEnabled(cacheable=false)
    public static String getLoginURI(String provider, Id repositoryId, String redirectURI) {
        try {
            return copado.RepositoryOAuth.getLoginUrl(new copado.RepositoryOAuth.LoginUrlRequest(provider, repositoryId, redirectURI));
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Configuration init(Id recordId) {
        try {
            copado.RepositoryOAuth.Configuration config = copado.RepositoryOAuth.init(recordId);
            return new Configuration(config);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=false)
    public static String validateGitConnection(Id repositoryId) {
        try {
            return copado.RepositoryOAuth.validateGitConnection(repositoryId);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled
    public static String createSSHKey(Id repositoryId) {
        try {
            return copado.RepositoryOAuth.createSSHKey(repositoryId);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }


    @AuraEnabled(cacheable=false)
    public static void deleteSSHKey(Id attachmentId) {
        try {
            if (String.isNotBlank(attachmentId)) {
                List<Attachment> attachments = new AttachmentsSelector().byId(new Set<Id>{ attachmentId });

                if (!attachments.isEmpty()) {
                    Utilities.performDML(attachments, 'delete', AccessLevel.SYSTEM_MODE);
                }
            }
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }


    @AuraEnabled(cacheable=false)
    public static String getSSHKey(Id repositoryId) {
        try {
            return copado.RepositoryOAuth.getSSHKey(repositoryId);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=false)
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static void save(Id repositoryId, String authType, String username, String password, String extraHeaders) {
        try {
            copado.RepositoryOAuth.RepositoryAuthenticationRequest request = new copado.RepositoryOAuth.RepositoryAuthenticationRequest();
            request.repositoryId = repositoryId;
            request.authType = authType;
            request.username = username;
            request.password = password;
            request.extraHeaders = extraHeaders;

            copado.RepositoryOAuth.authenticate(request);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getExistingRepositories(Id repositoryId) {
        try {
            List<Attachment> result = [SELECT Id, ParentId, Body, Name FROM Attachment where ParentId = :repositoryId AND Name = :REPOSITORIES WITH USER_MODE];
            return result.isEmpty() ? null : result[0].Body.toString();
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=false)
    public static void saveRepositorySelection(String serializedRequest) {
        try {
            GitRepoRequest request = (GitRepoRequest) JSON.deserialize(serializedRequest, GitRepoRequest.class);
            copado.RepositoryOAuth.addSSHKey(asRepositoryRequest(request));
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    // PRIVATE

    private static copado.RepositoryOAuth.AddSSHKeyRequest asRepositoryRequest(GitRepoRequest request) {
        copado.RepositoryOAuth.AddSSHKeyRequest result = new copado.RepositoryOAuth.AddSSHKeyRequest();
        result.recordId = request.recordId;
        result.repositoryId = request.repositoryId;
        result.repositoryName = request.repositoryName;
        result.state = request.state;
        result.addReadme = String.isBlank(request.repositoryId);

        return result;
    }

    // INNER

    public with sharing class Configuration {
        @AuraEnabled
        public String username{ get; set;}
        @AuraEnabled
        public String headers{ get; set;}
        @AuraEnabled
        public String authType{ get; set;}
        @AuraEnabled
        public SSHKey sshKey{ get; set;}
        @AuraEnabled
        public String repositoryName{ get; set;}

        public Configuration(copado.RepositoryOAuth.Configuration configuration) {
            this.authType = configuration?.authType;
            this.headers = configuration?.headers;
            this.repositoryName = configuration?.repositoryName;
            this.sshKey = configuration?.sshKey == null ? null : new SSHKey(configuration.sshKey);
            this.username = configuration?.username;
        }
    }


    public with sharing class SSHKey {
        @AuraEnabled
        public String key {get; set;}
        @AuraEnabled
        public String attachmentId {get; set;}

        public SSHKey(copado.RepositoryOAuth.SSHKey sshKey) {
            this.key = sshKey?.key;
            this.attachmentId = sshKey?.attachmentId;
        }
    }

    public with sharing class GitRepoRequest {
        @AuraEnabled
        public Id recordId { get; set; }
        @AuraEnabled
        public String repositoryId { get; set; }
        @AuraEnabled
        public String repositoryName { get; set; }
        @AuraEnabled
        public String state { get; set; }
    }
}