public with sharing class FieldSetController {
    @AuraEnabled(cacheable=true)
    public static List<FieldSetMemberWrapper> getFieldSetDetails(String objectName, String fieldSetName) {
        try {
            List<FieldSetMemberWrapper> wrapperList = new List<FieldSetMemberWrapper>();

            // Get the field set
            Schema.FieldSet fieldSet = Schema.getGlobalDescribe().get(objectName).getDescribe().fieldSets.getMap().get(fieldSetName);

            if (fieldSet == null) {
                throw new AuraHandledException('Field Set not found: ' + fieldSetName);
            }

            // Convert field set members to wrapper objects
            for (Schema.FieldSetMember fsm : fieldSet.getFields()) {
                wrapperList.add(
                    new FieldSetMemberWrapper(
                        fsm.getLabel(),
                        fsm.getFieldPath(),
                        String.valueOf(fsm.getType()),
                        fsm.getRequired(),
                        fsm.getType() == Schema.DisplayType.REFERENCE ? String.valueOf(fsm.getSObjectField().getDescribe().getReferenceTo()[0]) : null
                    )
                );
            }

            return wrapperList;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting field set details: ' + e.getMessage());
        }
    }

    // Wrapper class to serialize field set member information
    public class FieldSetMemberWrapper {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String apiName { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public Boolean required { get; set; }
        @AuraEnabled
        public String reference { get; set; }

        public FieldSetMemberWrapper(String label, String apiName, String type, Boolean required, String reference) {
            this.label = label;
            this.apiName = apiName;
            this.type = type;
            this.required = required;
            this.reference = reference;
        }
    }
}