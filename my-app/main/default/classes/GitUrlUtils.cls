public class GitUrlUtils {
    public class GitRepoUrls {
        public String provider;
        public String username;
        public String repository;
        public String baseUrl;
        public String commitUrl;
        public String tagUrl;
        public String pullRequestUrl;
    }

    public static GitRepoUrls getUrlsFromSsh(String sshUrl) {
        GitRepoUrls urls = new GitRepoUrls();

        if (String.isBlank(sshUrl)) {
            return null;
        }

        // GitHub, GitLab, Bitbucket
        Pattern commonPattern = Pattern.compile('git@([^:]+):([^/]+)/([^\\.]+)(\\.git)?');
        Matcher m = commonPattern.matcher(sshUrl);
        if (m.matches()) {
            urls.provider = m.group(1);  // github.com, gitlab.com, bitbucket.org
            urls.username = m.group(2);
            urls.repository = m.group(3);

            String base = 'https://' + urls.provider + '/' + urls.username + '/' + urls.repository;

            // Default paths — can be overridden based on provider
            String commitPath = 'commits';
            String tagPath = 'tags';
            String prPath = 'pull-requests';

            if (urls.provider == 'bitbucket.org') {
                commitPath = 'commits';
                tagPath = 'src';
                prPath = 'pull-requests';
            } else if (urls.provider == 'gitlab.com' || urls.provider.endsWith('.copado.com')) {
                commitPath = '-/commits';
                tagPath = '-/tags';
                prPath = '-/merge_requests';
            } else if (urls.provider == 'github.com') {
                commitPath = 'commits';
                tagPath = 'tags';
                prPath = 'pulls';
            }

            urls.baseUrl = base;
            urls.commitUrl = base + '/' + commitPath + '/';
            urls.tagUrl = base + '/' + tagPath + '/';
            urls.pullRequestUrl = base + '/' + prPath + '/';

            return urls;
        }

        // Microsoft Team Services / Azure DevOps
        Pattern azurePattern = Pattern.compile('git@ssh\\.dev\\.azure\\.com:v3\\/([^\\/]+)\\/([^\\/]+)\\/([^\\.]+)');
        Matcher a = azurePattern.matcher(sshUrl);
        if (a.matches()) {
            urls.provider = 'visualstudio.com';
            urls.username = a.group(1);      // org
            String project = a.group(2);     // project
            urls.repository = a.group(3);    // repo

            String base = 'https://' + urls.username + '.visualstudio.com/' + project + '/_git/' + urls.repository;

            urls.baseUrl = base;
            urls.commitUrl = base + '/commits';
            urls.tagUrl = base + '/tags';
            urls.pullRequestUrl = base + '/pullrequests';

            return urls;
        }

        return null;
    }
}