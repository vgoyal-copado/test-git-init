public with sharing class CMMetadata {
    @AuraEnabled
    public String name { get; set; }

    @AuraEnabled
    public String type { get; set; }

    public CMMetadata(String name, String type) {
        this.name = name;
        this.type = type;
    }
}