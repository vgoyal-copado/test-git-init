public with sharing class DeleteSalesforceFiles {

    // PUBLIC 
    public static Map<String, ContentDocument> deleteOutdatedContentDocumentsAndReturnLatest(Set<String> titles, Id recordId) {
        List<ContentDocument> contentDocumentsToBeDeleted = new List<ContentDocument>();
        Map<String, ContentDocument> latestFilesByTitle = new Map<String, ContentDocument>();
        // This will give us the content document links of selective commit files attached on the user story in descending order of their created date
        for (
            ContentDocumentLink contentDocumentLink : new ContentDocumentLinksSelector().contentDocumentByLinkedEntityIdAndTitle(new Set<Id>{ recordId }, titles)
        ) {
            if (latestFilesByTitle.containsKey(contentDocumentLink.ContentDocument?.Title)) {
                contentDocumentsToBeDeleted.add(new ContentDocument(Id = contentDocumentLink.ContentDocumentId));
            } else {
                /*
                    The very first time we find a selective commit file, we don't add it to the result variable (we just skip it)
                    as it contains the latest metadata details.
                */
                latestFilesByTitle.put(contentDocumentLink.ContentDocument?.Title, contentDocumentLink.ContentDocument);
            }
        }

        deleteFiles(contentDocumentsToBeDeleted);
        return latestFilesByTitle;
    }

    @AuraEnabled
    public static void deleteContentDocuments(List<Id> linkedEntityIds, List<String> titles) {
        List<ContentDocument> contentDocumentsToBeDeleted = new List<ContentDocument>();

        for (
            ContentDocumentLink link : new ContentDocumentLinksSelector()
                .contentDocumentByLinkedEntityIdAndTitle(new Set<Id>(linkedEntityIds), new Set<String>(titles))
        ) {
            contentDocumentsToBeDeleted.add(new ContentDocument(Id = link.ContentDocumentId));
        }

        deleteFiles(contentDocumentsToBeDeleted);
    }

    public static void deleteFiles(List<SObject> files) {
        // We are running this logic in SYSTEM_MODE, because we need the
        // file links to be deleted irrespective of the permissions of the logged in user.
        new Utilities.DeleteSObjectWithoutSharing().execute(files);
    }
}