@SuppressWarnings('PMD.CyclomaticComplexity, PMD.CognitiveComplexity')
public with sharing class WireServiceCtrl {

    /**
     * This can be used as a imperative alternative to lightning/uiRelatedListApi/getRelatedListRecords taking this into account:
     *  - where clause renamed to whereCondition
     *  - where clause MUST BE valid JSON. All identifiers must be double quoted.
     */
    @AuraEnabled(cacheable=false)
    public static List<SObject> getRelatedListRecords(Id parentRecordId, String relatedListId, List<String> fields, Integer pageSize, List<String> sortBy, String whereCondition) //NOPMD
    {
        try {
            String query = getRelatedListRecordsSOQL(parentRecordId, relatedListId, fields, pageSize, sortBy, whereCondition);
            List<SObject> queryResults = Database.query(query); //NOPMD (It is a false positive for Apex SOQL Injection, as all clauses are being escaped)
            if (queryResults.isEmpty()) {
                return new List<SObject>();
            }

            List<SObject> relatedRecords = queryResults[0].getSObjects(relatedListId);
            return relatedRecords != null ? relatedRecords : new List<SObject>();
        } catch (System.JSONException e) {
            throw new AuraHandledException('Invalid JSON format: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<SObject> getFilteredRecords(List<Id> recordIds, String whereCondition) {
        try {
            if (recordIds == null || recordIds.isEmpty()) {
                return new List<SObject>();
            }
            SObjectType mainTable = recordIds[0].getSObjectType();
            List<SObject> result = Database.query('SELECT Id FROM ' + mainTable + ' WHERE Id IN :recordIds AND ' + GraphQLToSOQLConverter.convert(whereCondition) + ' WITH USER_MODE'); //NOPMD (It is a false positive for Apex SOQL Injection, as all clauses are being escaped)

            return result.isEmpty() ? new List<SObject>() : result;
        } catch (System.JSONException e) {
            throw new ApplicationException('Invalid JSON format: ' + e.getMessage());
        } catch (Exception e) {
            throw new ApplicationException(e.getMessage());
        }
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String getRelatedListRecordsSOQL(Id parentRecordId, String relatedListId, List<String> fields, Integer pageSize, List<String> sortBy, String whereCondition) {
        SObjectType mainTable = parentRecordId.getSObjectType();
        List<String> escapedFields = escapeStrings(fields);

        String escapedFieldsString = String.join(escapedFields, ',');
        String escapedRelatedListId = String.escapeSingleQuotes(relatedListId);

        String subquery = 'SELECT ' + escapedFieldsString + ' FROM ' + escapedRelatedListId;

        if (whereCondition != null) {
            subquery += ' WHERE ' + GraphQLToSOQLConverter.convert(whereCondition);
        }

        if (sortBy != null && sortBy.size() > 0) {
            subquery += ' ORDER BY ' + String.join(processOrderClauses(sortBy), ', ');
        }

        if (pageSize != null) {
            pageSize = Math.min(pageSize, 999);
            subquery += ' LIMIT ' + Integer.valueOf(pageSize);
        } else {
            subquery += ' LIMIT 1';
        }

        String query = 'SELECT Id, (' + subquery + ') FROM ' + mainTable + ' WHERE Id = :parentRecordId WITH USER_MODE LIMIT 1 ';

        return query;

    }

    private static List<String> escapeStrings(List<String> strings) {
        List<String> escapedStrings = new List<String>();
        for (String myString : strings) {
            escapedStrings.add(String.escapeSingleQuotes(myString));
        }
        return escapedStrings;
    }

    private static List<String> processOrderClauses(List<String> orderClauses) {
        
        List<String> escapedOrderClauses = escapeStrings(orderClauses);

        List<String> processedOrderClauses = new List<String>();
        for (String orderClause : escapedOrderClauses) {
            if (orderClause.startsWith('-')) {
                orderClause = orderClause.substring(1) + ' DESC';
            }

            processedOrderClauses.add(orderClause);
        }

        return processedOrderClauses;
    }

    @AuraEnabled(cacheable=false)
    public static SObject getRecord(Id recordId, List<String> fields) {
        try {

            SObjectType mainTable = recordId.getSObjectType();
            List<String> escapedFields = escapeStrings(fields);
            String escapedFieldsString = String.join(escapedFields, ',');

            List<SObject> results = Database.query('SELECT ' + escapedFieldsString + ' FROM ' + mainTable + ' WHERE Id = :recordId WITH USER_MODE LIMIT 1'); //NOPMD (It is a false positive for Apex SOQL Injection, as all clauses are being escaped)
            if (results.isEmpty()) {
                return null;
            }
            return results[0];

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<SObject> getRecords(List<Id> recordIds, List<String> fields) {
        try {
            if (recordIds == null || recordIds.isEmpty()) {
                return new List<SObject>();
            }

            SObjectType mainTable = recordIds[0].getSObjectType();
            List<String> escapedFields = escapeStrings(fields);
            String escapedFieldsString = String.join(escapedFields, ',');

            List<SObject> result = Database.query('SELECT ' + escapedFieldsString + ' FROM ' + mainTable + ' WHERE Id IN :recordIds WITH USER_MODE'); //NOPMD (It is a false positive for Apex SOQL Injection, as all clauses are being escaped)

            return result.isEmpty() ? new List<SObject>() : result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @todo This may need some clean up. Maybe separate logic to different methods.
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, object> getObjectInfo(String objectApiName) {

        Map<String, Object> result = new Map<String, Object>();

        // Fields
        Schema.DescribeSObjectResult describe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();

        Map<String, Schema.SObjectField> fields = describe.fields.getMap();

        Map<String, Map<String, Object>> fieldsList = new Map<String, Map<String, Object>>();

        for (String field : fields.keySet()) {

            Map<String, Object> fieldMap = new Map<String, Object>();

            Schema.DescribeFieldResult fieldDescribe = fields.get(field).getDescribe();

            fieldMap.put('apiName', fieldDescribe.getName());
            fieldMap.put('label',   fieldDescribe.getLabel());
            fieldMap.put('dataType', fieldDescribe.getType().name());
            fieldMap.put('updateable', fieldDescribe.isUpdateable());

            List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();

            List<Object> picklistValuesList = new List<Object>();

            for (Schema.PicklistEntry picklistValue : picklistValues) {

                Map<String, Object> picklistValueMap = new Map<String, Object>();

                picklistValueMap.put('label', picklistValue.getLabel());
                picklistValueMap.put('value', picklistValue.getValue());
                picklistValueMap.put('active', picklistValue.isActive());
                picklistValueMap.put('defaultValue', picklistValue.isDefaultValue());

                picklistValuesList.add(picklistValueMap);
            }

            fieldMap.put('picklistValues', picklistValuesList);

            List<Object> referenceToInfos = new List<Object>();

            List<Schema.SObjectType> referenceToDescribeList = fields.get(field).getDescribe().getReferenceTo();
            
            for (Schema.SObjectType referenceTo : referenceToDescribeList) {
                Map<String, Object> referenceToInfo = new Map<String, Object>();

                Schema.DescribeSObjectResult referenceToDescribe = referenceTo.getDescribe();

                referenceToInfo.put('apiName', referenceToDescribe.getName());

                List<String> nameFields = new List<String>();

                Map<String, Schema.SObjectField> subfieldsMap = referenceToDescribe.fields.getMap();

                for (String subfield : subfieldsMap.keySet()) {
                    Schema.DescribeFieldResult subFieldDescribe = subfieldsMap.get(subfield).getDescribe();
                    if (subFieldDescribe.isNameField()) {
                        nameFields.add(subFieldDescribe.getName());
                    }
                }

                referenceToInfo.put('nameFields', nameFields);

                // referenceToInfo.put('label', referenceTo.getDescribe().getLabel());
                referenceToInfos.add(referenceToInfo);
            }
            fieldMap.put('referenceToInfos', referenceToInfos);

            fieldsList.put(fieldDescribe.getName(), fieldMap);
        }

        result.put('fields', fieldsList);

        // Default record type id
        result.put('defaultRecordTypeId', null);

        for (Schema.RecordTypeInfo recordTypeInfo : describe.getRecordTypeInfos()) {
            if (recordTypeInfo.isDefaultRecordTypeMapping()) {
                result.put('defaultRecordTypeId', recordTypeInfo.getRecordTypeId());
            }
        }

        return result;
    }

    @AuraEnabled(cacheable=false)
    public static String getGraphQLToSOQL(String whereCondition) {
        String soql = GraphQLToSOQLConverter.convert(whereCondition);
        return soql;
    }
    
}