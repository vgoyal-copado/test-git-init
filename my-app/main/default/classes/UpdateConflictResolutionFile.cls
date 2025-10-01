public with sharing class UpdateConflictResolutionFile {
    private static final String CONFLICT_RESOLUTION_FILE_NAME = 'GitConflictsResolution.json';

    // PUBLIC
    public static void execute(Id resultId, Id promotionId) {
        Map<Id, List<ContentDocumentLink>> fileLinksByLinkedEntityId = getFileLinksByLinkedEntityId(new Set<Id>{ resultId, promotionId });
        updateFilesOnPromotion(fileLinksByLinkedEntityId, promotionId, resultId);
        updateAttachmentOnPromotion(fileLinksByLinkedEntityId, promotionId, resultId);
    }

    // PRIVATE
    private static List<ContentDocumentLink> getFileLinks(Set<Id> entityIds) {
        return (new ContentDocumentLinksSelector().byLinkedEntityIdAndTitles(entityIds, new Set<String>{ CONFLICT_RESOLUTION_FILE_NAME }));
    }

    private static void updateFilesOnPromotion(Map<Id, List<ContentDocumentLink>> fileLinksByLinkedEntityId, Id promotionId, Id resultId) {
        List<ContentDocumentLink> filesOnPromotion = fileLinksByLinkedEntityId.containsKey(promotionId)
            ? fileLinksByLinkedEntityId.get(promotionId)
            : new List<ContentDocumentLink>();
        List<ContentDocumentLink> filesOnResult = fileLinksByLinkedEntityId.containsKey(resultId)
            ? fileLinksByLinkedEntityId.get(resultId)
            : new List<ContentDocumentLink>();

        new Utilities.DeleteSObjectWithoutSharing().execute(filesOnPromotion);

        if (!filesOnResult.isEmpty()) {
            createContentDocumentLink(getDocumentIds(filesOnResult), promotionId);
        }
    }

    private static void updateAttachmentOnPromotion(Map<Id, List<ContentDocumentLink>> fileLinksByLinkedEntityId, Id promotionId, Id resultId) {
        List<ContentDocumentLink> filesOnResult = fileLinksByLinkedEntityId.containsKey(resultId)
            ? fileLinksByLinkedEntityId.get(resultId)
            : new List<ContentDocumentLink>();

        deleteAttachments(promotionId);

        if (!filesOnResult.isEmpty()) {
            Attachment att = new Attachment(
                Name = CONFLICT_RESOLUTION_FILE_NAME,
                ParentId = promotionId,
                Body = filesOnResult[0].ContentDocument.LatestPublishedVersion.VersionData
            );
            Utilities.performDML(new List<Attachment>{ att }, 'insert', AccessLevel.USER_MODE);
        }
    }

    private static void deleteAttachments(Id promotionId) {
        List<Attachment> attachmentsOnPromotion = new AttachmentsSelector()
            .byParentIdsAndNames(new Set<Id>{ promotionId }, new Set<String>{ CONFLICT_RESOLUTION_FILE_NAME }, 1000);

        new Utilities.DeleteSObjectWithoutSharing().execute(attachmentsOnPromotion);
    }

    private static Map<Id, List<ContentDocumentLink>> getFileLinksByLinkedEntityId(Set<Id> entityIds) {
        Map<Id, List<ContentDocumentLink>> result = new Map<Id, List<ContentDocumentLink>>();
        List<ContentDocumentLink> files = new ContentDocumentLinksSelector()
            .versionDataByLinkedEntityIdsAndTitles(entityIds, new Set<String>{ CONFLICT_RESOLUTION_FILE_NAME });
        for (ContentDocumentLink file : files) {
            if (!result.containsKey(file.LinkedEntityId)) {
                result.put(file.LinkedEntityId, new List<ContentDocumentLink>{ file });
            } else {
                result.get(file.LinkedEntityId).add(file);
            }
        }
        return result;
    }

    private static void createContentDocumentLink(Set<Id> documentIds, Id promotionId) {
        List<ContentDocumentLink> fileLinks = new List<ContentDocumentLink>();
        for (Id documentId : documentIds) {
            fileLinks.add(new ContentDocumentLink(ContentDocumentId = documentId, LinkedEntityId = promotionId, ShareType = 'V'));
        }
        Utilities.performDML(fileLinks, 'insert', AccessLevel.USER_MODE);
    }

    private static Set<Id> getDocumentIds(List<ContentDocumentLink> contentDocumentLinks) {
        Set<Id> result = new Set<Id>();
        for (ContentDocumentLink documentLink : contentDocumentLinks) {
            result.add(documentLink.ContentDocumentId);
        }
        return result;
    }
}