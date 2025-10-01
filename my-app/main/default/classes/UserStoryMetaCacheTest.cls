@IsTest
private class UserStoryMetaCacheTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    static void testRefreshDependenciesSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            //Setup
            copado__User_Story__c userStory = [SELECT Id FROM copado__User_Story__c LIMIT 1];
            Id pipelineId = getPipelineId();

            UserStoryMetaCache.mockDependenciesStatusCode = 200;
            UserStoryMetaCache.mockDependenciesResponse = '{"eventId":"EVT-123"}';


            List<UserStoryMetaCache.Metadata> selections = new List<UserStoryMetaCache.Metadata>();
            UserStoryMetaCache.Metadata md = new UserStoryMetaCache.Metadata();
            md.name = 'Class123';
            md.type = 'ApexClass';
            selections.add(md);

            RefreshDependencyWrapper request = new RefreshDependencyWrapper();
            request.credentialId = getDevCredential().Id;
            request.userStoryId = userStory.Id;
            request.pipelineId = pipelineId;
            request.refreshMode = 'CUSTOM';
            request.selectedMetadata = selections;

            //Exercise
            Test.startTest();

            String eventId = UserStoryMetaCache.refreshDependencies(request);
            Test.stopTest();

            // Verify
            System.assertEquals('EVT-123', eventId, 'Should return the eventId from mock response');
        }
    }

    @IsTest
    static void testGetRefreshStatusSuccess() {
        System.runAs(TestUtilities.getRunAsUser()) {
            //Setup
            UserStoryMetaCache.mockDependenciesStatusCode = 200;
            String body = '{"eventId":"EVT-123","status":"COMPLETED"}';
            UserStoryMetaCache.mockDependenciesResponse = body;

            //Exercise
            Test.startTest();
            String response = UserStoryMetaCache.getRefreshStatus('EVT-123');
            Test.stopTest();

            //Verify
            System.assertEquals(body, response, 'Should return the raw response body');
        }
    }
    
    @IsTest
    static void testGetRefreshStatusWithNoEventId() {
        System.runAs(TestUtilities.getRunAsUser()) {

            //Exercise
            Test.startTest();
            try {
                UserStoryMetaCache.getRefreshStatus('');
            } catch(Exception ex) {
                System.assert(ex.getStackTraceString().contains('UserStoryMetaCache'), 'Incorrect exception');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void getDependenciesTest_Success() {
        System.runAs(TestUtilities.getRunAsUser()) {
            copado__User_Story__c userStory = [SELECT Id FROM copado__User_Story__c LIMIT 1];
            
            // Create test metadata
            UserStoryMetaCache.Metadata testMetadata = new UserStoryMetaCache.Metadata();
            testMetadata.name = 'TestClass';
            testMetadata.type = 'ApexClass';        
            
            UserStoryMetaCache.mockDependenciesResponse = '{"success": true}';
            
            Test.startTest();
            
            String result = UserStoryMetaCache.getDependencies(
                getDevCredential().Id,
                userStory.Id,
                'all',
                new List<UserStoryMetaCache.Metadata>{testMetadata}
            );
            Test.stopTest();

            Assert.areEqual('{"success": true}', result, 'Returned response is incorrect');
        }
    }
    
    @IsTest
    static void getDependenciesTest_KO_StatusCode() {
        System.runAs(TestUtilities.getRunAsUser()) {
            try {
                copado__User_Story__c userStory = [SELECT Id FROM copado__User_Story__c LIMIT 1];
                
                // Create test metadata
                UserStoryMetaCache.Metadata testMetadata = new UserStoryMetaCache.Metadata();
                testMetadata.name = 'TestClass';
                testMetadata.type = 'ApexClass';        
                
                UserStoryMetaCache.mockDependenciesResponse = '{"success": true}';
                UserStoryMetaCache.mockDependenciesStatusCode = 500;
                
                Test.startTest();
                
                String result = UserStoryMetaCache.getDependencies(
                    getDevCredential().Id,
                    userStory.Id,
                    'all',
                    new List<UserStoryMetaCache.Metadata>{testMetadata}
                );
                Test.stopTest();

            	System.assert(false, 'Expected exception was not thrown');
            } catch (Exception ex) {
                System.assert(ex.getStackTraceString().contains('UserStoryMetaCache'), 'Incorrect exception');
            }
        }
    }

    @IsTest
    static void getDependenciesTest_InputError() {
        System.runAs(TestUtilities.getRunAsUser()) {
            try {
                Test.startTest();
                String result = UserStoryMetaCache.getDependencies(null, null, null, null);
                Test.stopTest();
                
                System.assert(false, 'Expected exception was not thrown');
            } catch (Exception ex) {
                System.assert(ex.getStackTraceString().contains('UserStoryMetaCache'), 'Incorrect exception');
            }
        }
    }

    @IsTest
    static void isDependencyTabEnabledTest_WhenActivated() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Set up test data
            Id pipelineId = getPipelineId();
            
            // Mock response for activated status
            UserStoryMetaCache.mockCacheStatusResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "deactivated"}}}';
            
            Test.startTest();
            String result = UserStoryMetaCache.isDependencyTabEnabled(pipelineId);
            Test.stopTest();
            
            System.assertEquals('deactivated', result.toLowerCase(), 'MetaCache should be deactivated');
        }
    }
    
    @IsTest
    private static void checkMetaCacheStatusTest_OK() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();
            
            // Mock response for activated status
        	UserStoryMetaCache.mockCacheStatusResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "activated"}}}';

            // Exercise
            Test.startTest();
            Map<String, Object> result = UserStoryMetaCache.checkMetaCacheStatus(pipelineId);
            Test.stopTest();

            // Assertions
            System.assertEquals('activated', getPipelineStatus(result), 'MetaCache should be activated.');
        }
    }
    
    @IsTest
    private static void checkMetaCacheStatusTest_KO() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Setup
            Id pipelineId = getPipelineId();
            
            // Mock response for activated status

        	UserStoryMetaCache.mockCacheStatusResponse = '{"success": true, "globalStatus": {"pipeline": {"pipelineStatus": "activated"}}}';

            // Exercise
            Test.startTest();
            Map<String, Object> result = UserStoryMetaCache.checkMetaCacheStatus(pipelineId);
            Test.stopTest();

            // Assertions
            System.assertEquals('activated', getPipelineStatus(result), 'MetaCache should be activated.');
        }
    }
    
    @IsTest
    static void getValidatedMetaCacheStatusTest_OK_200() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Set up test data
            Map<String, Object> globalStatus = new Map<String, Object>{
                'pipeline' => new Map<String, Object>{
                    'pipelineStatus' => 'deactivated'
                }
            };
            Map<String, Object> mockResp = new Map<String, Object>{
                'statusCode' => 200,
                'globalStatus' => globalStatus
            };
            
            // Exercise
            Test.startTest();
            String result = UserStoryMetaCache.getValidatedMetaCacheStatus(mockResp);
            Test.stopTest();
            
            // Assertions
            System.assertEquals('deactivated', result.toLowerCase(), 'MetaCache should be deactivated');
        }
    }
    
    @IsTest
    static void getValidatedMetaCacheStatusTest_OK_404() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // Set up test data'
            Map<String, Object> globalStatus = new Map<String, Object>{
                'pipeline' => new Map<String, Object>{
                    'pipelineStatus' => 'deactivated'
                }
            };
            Map<String, Object> mockResp = new Map<String, Object>{
                'statusCode' => 404,
                'globalStatus' => globalStatus
            };
            
            // Exercise
            Test.startTest();
            String result = UserStoryMetaCache.getValidatedMetaCacheStatus(mockResp);
            Test.stopTest();
            
            // Assertions
            System.assertEquals('deactivated', result.toLowerCase(), 'MetaCache should be deactivated');
        }
    }
    
    @IsTest
    static void getValidatedMetaCacheStatusTest_KO() {
        System.runAs(TestUtilities.getRunAsUser()) {
                // Set up test data
                Map<String, Object> globalStatus = new Map<String, Object>{
                    'pipeline' => new Map<String, Object>{
                        'pipelineStatus' => 'invalid-status'
                    }
                };
                Map<String, Object> mockResp = new Map<String, Object>{
                    'statusCode' => 500,
                    'globalStatus' => globalStatus
                };
                
                // Exercise
                Test.startTest();
                String result = UserStoryMetaCache.getValidatedMetaCacheStatus(mockResp);
                Test.stopTest();
                
                // Assertions
            System.assertEquals('deactivated', result.toLowerCase(), 'MetaCache should be deactivated');
        }
    }

    @IsTest
    static void getPipelineFromUserStoryTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
                // Set up test data
                // UserStory with Project
                copado__User_Story__c userStory = getUserStory();
                
                // Exercise
                Test.startTest();
                copado__Deployment_Flow__c result = UserStoryMetaCache.getPipelineFromUserStory(userStory);
                Test.stopTest();
                
                // Assertions
            System.assertNotEquals(null, result, 'Expected a Pipeline to be returned.');
        }
    }
    
    // HELPER

    private static void createData() {
        System.runAs(TestUtilities.getRunAsUser()) {
            Environment dev1 = new Environment().name('Dev1').orgId('a0t5p00000eFWXq');
            Environment staging = new Environment().name('Staging').orgId('a0fS8000001DMTZ');
            Credential devCred = new Credential(dev1).name('Dev1');
            new Credential(staging).name('Staging');

            new Pipeline()
                .name('MyPipeline')
                .mainBranch('main')
                .platform('SFDX')
                .add(new Project())
                .add(new PipelineConnection().sourceEnvironment(dev1).destinationEnvironment(staging).destinationBranch('staging').branch('dev1'))
            .persist();
        

            copado__User_Story__c story = new copado__User_Story__c(
                copado__User_Story_Title__c = 'My Test User Story',
                copado__Environment__c = dev1.Id,
				copado__Org_Credential__c = devCred.Id,
                copado__Project__c = getProject().Id
            );
            insert story;
        }
    }

    private static copado__Project__c getProject() {
        return [
            SELECT Id
            FROM copado__Project__c
            LIMIT 1
        ];
    }
    
    private static copado__Org__c getDevCredential() {
        return [
            SELECT Id, Name
            FROM copado__Org__c
            WHERE Name = 'Dev1'
            LIMIT 1
        ];
    }

    private static Id getPipelineId(){
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1].Id;
    }

    private static copado__User_Story__c getUserStory(){
        return [ SELECT copado__Environment__r.copado__Org_ID__c, copado__Project__r.copado__Deployment_Flow__c,
                    copado__Release__r.copado__Project__c
                FROM copado__User_Story__c
                LIMIT 1
        ];
    }

    private static String getPipelineStatus(Map<String, Object> result){
        Map<String, Object> globalStatus = (Map<String, Object>)result.get('globalStatus');
        Map<String, Object> pipelineStatus = (Map<String, Object>)globalStatus.get('pipeline');
        return (String)pipelineStatus.get('pipelineStatus');
    }
}