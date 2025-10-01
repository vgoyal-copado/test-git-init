public with sharing class RefreshDependencyWrapper {
    
        @AuraEnabled
        public Id credentialId { get; set; }
        @AuraEnabled
        public Id userStoryId { get; set; }
        @AuraEnabled
        public Id pipelineId { get; set; }
        @AuraEnabled
        public String refreshMode { get; set; }
        @AuraEnabled
        public List<UserStoryMetaCache.Metadata> selectedMetadata { get; set; }
}