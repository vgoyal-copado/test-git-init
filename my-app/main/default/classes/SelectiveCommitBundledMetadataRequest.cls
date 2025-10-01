public with sharing class SelectiveCommitBundledMetadataRequest {
    @AuraEnabled
    public Id userStoryId { get; set; }
    @AuraEnabled
    public String filePrefix { get; set; }
    @AuraEnabled
    public String filePathHash { get; set; }
}