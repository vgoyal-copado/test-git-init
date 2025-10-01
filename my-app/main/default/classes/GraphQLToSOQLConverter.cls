@SuppressWarnings('PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.AvoidDeeplyNestedIfStmts')
public with sharing class GraphQLToSOQLConverter {
    
    private static final Set<String> VALID_OPERATORS = new Set<String>{
        'eq', 'ne', 'gt', 'lt', 'ge', 'le', 'like', 'in', 'contains', 'notContains'
    };
    
    public static String convert(String filterJson) {
        if (String.isBlank(filterJson)) {
            return '';
        }
        
        try {
            Map<String, Object> filterMap = (Map<String, Object>)JSON.deserializeUntyped(filterJson);
            return processFilter(filterMap, 0);
        } catch (Exception e) {
            throw new GraphQLToSOQLException('Error converting filter: ' + e.getMessage());
        }
    }
    
    private static String processFilter(Map<String, Object> filterMap, Integer indentLevel) {
        if (filterMap == null || filterMap.isEmpty()) {
            return '';
        }
        
        try {
            if (filterMap.containsKey('and')) {
                return processLogicalOperator(filterMap, 'and', indentLevel);
            } else if (filterMap.containsKey('or')) {
                return processLogicalOperator(filterMap, 'or', indentLevel);
            } else {
                return processDirectConditions(filterMap);
            }
        } catch (Exception e) {
            throw new GraphQLToSOQLException('Error processing filter: ' + e.getMessage());
        }
    }
    
    private static String processLogicalOperator(Map<String, Object> filterMap, String operator, Integer indentLevel) {
        List<Object> conditions = (List<Object>)filterMap.get(operator);
        List<String> processedConditions = new List<String>();
        
        for (Object condition : conditions) {
            if (condition instanceof Map<String, Object>) {
                Map<String, Object> conditionMap = (Map<String, Object>)condition;
                String processedCondition = processFilter(conditionMap, indentLevel + 1);
                
                if (String.isNotBlank(processedCondition)) {
                    processedCondition = ensureParentheses(processedCondition);
                    processedConditions.add(processedCondition);
                }
            }
        }
        
        if (processedConditions.isEmpty()) {
            return '';
        }
        
        String joinOperator = operator.equalsIgnoreCase('and') ? ' AND ' : ' OR ';
        return processedConditions.size() == 1 ? 
               processedConditions[0] : 
               '(' + String.join(processedConditions, joinOperator) + ')';
    }

    private static String processDirectConditions(Map<String, Object> filterMap) {
        List<String> conditions = new List<String>();
        
        for (String field : filterMap.keySet()) {
            if (!field.equalsIgnoreCase('and') && !field.equalsIgnoreCase('or')) {
                Object value = filterMap.get(field);
                if (value instanceof Map<String, Object>) {
                    if (field.endsWith('__r')) {
                        String relationshipCondition = processRelationshipField(field, (Map<String, Object>)value);
                        if (String.isNotBlank(relationshipCondition)) {
                            conditions.add(ensureParentheses(relationshipCondition));
                        }
                    } else {
                        String condition = buildCondition(field, (Map<String, Object>)value);
                        if (String.isNotBlank(condition)) {
                            conditions.add(ensureParentheses(condition));
                        }
                    }
                }
            }
        }
        
        return String.join(conditions, ' AND ');
    }

    private static String processRelationshipField(String relationshipField, Map<String, Object> relationshipMap) {
        List<String> relationshipConditions = new List<String>();
        
        for (String field : relationshipMap.keySet()) {
            Object value = relationshipMap.get(field);
            if (value instanceof Map<String, Object>) {
                if (field.endsWith('__r')) {
                    String nestedCondition = processRelationshipField(field, (Map<String, Object>)value);
                    if (String.isNotBlank(nestedCondition)) {
                        relationshipConditions.add(nestedCondition);
                    }
                } else {
                    String fullFieldPath = relationshipField + '.' + field;
                    String condition = buildCondition(fullFieldPath, (Map<String, Object>)value);
                    if (String.isNotBlank(condition)) {
                        relationshipConditions.add(condition);
                    }
                }
            }
        }
        
        return String.join(relationshipConditions, ' AND ');
    }

    private static String ensureParentheses(String condition) {
        condition = condition.trim();
        if (!condition.startsWith('(') || !condition.endsWith(')')) {
            return '(' + condition + ')';
        }
        return condition;
    }
    
    private static String buildCondition(String fieldPath, Map<String, Object> operatorMap) {
        if (operatorMap == null || operatorMap.isEmpty()) {
            return '';
        }
        
        for (String operator : operatorMap.keySet()) {
            Object value = operatorMap.get(operator);
            
            switch on operator.toLowerCase() {
                when 'eq' {
                    return buildEqualsCondition(fieldPath, value);
                }
                when 'ne' {
                    return buildNotEqualsCondition(fieldPath, value);
                }
                when 'gt' {
                    return fieldPath + ' > ' + formatValue(value);
                }
                when 'lt' {
                    return fieldPath + ' < ' + formatValue(value);
                }
                when 'ge' {
                    return fieldPath + ' >= ' + formatValue(value);
                }
                when 'le' {
                    return fieldPath + ' <= ' + formatValue(value);
                }
                when 'like' {
                    return fieldPath + ' LIKE ' + formatValue(value);
                }
                when 'in' {
                    return buildInCondition(fieldPath, value);
                }
                when 'notcontains' {
                    return buildNotContainsCondition(fieldPath, value);
                }
                when 'contains' {
                    return buildContainsCondition(fieldPath, value);
                }
            }
        }
        return '';
    }

    private static String buildEqualsCondition(String fieldPath, Object value) {
        if (value == null || (value instanceof String && ((String)value).toLowerCase() == 'null')) {
            return fieldPath + ' = \'\'';
        }
        return fieldPath + ' = ' + formatValue(value);
    }
    
    private static String buildNotEqualsCondition(String fieldPath, Object value) {
        if (value == null || (value instanceof String && ((String)value).toLowerCase() == 'null')) {
            return fieldPath + ' != \'\'';
        }
        return fieldPath + ' != ' + formatValue(value);
    }
    
    private static String buildNotContainsCondition(String fieldPath, Object value) {
        String formattedValue = formatValue(value);
        return 'NOT ' + fieldPath + ' LIKE \'%' + String.escapeSingleQuotes(formattedValue.removeStart('\'').removeEnd('\'')) + '%\'';
    }
    
    private static String buildContainsCondition(String fieldPath, Object value) {
        String formattedValue = formatValue(value);
        return fieldPath + ' LIKE \'%' + String.escapeSingleQuotes(formattedValue.removeStart('\'').removeEnd('\'')) + '%\'';
    }
    
    private static String buildInCondition(String fieldPath, Object value) {
        if (!(value instanceof List<Object>)) {
            throw new GraphQLToSOQLException('IN operator requires a list of values');
        }
        
        List<Object> values = (List<Object>)value;
        List<String> formattedValues = new List<String>();
        
        for (Object item : values) {
            formattedValues.add(formatValue(item));
        }
        
        return fieldPath + ' IN (' + String.join(formattedValues, ', ') + ')';
    }
    
    private static String formatValue(Object value) {
        if (value == null) {
            return null;
        }

        if (value instanceof Boolean || value instanceof Integer || 
            value instanceof Long || value instanceof Decimal) {

            return String.valueOf(value);
        }

        if (value instanceof Date) {

            return formatDate((Date)value);
        }

        if (value instanceof Datetime) {
            return formatDatetime((Datetime)value);
        }

        if (value instanceof String) {
            String strValue = (String)value;

            if (strValue.toLowerCase() == 'null') {
                return '';
            }

            Pattern datetimePattern = Pattern.compile('^\\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\\d|3[01])T(?:[01]\\d|2[0-3]):[0-5]\\d:[0-5]\\d(?:\\.\\d+)?Z$');
            if (datetimePattern.matcher(strValue).matches()) {
                Datetime dt = (Datetime)JSON.deserialize('"' + strValue + '"', Datetime.class);
                return formatDatetime(dt);
            }

            Pattern datePattern = Pattern.compile('^\\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\\d|3[01])$');
            if (datePattern.matcher(strValue).matches()) {
                Date d = Date.valueOf(strValue);
                return formatDate(d);
            }
            return '\'' + String.escapeSingleQuotes((String)value) + '\'';
        }

        return String.valueOf(value);
    }
    
    private static String formatDate(Date dateValue) {
        return dateValue.year() + '-' + 
               String.valueOf(dateValue.month()).leftPad(2, '0') + '-' + 
               String.valueOf(dateValue.day()).leftPad(2, '0');
    }
    
    private static String formatDatetime(Datetime datetimeValue) {
        return datetimeValue.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
    
    public class GraphQLToSOQLException extends Exception {}
}