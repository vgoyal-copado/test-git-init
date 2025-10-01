@isTest
public class ConvertGitSshToRepositoryDetailsTest {

    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
    }
    
    @isTest
    static void testGitHubSshUrl() {
        System.runAs(TestUtilities.getRunAsUser()) {
            List<ConvertGitSshToRepositoryDetails.Request> requests = new List<ConvertGitSshToRepositoryDetails.Request>();
            ConvertGitSshToRepositoryDetails.Request req = new ConvertGitSshToRepositoryDetails.Request();
            req.uri = 'git@github.com:octocat/Hello-World.git';
            requests.add(req);
    
            Test.startTest();
            List<ConvertGitSshToRepositoryDetails.Response> responses = ConvertGitSshToRepositoryDetails.execute(requests);
            Test.stopTest();
    
            System.assertEquals('https://github.com/octocat/Hello-World', responses[0].baseUrl, 'The url matches');
            System.assertEquals('https://github.com/octocat/Hello-World/commits/', responses[0].commitUrl, 'The url matches');
            System.assertEquals('https://github.com/octocat/Hello-World/tags/', responses[0].tagUrl, 'The url matches');
            System.assertEquals('https://github.com/octocat/Hello-World/pulls/', responses[0].pullRequestUrl, 'The url matches');
        }
    }

    @isTest
    static void testGitLabSshUrl() {
        System.runAs(TestUtilities.getRunAsUser()) {
        
            List<ConvertGitSshToRepositoryDetails.Request> requests = new List<ConvertGitSshToRepositoryDetails.Request>();
            ConvertGitSshToRepositoryDetails.Request req = new ConvertGitSshToRepositoryDetails.Request();
            req.uri = 'git@gitlab.com:john/project-x.git';
            requests.add(req);
    
            Test.startTest();
            List<ConvertGitSshToRepositoryDetails.Response> responses = ConvertGitSshToRepositoryDetails.execute(requests);
            Test.stopTest();
    
            System.assertEquals('https://gitlab.com/john/project-x', responses[0].baseUrl, 'The url matches');
            System.assertEquals('https://gitlab.com/john/project-x/-/commits/', responses[0].commitUrl, 'The url matches');
            System.assertEquals('https://gitlab.com/john/project-x/-/tags/', responses[0].tagUrl, 'The url matches');
            System.assertEquals('https://gitlab.com/john/project-x/-/merge_requests/', responses[0].pullRequestUrl, 'The url matches');
        }
    }

    @isTest
    static void testBitbucketSshUrl() {
        System.runAs(TestUtilities.getRunAsUser()) {

            List<ConvertGitSshToRepositoryDetails.Request> requests = new List<ConvertGitSshToRepositoryDetails.Request>();
            ConvertGitSshToRepositoryDetails.Request req = new ConvertGitSshToRepositoryDetails.Request();
            req.uri = 'git@bitbucket.org:teamalpha/repo-one.git';
            requests.add(req);
    
            Test.startTest();
            List<ConvertGitSshToRepositoryDetails.Response> responses = ConvertGitSshToRepositoryDetails.execute(requests);
            Test.stopTest();
    
            System.assertEquals('https://bitbucket.org/teamalpha/repo-one', responses[0].baseUrl, 'The url matches');
            System.assertEquals('https://bitbucket.org/teamalpha/repo-one/commits/', responses[0].commitUrl, 'The url matches');
            System.assertEquals('https://bitbucket.org/teamalpha/repo-one/src/', responses[0].tagUrl, 'The url matches');
            System.assertEquals('https://bitbucket.org/teamalpha/repo-one/pull-requests/', responses[0].pullRequestUrl, 'The url matches');
        }
    }

    @isTest
    static void testInvalidUrl() {
        System.runAs(TestUtilities.getRunAsUser()) {

            List<ConvertGitSshToRepositoryDetails.Request> requests = new List<ConvertGitSshToRepositoryDetails.Request>();
            ConvertGitSshToRepositoryDetails.Request req = new ConvertGitSshToRepositoryDetails.Request();
            req.uri = 'invalid-ssh-url';
            requests.add(req);
    
            Test.startTest();
            List<ConvertGitSshToRepositoryDetails.Response> responses = ConvertGitSshToRepositoryDetails.execute(requests);
            Test.stopTest();
    
            System.assertEquals(null, responses[0].baseUrl, 'The url matches');
            System.assertEquals(null, responses[0].commitUrl, 'The url matches');
            System.assertEquals(null, responses[0].tagUrl, 'The url matches');
            System.assertEquals(null, responses[0].pullRequestUrl, 'The url matches');
        }
    }
}