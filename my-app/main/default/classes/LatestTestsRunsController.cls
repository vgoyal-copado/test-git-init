public with sharing class LatestTestsRunsController {
    // PUBLIC
    @AuraEnabled
    public static Map<Id, List<TestWrapper>> getTests(List<Id> parentIds) {
        try {
            Map<Id, List<TestWrapper>> resultsByParentId = new Map<Id, List<TestWrapper>>();
            Map<Id, List<copado__Test__c>> testsByParentId = getLatestTestsRuns(parentIds);
            
            // Get all tests across all parents for consolidated results
            List<copado__Test__c> allTests = new List<copado__Test__c>();
            for(List<copado__Test__c> tests : testsByParentId.values()) {
                allTests.addAll(tests);
            }
            
            Map<String, copado__Result__c> consolidatedResultByLatestJobExecution = 
                consolidatedResultByLatestJobExecution(allTests);

            // Process each parent's tests
            for(Id parentId : testsByParentId.keySet()) {
                List<TestWrapper> parentResults = new List<TestWrapper>();
                for(copado__Test__c test : testsByParentId.get(parentId)) {
                    parentResults.add(prepareWrapper(test, consolidatedResultByLatestJobExecution));
                }
                resultsByParentId.put(parentId, parentResults);
            }
            
            return resultsByParentId;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    // PRIVATE
    private static Map<Id, List<copado__Test__c>> getLatestTestsRuns(List<Id> parentIds) {
        Map<Id, Set<String>> testIdsByParentId = new Map<Id, Set<String>>();
        
        // Initialize the map for each parent Id
        for(Id parentId : parentIds) {
            testIdsByParentId.put(parentId, new Set<String>());
        }
    
        // Query job executions for all parents in one go
        for (copado__JobExecution__c jobExecution : [
            SELECT Id, copado__DataJson__c, 
                   copado__Promotion__c, copado__UserStoryCommit__c, 
                   copado__Deployment__c, copado__Deployment__r.copado__Promotion__c
            FROM copado__JobExecution__c
            WHERE copado__Promotion__c IN :parentIds 
               OR copado__UserStoryCommit__c IN :parentIds 
               OR copado__Deployment__c IN :parentIds 
               OR copado__Deployment__r.copado__Promotion__c IN :parentIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            // Determine the parent Id for this job execution
            Id parentId = jobExecution.copado__Promotion__c != null ? jobExecution.copado__Promotion__c :
                         jobExecution.copado__UserStoryCommit__c != null ? jobExecution.copado__UserStoryCommit__c :
                         jobExecution.copado__Deployment__c != null ? jobExecution.copado__Deployment__c :
                         jobExecution.copado__Deployment__r.copado__Promotion__c;
            
            if(String.isNotBlank(jobExecution.copado__DataJson__c)) {
                DataJsonWrapper data = (DataJsonWrapper) JSON.deserialize(
                    jobExecution.copado__DataJson__c, DataJsonWrapper.class
                );
                if (data.testIds != null && !data.testIds.isEmpty()) {
                    testIdsByParentId.get(parentId).addAll(data.testIds);
                }
            }
        }
    
        // Get all unique test IDs across all parents
        Set<String> allTestIds = new Set<String>();
        for(Set<String> testIds : testIdsByParentId.values()) {
            allTestIds.addAll(testIds);
        }
    
        // Query all tests in one go
        Map<Id, copado__Test__c> testsById = new Map<Id, copado__Test__c>([
            SELECT Id, Name, copado__Type__c, copado__User_Story__c,
                   copado__ExtensionConfiguration__c, copado__LatestJobExecution__c,
                   copado__ReadyToRun__c, copado__ExtensionConfiguration__r.copado__ExtensionTool__c,
                   copado__LatestJobExecution__r.copado__Job_Step__c,
                   copado__LatestJobExecution__r.copado__Job_Step__r.copado__Result__c,
                   (SELECT Id, Name, copado__Status__c, copado__Start_Time__c 
                    FROM copado__Results__r 
                    ORDER BY copado__Start_Time__c DESC)
            FROM copado__Test__c
            WHERE Id IN :allTestIds
            WITH USER_MODE
        ]);
    
        // Organize tests by parent Id
        Map<Id, List<copado__Test__c>> testsByParentId = new Map<Id, List<copado__Test__c>>();
        for(Id parentId : testIdsByParentId.keySet()) {
            List<copado__Test__c> parentTests = new List<copado__Test__c>();
            for(String testId : testIdsByParentId.get(parentId)) {
                if(testsById.containsKey(testId)) {
                    parentTests.add(testsById.get(testId));
                }
            }
            testsByParentId.put(parentId, parentTests);
        }
    
        return testsByParentId;
    }
    

    private static List<copado__Test__c> getLatestTestsRuns(Set<String> testIds) {
        return [
            SELECT
                Id,
                Name,
                copado__Type__c,
                copado__User_Story__c,
                copado__ExtensionConfiguration__c,
                copado__LatestJobExecution__c,
                copado__ReadyToRun__c,
                copado__ExtensionConfiguration__r.copado__ExtensionTool__c,
                copado__LatestJobExecution__r.copado__Job_Step__c,
                copado__LatestJobExecution__r.copado__Job_Step__r.copado__Result__c,
                (SELECT Id, Name, copado__Status__c, copado__Start_Time__c FROM copado__Results__r ORDER BY copado__Start_Time__c DESC)
            FROM copado__Test__c
            WHERE Id IN :testIds
            WITH USER_MODE
        ];
    }

    private static Map<String, copado__Result__c> consolidatedResultByLatestJobExecution(List<copado__Test__c> tests) {
        Map<String, copado__Result__c> resultByLatestJobExecution = new Map<String, copado__Result__c>();
        Map<String, String> jobExecutionIdByResultId = new Map<String, String>();

        for (copado__Test__c test : tests) {
            if (
                test.copado__LatestJobExecution__c != null &&
                test.copado__LatestJobExecution__r.copado__Job_Step__c != null &&
                test.copado__LatestJobExecution__r.copado__Job_Step__r.copado__Result__c != null
            ) {
                jobExecutionIdByResultId.put(test.copado__LatestJobExecution__r.copado__Job_Step__r.copado__Result__c, test.copado__LatestJobExecution__c);
            }
        }

        if (!jobExecutionIdByResultId.isEmpty()) {
            for (copado__Result__c result : [
                SELECT Id, Name, copado__Start_Time__c, copado__Status__c
                FROM copado__Result__c
                WHERE Id IN :jobExecutionIdByResultId.keyset()
                WITH USER_MODE
            ]) {
                resultByLatestJobExecution.put(jobExecutionIdByResultId.get(result.Id), result);
            }
        }
        return resultByLatestJobExecution;
    }

    private static TestWrapper prepareWrapper(copado__Test__c test, Map<String, copado__Result__c> consolidatedResultByLatestJobExecution) {
        return new TestWrapper()
            .id(test.id)
            .name(test.Name)
            .testType(test.copado__Type__c)
            .testTool(test.copado__ExtensionConfiguration__r.copado__ExtensionTool__c)
            .testUrl()
            .result(test, consolidatedResultByLatestJobExecution);
    }

    //INNER

    public with sharing class DataJsonWrapper {
        public List<String> testIds;
    }
    public with sharing class TestWrapper {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String testType;
        @AuraEnabled
        public String testTool;
        @AuraEnabled
        public String runDate;
        @AuraEnabled
        public String result;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String testUrl;
        @AuraEnabled
        public String resultUrl;

        private TestWrapper id(String id) {
            this.id = id;
            return this;
        }

        private TestWrapper name(String name) {
            this.name = name;
            return this;
        }

        private TestWrapper testType(String testType) {
            this.testType = testType;
            return this;
        }

        private TestWrapper testTool(String testTool) {
            this.testTool = testTool;
            return this;
        }

        private TestWrapper status(copado__Test__c test, String status) {
            this.status = status;

            return this;
        }

        private TestWrapper testUrl() {
            this.testUrl = '/' + this.id;
            return this;
        }

        private TestWrapper result(copado__Test__c test, Map<String, copado__Result__c> consolidatedResultByLatestJobExecution) {
            if (consolidatedResultByLatestJobExecution.containsKey(test.copado__LatestJobExecution__c)) {
                copado__Result__c result = consolidatedResultByLatestJobExecution.get(test.copado__LatestJobExecution__c);
                this.runDate = result.copado__Start_Time__c != null ? result.copado__Start_Time__c.format() : '';
                this.result = result.Name;
                status(test, result.copado__Status__c);
                this.resultUrl = '/' + result.Id;
            } else if (!test.copado__Results__r.isEmpty()) {
                copado__Result__c result = test.copado__Results__r[0];
                this.runDate = result.copado__Start_Time__c != null ? result.copado__Start_Time__c.format() : '';
                this.result = result.Name;
                status(test, result.copado__Status__c);
                this.resultUrl = '/' + result.id;
            } else {
                status(test, '');
            }
            return this;
        }
    }
}