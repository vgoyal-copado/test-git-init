public with sharing class QueueCtrl {
    private static final Pattern TEMPLATE_PATTERN = Pattern.compile(
        '\\{\\$?[a-zA-Z_][a-zA-Z0-9_]*\\.[a-zA-Z_][a-zA-Z0-9_.]*(\\.[a-zA-Z_][a-zA-Z0-9_]*)?\\}'
    );

    @AuraEnabled
    public static String resolve(String expression, Id recordId) {
        System.debug('expression: ' + expression);
        System.debug('recordId: ' + recordId);
        String result = expression;
        copado.Jobs.DynamicExpressionEvaluateRequest request = new copado.Jobs.DynamicExpressionEvaluateRequest(
            recordId,
            dynamicExpressions(expression)
        );
        List<copado.Jobs.DynamicExpressionEvaluateResult> responses = copado.Jobs.DynamicExpression.evaluate(request);
        for(copado.Jobs.DynamicExpressionEvaluateResult response : responses) {
            String value = response.value == null ? '' : response.value;
            result = result.replace(response.dynamicExpression, value);
        }
        return result;
        
    }

    @AuraEnabled
    public static Integer getQueuePendingTasks(String resource) {
        List<copado.Feature.QueueResult> queueResults = copado.Feature.Queue.currentState();
        System.debug('queueResults'+queueResults);
        System.debug('resource'+resource);
        
        for (copado.Feature.QueueResult qr : queueResults) {
            System.debug('qr: '+qr);
            if (qr.resourceName == resource) {
                System.debug('found: '+qr);
                return qr.numberOfTasks;
            }
        }
        //throw new AuraHandledException('Resource not found: ' + resource);
        
        return 0;
    }

    private static List<String> dynamicExpressions(String content) {
        List<String> result = new List<String>();

        Matcher m = TEMPLATE_PATTERN.matcher(content);

        while(m.find()) {
			result.add(m.group());
        }

        return result;
    }
}