@IsTest
private with sharing class SourceMemberTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            makeData();
        }
    }

    @IsTest
    private static void testGetItemsFromSourceMember() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            SourceMember.mockResponse = getProxyOrgResponse(200, getSourceMemberItemsResponse(), '', '');
            Id orgCredentialId = getOrgCredentialId('Scratch Org');
            String memberName = 'Test';
            String memberType = '';
            String changedDateTimeFilter = '2024-01-01T09:58:00.000Z';
            String changedBy = 'User';
            String isNameObsolete = 'false';

            // EXERCISE

            List<SourceMemberResult> response = SourceMember.getItems(
                orgCredentialId,
                memberName,
                memberType,
                changedDateTimeFilter,
                changedBy,
                isNameObsolete
            );

            // VERIFY

            Assert.areEqual(8, response.size(), 'The number of source member items is incorrect');
            
            // Check EntitlementProcess is not taking into consideration because it is an "Invalid Type".
            Assert.areNotEqual('EntitlementProcess', response.get(0).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areNotEqual('standard', response.get(0).MemberName, 'The MemberName of source member item is incorrect');
            
            Assert.areEqual('testprofile', response.get(0).MemberName, 'The MemberName of source member item is incorrect');
            Assert.areEqual('Profile', response.get(0).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual(
                'Test__c-Testテスáćト日本語áć%21%40%23%24%25%5E%26*%28%29_%2B-%3D%7B%7D%5B%5D%7C%3A%3B%3C%3E%2C.%3F%2F',
                response.get(1).MemberName,
                'The MemberName of source member item is incorrect'
            );
            Assert.areEqual('Layout', response.get(1).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual('TestFolder1/Folder2', response.get(2).MemberName, 'The MemberName of source member item is incorrect');
            Assert.areEqual('EmailFolder', response.get(2).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual('TestFolder1', response.get(3).MemberName, 'The MemberName of source member item is incorrect');
            Assert.areEqual('EmailFolder', response.get(3).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual(
                'site/testDigitalExpBundle.site/content',
                response.get(4).MemberName,
                'The MemberType of source member item is incorrect'
            );
            Assert.areEqual('DigitalExperience', response.get(4).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual('site/testDigitalExpBundle', response.get(5).MemberName, 'The MemberType of source member item is incorrect');
            Assert.areEqual('DigitalExperienceBundle', response.get(5).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual('testdocumentfolder', response.get(6).MemberName, 'The MemberType of source member item is incorrect');
            Assert.areEqual('DocumentFolder', response.get(6).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual('testdocumentfolder/mydoc', response.get(7).MemberName, 'The MemberType of source member item is incorrect');
            Assert.areEqual('Document', response.get(7).MemberType, 'The MemberType of source member item is incorrect');
        }
    }

    @IsTest
    private static void testGetDeletedItemsFromSourceMemberWithoutFilters() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            SourceMember.mockResponse = getProxyOrgResponse(200, getDeletedSourceMemberItemsResponse(), '', '');
            Id orgCredentialId = getOrgCredentialId('Scratch Org');

            // EXERCISE

            List<SourceMemberResult> response = SourceMember.getItems(orgCredentialId, null, null, null, null, 'true');

            // VERIFY

            Assert.areEqual(4, response.size(), 'The number of source member items is incorrect');
            Assert.areEqual('testpage', response.get(0).MemberName, 'The MemberName of source member item is incorrect');
            Assert.areEqual('ApexPage', response.get(0).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual(
                'Test__c-Testテスáćト日本語áć%21%40%23%24%25%5E%26*%28%29_%2B-%3D%7B%7D%5B%5D%7C%3A%3B%3C%3E%2C.%3F%2F',
                response.get(1).MemberName,
                'The MemberName of source member item is incorrect'
            );
            Assert.areEqual('Layout', response.get(1).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual('TestFolder1/Folder2', response.get(2).MemberName, 'The MemberName of source member item is incorrect');
            Assert.areEqual('EmailFolder', response.get(2).MemberType, 'The MemberType of source member item is incorrect');
            Assert.areEqual('TestFolder1', response.get(3).MemberName, 'The MemberName of source member item is incorrect');
            Assert.areEqual('EmailFolder', response.get(3).MemberType, 'The MemberType of source member item is incorrect');
        }
    }

    @IsTest
    private static void testGetDeletedItemsFromSourceMemberWithFilters() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            SourceMember.mockResponse = getProxyOrgResponse(200, getDeletedSourceMemberItemsResponseWithFilters(), '', '');
            Id orgCredentialId = getOrgCredentialId('Scratch Org');
            String memberName = 'Test';
            String memberType = 'ApexPage';
            String changedDateTimeFilter = '';
            String changedBy = 'User';
            String isNameObsolete = 'true';

            // EXERCISE

            List<SourceMemberResult> response = SourceMember.getItems(
                orgCredentialId,
                memberName,
                memberType,
                changedDateTimeFilter,
                changedBy,
                isNameObsolete
            );

            // VERIFY

            Assert.areEqual(1, response.size(), 'The number of source member items is incorrect');
            Assert.areEqual('testpage', response.get(0).MemberName, 'The MemberName of source member item is incorrect');
            Assert.areEqual('ApexPage', response.get(0).MemberType, 'The MemberType of source member item is incorrect');
        }
    }

    private static String getSourceMemberItemsResponse() {
        SourceMember.SourceMemberQueryResult result = new SourceMember.SourceMemberQueryResult();
        result.records = new List<SourceMemberResult>();
        result.records.add(new SourceMemberResult('standard', 'EntitlementProcess', false));
        result.records.add(new SourceMemberResult('testprofile', 'Profile', false));
        result.records.add(new SourceMemberResult('Test__c-Testテスáćト日本語áć!@#$%^&*()_+-={}[]|:;<>,.?/', 'Layout', false));
        result.records.add(new SourceMemberResult('TestFolder1/Folder2', 'EmailTemplateFolder', false));
        result.records.add(new SourceMemberResult('TestFolder1', 'EmailTemplateFolder', false));
        result.records.add(new SourceMemberResult('MyTestEmailTemplate', 'EmailTemplate', false));
        result.records.add(new SourceMemberResult('site/testDigitalExpBundle.site/content', 'DigitalExperience', false));
        result.records.add(new SourceMemberResult('site/testDigitalExpBundle', 'DigitalExperienceBundle', false));
        result.records.add(new SourceMemberResult('testdocumentfolder', 'DocumentFolder', false));
        result.records.add(new SourceMemberResult('testdocumentfolder/mydoc', 'Document', false));

        return JSON.serialize(result);
    }

    private static String getDeletedSourceMemberItemsResponse() {
        SourceMember.SourceMemberQueryResult result = new SourceMember.SourceMemberQueryResult();
        result.records = new List<SourceMemberResult>();
        result.records.add(new SourceMemberResult('testpage', 'ApexPage', true));
        result.records.add(new SourceMemberResult('Test__c-Testテスáćト日本語áć!@#$%^&*()_+-={}[]|:;<>,.?/', 'Layout', true));
        result.records.add(new SourceMemberResult('TestFolder1/Folder2', 'EmailTemplateFolder', true));
        result.records.add(new SourceMemberResult('TestFolder1', 'EmailTemplateFolder', true));
        return JSON.serialize(result);
    }

    private static String getDeletedSourceMemberItemsResponseWithFilters() {
        SourceMember.SourceMemberQueryResult result = new SourceMember.SourceMemberQueryResult();
        result.records = new List<SourceMemberResult>();
        result.records.add(new SourceMemberResult('testpage', 'ApexPage', true));
        return JSON.serialize(result);
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String getProxyOrgResponse(Integer statusCode, String content, String errorCode, String errorMessage) {
        return JSON.serialize(new ProxyOrgResponse(statusCode, content, errorCode, errorMessage));
    }

    private static void makeData() {
        new Credential().type('Scratch Org').type('Scratch Org')?.persist();
        new Credential().type('Production/Developer').type('Production/Developer')?.persist();
    }

    private static Id getOrgCredentialId(String type) {
        return [SELECT Id, copado__Org_Type__c FROM copado__Org__c WHERE copado__Org_Type__c = :type LIMIT 1].Id;
    }
}