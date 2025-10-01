public with sharing class CredentialListView {
    @TestVisible
    private static String mockResponse;
    private final static String SOBJECT_API_PATH = '/services/data/v60.0/sobjects/';

    // PUBLIC

    @AuraEnabled(cacheable=true)
    public static List<ListView> getSobjectListviews(String sobjectType) {
        try {
            return new ListViewSelector().bySobject(sobjectType);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Response getListViewRecords(String listViewId) {
        try {
            Response result = new Response();
            copado.GlobalAPI.ProxyOrgRequest request = new copado.GlobalAPI.ProxyOrgRequest();

            request.endPointUrlService = SOBJECT_API_PATH + 'copado__Org__c/listviews/' + listViewId + '/describe';
            request.orgCredentialId = getCredential().Id;
            request.logLabelIdentifier = Label.Credential_List_View_Fetching;
            request.requestType = HttpMethod.GET.name();

            copado.GlobalAPI.ProxyOrgResponse proxyResponse = !Test.isRunningTest()
                ? new copado.GlobalAPI().proxyOrgRequest(request)
                : TestUtilities.getMockedResponse(mockResponse);

            ListViewDescribeResponse listViewDescribeResponse = processResponse(proxyResponse, request.logLabelIdentifier);
            result.data = Database.query(listViewDescribeResponse.query);
            result.columns = listViewDescribeResponse.columns;
            return result;
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    // PRIVATE

    private static ListViewDescribeResponse processResponse(copado.GlobalAPI.ProxyOrgResponse response, String logLabelIdentifier) {
        if (response.statusCode == 200) {
            return (ListViewDescribeResponse) JSON.deserialize(response.content, ListViewDescribeResponse.class);
        } else {
            String message = String.isNotBlank(response.errorMessage) ? response.errorMessage : Label.Error + ': ' + logLabelIdentifier;
            throw new ApplicationException(message);
        }
    }

    private static copado__Org__c getCredential() {
        List<copado__Org__c> result = new CredentialsSelector()
            .bySFDCOrgId(new Set<String>{ UserInfo.getOrganizationId() + '_' + UserInfo.getUserId() });
        if (result.isEmpty()) {
            throw new ApplicationException(Label.Credential_Not_Found);
        }

        validateOrg(result[0].Id);
        return result[0];
    }

    private static void validateOrg(String orgId) {
        copado.ValidateOrgAction.Request request = new copado.ValidateOrgAction.Request();
        request.orgId = orgId;

        List<copado.ValidateOrgAction.Result> result = copado.ValidateOrgAction.execute(new List<copado.ValidateOrgAction.Request>{ request });
        Boolean isValid = !result.isEmpty() ? result.get(0).isValidOrg : false;

        if (!isValid) {
            throw new ApplicationException(Label.Org_Is_Not_Valid);
        }
    }

    @TestVisible
    private class ListViewDescribeResponse {
        public List<Column> columns;
        public String query;
    }

    public class Response {
        @AuraEnabled
        public List<Column> columns;
        @AuraEnabled
        public List<SObject> data;
    }
    public class Column {
        @AuraEnabled
        public String ascendingLabel;
        @AuraEnabled
        public String descendingLabel;
        @AuraEnabled
        public String fieldNameOrPath;
        @AuraEnabled
        public Boolean hidden;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Boolean searchable;
        @AuraEnabled
        public String selectListItem;
        @AuraEnabled
        public String sortDirection;
        @AuraEnabled
        public Boolean sortable;
        @AuraEnabled
        public String type;
    }
}