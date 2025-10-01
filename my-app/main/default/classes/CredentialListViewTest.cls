@IsTest
private class CredentialListViewTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
    }

    @IsTest
    private static void getListViewOfCredentailsSuccessfully() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            TestUtilities.createCredential(false);
            TestUtilities.createCredential(false).persist();

            // EXERCISE

            Test.startTest();
            List<ListView> listViews = CredentialListView.getSobjectListviews('copado__Org__c');
            Test.stopTest();

            // VERIFY

            Assert.isTrue(hasListView(listViews, 'All'), 'Credentials List View should have list view named All');
        }
    }

    @IsTest
    private static void getListViewRecordsSuccessfully() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            TestUtilities.createCredential(false)
                .name('Test')
                .sfdcOrgId(UserInfo.getOrganizationId() + '_' + UserInfo.getUserId())
                .oauthSignature('signature')
                .validatedDate(System.now())
                .persist();

            CredentialListView.ListViewDescribeResponse response = new CredentialListView.ListViewDescribeResponse();
            response.columns = getColumns();
            response.query = 'SELECT Name, CreatedBy.Name, Id, CreatedDate, LastModifiedDate, SystemModstamp, CreatedBy.Id, CreatedById FROM copado__Org__c ORDER BY Id ASC NULLS FIRST';

            CredentialListView.mockResponse = new ProxyOrgResponse(200, JSON.serialize(response), null, null).getResponse();

            // EXERCISE

            Test.startTest();
            CredentialListView.Response result = CredentialListView.getListViewRecords('All');
            Test.stopTest();

            // VERIFY

            Assert.areEqual(1, result.columns.size(), 'The number of columns returned is not 1');
            List<CredentialListView.Column> expectedColumnsList = getColumns();

            Assert.areEqual(
                expectedColumnsList.get(0).ascendingLabel,
                result.columns.get(0).ascendingLabel,
                'The ascending label of column returned is incorrect'
            );
            Assert.areEqual(
                expectedColumnsList.get(0).descendingLabel,
                result.columns.get(0).descendingLabel,
                'The descending Label of column returned is incorrect'
            );
            Assert.areEqual(expectedColumnsList.get(0).hidden, result.columns.get(0).hidden, 'The hidden field of column returned is incorrect');
            Assert.areEqual(expectedColumnsList.get(0).label, result.columns.get(0).label, 'The label of column returned is incorrect');
            Assert.areEqual(
                expectedColumnsList.get(0).searchable,
                result.columns.get(0).searchable,
                'The searchable of column returned is incorrect'
            );
            Assert.areEqual(
                expectedColumnsList.get(0).selectListItem,
                result.columns.get(0).selectListItem,
                'The selectListItem of column returned is incorrect'
            );
            Assert.areEqual(
                expectedColumnsList.get(0).sortDirection,
                result.columns.get(0).sortDirection,
                'The sortDirection of column returned is incorrect'
            );
            Assert.areEqual(expectedColumnsList.get(0).sortable, result.columns.get(0).sortable, 'The sortable of column returned is incorrect');
            Assert.areEqual(expectedColumnsList.get(0).type, result.columns.get(0).type, 'The type of column returned is incorrect');
            Assert.isTrue(hasCredential(result.data, 'Test'), 'The returned list does not have the created credential Test');
        }
    }

    @IsTest
    private static void throwErrorOnGetingListViewRecords() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            TestUtilities.createCredential(false).persist();
            List<ListView> listViews = CredentialListView.getSobjectListviews('copado__Org__c');
            String listViewId = listViews[0].Id;

            CredentialListView.mockResponse = new ProxyOrgResponse(200, '', '', null).getResponse();
            String exceptionMessage = '';

            // EXERCISE
            try {
                Test.startTest();
                CredentialListView.getListViewRecords(listViewId);
                Test.stopTest();
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }

            // VERIFY
            Assert.areEqual(Label.Credential_Not_Found, exceptionMessage, 'Exception of non validated credential.');
        }
    }

    @IsTest
    private static void throwErrorOnHttpCalloutToGetListViewRecords() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            String errorMessage = 'Test Error Message';
            TestUtilities.createCredential(false)
                .sfdcOrgId(UserInfo.getOrganizationId() + '_' + UserInfo.getUserId())
                .oauthSignature('signature')
                .validatedDate(System.now())
                .persist();
            List<ListView> listViews = CredentialListView.getSobjectListviews('copado__Org__c');
            String listViewId = listViews[0].Id;

            CredentialListView.mockResponse = new ProxyOrgResponse(500, '', '', errorMessage).getResponse();
            String exceptionMessage = '';

            // EXERCISE
            try {
                Test.startTest();
                CredentialListView.getListViewRecords(listViewId);
                Test.stopTest();
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }

            // VERIFY
            Assert.areEqual(errorMessage, exceptionMessage, 'Exception from HTTP callout to get list view.');
        }
    }

    @IsTest
    private static void throwErrorOnLoggedInNonValidatedCredential() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP

            TestUtilities.createCredential(false).sfdcOrgId(UserInfo.getOrganizationId() + '_' + UserInfo.getUserId()).persist();
            List<ListView> listViews = CredentialListView.getSobjectListviews('copado__Org__c');
            String listViewId = listViews[0].Id;
            String exceptionMessage = '';

            // EXERCISE
            try {
                Test.startTest();
                CredentialListView.getListViewRecords(listViewId);
                Test.stopTest();
            } catch (Exception ex) {
                exceptionMessage = ex.getMessage();
            }

            // VERIFY
            Assert.areEqual(Label.Org_Is_Not_Valid, exceptionMessage, 'Logged In Org should have validated credential.');
        }
    }

    private static boolean hasCredential(List<copado__Org__c> credentials, String credName) {
        Boolean result = false;
        for (copado__Org__c cred : credentials) {
            if (cred.Name == credName) {
                result = true;
                break;
            }
        }
        return result;
    }

    private static boolean hasListView(List<ListView> listViews, String name) {
        Boolean result = false;
        for (ListView view : listViews) {
            if (view.DeveloperName == name) {
                result = true;
                break;
            }
        }
        return result;
    }

    private static List<CredentialListView.Column> getColumns() {
        CredentialListView.Column column = new CredentialListView.Column();
        column.ascendingLabel = 'Z-A';
        column.descendingLabel = 'A-Z';
        column.fieldNameOrPath = 'Name';
        column.hidden = false;
        column.label = 'Credential Name';
        column.searchable = true;
        column.selectListItem = 'Name';
        column.sortable = true;
        column.type = 'String';
        return new List<CredentialListView.Column>{ column };
    }
}