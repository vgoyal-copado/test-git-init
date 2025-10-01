public with sharing class JobStepDataDeployController {
    // PUBLIC

    @AuraEnabled(cacheable=true)
    public static Map<Id, DataTemplate> loadActiveDataTemplates() {
        try {
            return getActiveDataTemplatesByIds();
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, DataTemplate> loadDataTemplateById(List<Id> ids) {
        try {
            Map<Id, DataTemplate> dataTemplatesByIds = getDataTemplatesById(ids);
            return populateTotalRelatedObjectsAndTemplateFilter(dataTemplatesByIds);
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getFunctionParameters(String apiName) {
        try {
            List<copado__Function__c> functionDetail = new FunctionsSelector().byApiName(new Set<String>{ apiName });
            if (functionDetail.isEmpty()) {
                throw new ApplicationException(Label.Missing_Function_Error + ' ' + apiName);
            }
            return functionDetail[0].copado__Parameters__c;
        } catch (Exception ex) {
            throw new ApplicationException().auraHandled(ex);
        }
    }

    // PRIVATE

    private static Map<Id, DataTemplate> getActiveDataTemplatesByIds() {
        Map<Id, DataTemplate> result = new Map<Id, DataTemplate>();
        for (copado__Data_Template__c template : new DataTemplatesSelector().allActive()) {
            result.put(
                template.Id,
                new DataTemplate(template.Id, template.Name, null, null)
            );
        }
        return result;
    }

    private static Map<Id, DataTemplate> getDataTemplatesById(List<Id> ids) {
        Map<Id, DataTemplate> result = new Map<Id, DataTemplate>();

        for (copado__Data_Template__c template : new DataTemplatesSelector().byIdSelectedField(new Set<Id>(ids))) {
            result.put(
                template.Id,
                new DataTemplate(template.Id, template.Name, template.copado__Template_Source_Org__r.Name, template.copado__Batch_Size__c, template.copado__Continue_on_Error__c)
            );
        }
        return result;
    }

    private static Map<Id, DataTemplate> populateTotalRelatedObjectsAndTemplateFilter(Map<Id, DataTemplate> dataTemplatesByIds) {
        for (
            Attachment attachment : new AttachmentsSelector()
                .byParentIdsAndNames(dataTemplatesByIds.keySet(), new Set<String>{ DataTemplateDetail.ATTACHMENT_NAME }, dataTemplatesByIds.size())
        ) {
            if (dataTemplatesByIds.containsKey(attachment.ParentId)) {
                TemplateDetail templateDetail = (TemplateDetail) JSON.deserialize(attachment.Body?.toString(), TemplateDetail.class);
                dataTemplatesByIds.get(attachment.ParentId).totalRelatedObjects = getRelatedObjectCount(templateDetail);
                dataTemplatesByIds.get(attachment.ParentId).filterLogic = templateDetail.queryFilterList?.size() == 0
                    ? ''
                    : templateDetail.dataTemplate?.templateFilterLogic;
                dataTemplatesByIds.get(attachment.ParentId).queryFilterList = templateDetail.queryFilterList;
            }
        }

        return dataTemplatesByIds;
    }

    private static Integer getRelatedObjectCount(TemplateDetail templateDetail) {
        return templateDetail.parentObjectsReferenceList?.size() + templateDetail.childrenObjectsReferenceList?.size();
    }

    // INNER

    public class DataTemplate {
        @AuraEnabled
        public Id templateId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String sourceOrg;
        @AuraEnabled
        public Decimal batchSize;
        @AuraEnabled
        public Integer totalRelatedObjects;
        @AuraEnabled
        public List<QueryEditor.CriteriaWrapper> queryFilterList;
        @AuraEnabled
        public String filterLogic;
        @AuraEnabled
        public String continueOnError;

        @SuppressWarnings('PMD.ExcessiveParameterList')
        public DataTemplate(Id templateId, String name, String sourceOrg, Decimal batchSize, String continueOnError) {
            this.templateId = templateId;
            this.name = name;
            this.sourceOrg = sourceOrg;
            this.batchSize = batchSize;
            this.continueOnError = continueOnError;
        }

        @SuppressWarnings('PMD.ExcessiveParameterList')
        public DataTemplate(Id templateId, String name, String sourceOrg, Decimal batchSize) {
            this.templateId = templateId;
            this.name = name;
            this.sourceOrg = sourceOrg;
            this.batchSize = batchSize;
        }
    }

    private class TemplateDetail {
        public List<QueryEditor.CriteriaWrapper> queryFilterList;
        public DataTemplateDetails dataTemplate;
        public List<DataTemplateDetail.RelationTemplateDetails> parentObjectsReferenceList;
        public List<DataTemplateDetail.RelationTemplateDetails> childrenObjectsReferenceList;
    }

    private class DataTemplateDetails {
        public String templateFilterLogic;
    }
}