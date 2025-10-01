@IsTest
private class WireServiceCtrlTest {
    
    private static final String TEST_JSON_WHERE = '{"Title": {"eq": "Manager"}}';
    private static final String TEST_JSON_WHERE_COMPLEX = '{' +
        '"and": [' +
            '{' +
                '"Title": {"eq": "Manager"},' +
                '"Phone": {"ne": null}' +
            '},' +
            '{' +
                '"or": [' +
                    '{"Department": {"eq": "Sales"}},' +
                    '{"LeadSource": {"in": ["Web", "Phone"]}}' +
                ']' +
            '}' +
        ']' +
    '}';
    private static final String INVALID_JSON = '{Title: x "Manager"}';
    

    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            Account testAccount = new Account(
            Name = 'Test Account',
            Type = 'Customer',
            Rating = 'Hot'
        );
        insert testAccount;
        
        List<Contact> contacts = new List<Contact>();
        for(Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                LastName = 'Test Contact ' + i,
                FirstName = 'Test',
                AccountId = testAccount.Id,
                Title = 'Manager',
                Department = 'Sales',
                LeadSource = 'Web',
                Phone = '123-456-7890'
            ));
        }
        insert contacts;
        }
    }
    
    @IsTest
    private static void getRelatedListRecordsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            // EXERCISE
            Test.startTest();
            List<SObject> results = WireServiceCtrl.getRelatedListRecords(
                testAccount.Id,
                'Contacts',
                new List<String>{'Id', 'LastName', 'Title'},
                10,
                new List<String>{'LastName'},
                TEST_JSON_WHERE
            );
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(results, 'Results should not be null');
            Assert.isTrue(results.size() > 0, 'Should return contacts');
        }
    }

    @IsTest
    private static void testComplexGraphQLQuery() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            // Using complex JSON query defined in class variables
            
            // EXERCISE
            Test.startTest();
            String result = WireServiceCtrl.getGraphQLToSOQL(TEST_JSON_WHERE_COMPLEX);
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isTrue(result.contains('AND'), 'Should contain AND operator');
            Assert.isTrue(result.contains('OR'), 'Should contain OR operator');
        }
    }
    
    @IsTest
    private static void testNullAndEmptyConditions() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Test.startTest();
            String result1 = GraphQLToSOQLConverter.convert(null);
            String result2 = GraphQLToSOQLConverter.convert('');
            String result3 = GraphQLToSOQLConverter.convert('{}');
            Test.stopTest();
            
            // VERIFY
            Assert.areEqual('', result1, 'Null input should return empty string');
            Assert.areEqual('', result2, 'Empty input should return empty string');
            Assert.areEqual('', result3, 'Empty object should return empty string');
        }
    }
    
    @IsTest
    private static void testVariousOperators() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            String jsonQuery = '{' +
                '"NumberOfEmployees": {"gt": 100},' +
                '"CreatedDate": {"lt": "2023-01-01"},' +
                '"FullName": {"like": "%test name%"},' +
                '"FirstName": {"contains": "test"},' +
                '"LastName": {"notcontains": "test"},' +                
                '"Type": {"in": ["Prospect", "Customer"]},' +
                '"Phone": {"eq": null},' +
                '"Website": {"ne": null},' +
                '"Age": {"ge": 30},' +
                '"Year": {"le": 2000}' +
            '}';
            
            // EXERCISE
            Test.startTest();
            String result = GraphQLToSOQLConverter.convert(jsonQuery);
            Test.stopTest();
            
            // VERIFY
            Assert.isTrue(result.contains('>'), 'Should contain greater than operator');
            Assert.isTrue(result.contains('<'), 'Should contain less than operator');
            Assert.isTrue(result.contains('< 2023-01-01'), 'Should handle dates without quotes');
            Assert.isTrue(result.contains('LIKE'), 'Should contain LIKE operator');
            Assert.isTrue(result.contains('IN'), 'Should contain IN operator');
            Assert.isTrue(result.contains('\'\''), 'Should handle null values');
        }
    }
    
    @IsTest
    private static void getRelatedListRecordsInvalidJsonTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            // EXERCISE
            Test.startTest();
            try {
                WireServiceCtrl.getRelatedListRecords(
                    testAccount.Id,
                    'Contacts',
                    new List<String>{'Id', 'LastName'},
                    10,
                    new List<String>{'LastName'},
                    INVALID_JSON
                );
                Assert.fail('Should have thrown an exception');
            } catch(AuraHandledException e) {
                // VERIFY
                Assert.isTrue(true, 'Should throw AuraHandledException');
            }
            Test.stopTest();
        }
    }
    
    @IsTest
    private static void testNestedFieldConditions() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            String jsonQuery = '{"and":[{"and":[{"copado__Acceptance_Criteria__c":{"notContains":"lwc"},"copado__Acceptance_Criteria_Status__c":{"contains":"Accepted" }, "copado__Story_Points_SFDC__c": { "gt": 1 }}] }]}';
            
            // EXERCISE
            Test.startTest();
            String result = GraphQLToSOQLConverter.convert(jsonQuery);
            Test.stopTest();
            
            // VERIFY
            Assert.isTrue(result.contains('(NOT copado__Acceptance_Criteria__c LIKE \'%lwc%\')'), 'Should handle nested fields');
            Assert.isTrue(result.contains('(copado__Acceptance_Criteria_Status__c LIKE \'%Accepted%\')'), 'Should handle multiple nested fields');
            Assert.isTrue(result.contains('(copado__Story_Points_SFDC__c > 1)'), 'Should handle multiple nested fields');
        }
    }
    
    @IsTest
    private static void testDateTimeFormatting() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Datetime testDt = Datetime.now();
            Date testDate = Date.today();
            String jsonQuery = '{' +
                '"CreatedDate": {"eq": "' + testDt.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"},' +
                '"LastModifiedDate": {"eq": "' + testDate.year() + '-' + 
                    String.valueOf(testDate.month()).leftPad(2, '0') + '-' + 
                    String.valueOf(testDate.day()).leftPad(2, '0') + '"}' +
            '}';
            
            // EXERCISE
            Test.startTest();
            String result = GraphQLToSOQLConverter.convert(jsonQuery);
            Test.stopTest();
            
            // VERIFY
            Assert.isTrue(result.contains(testDt.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')), 'Should format datetime correctly');
        }
    }

    @IsTest
    private static void getRecordTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            // EXERCISE
            Test.startTest();
            SObject result = WireServiceCtrl.getRecord(
                testAccount.Id,
                new List<String>{'Id', 'Name'}
            );
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(result, 'Result should not be null');
            Assert.areEqual(testAccount.Id, result.Id, 'Should return correct record');
        }
    }
    
    @IsTest
    private static void getRecordsTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            // EXERCISE
            Test.startTest();
            List<SObject> results = WireServiceCtrl.getRecords(
                new List<Id>{testAccount.Id},
                new List<String>{'Id', 'Name'}
            );
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(results, 'Results should not be null');
            Assert.areEqual(1, results.size(), 'Should return correct number of records');
        }
    }
    
    @IsTest
    private static void getObjectInfoTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            Test.startTest();
            Map<String, Object> result = WireServiceCtrl.getObjectInfo('Account');
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(result, 'Result should not be null');
            Assert.isTrue(result.containsKey('fields'), 'Should contain fields information');
            Assert.isTrue(result.containsKey('defaultRecordTypeId'), 'Should contain default record type information');
        }
    }

    @IsTest
    private static void testOrderByProcessing() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            // EXERCISE
            Test.startTest();
            List<SObject> results = WireServiceCtrl.getRelatedListRecords(
                testAccount.Id,
                'Contacts',
                new List<String>{'Id', 'LastName', 'FirstName'},
                10,
                new List<String>{'-LastName', 'FirstName'},
                null
            );
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(results, 'Results should not be null');
        }
    }
    
    @IsTest
    private static void testPagination() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Account testAccount = [SELECT Id FROM Account LIMIT 1];
            
            // EXERCISE
            Test.startTest();
            List<SObject> results1 = WireServiceCtrl.getRelatedListRecords(
                testAccount.Id,
                'Contacts',
                new List<String>{'Id', 'LastName'},
                null,
                null,
                null
            );
            
            List<SObject> results2 = WireServiceCtrl.getRelatedListRecords(
                testAccount.Id,
                'Contacts',
                new List<String>{'Id', 'LastName'},
                1000,
                null,
                null
            );
            Test.stopTest();
            
            // VERIFY
            Assert.isNotNull(results1, 'Results with null pageSize should not be null');
            Assert.isNotNull(results2, 'Results with large pageSize should not be null');
        }
    }
}