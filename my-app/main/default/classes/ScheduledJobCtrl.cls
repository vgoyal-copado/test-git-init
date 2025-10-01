public with sharing class ScheduledJobCtrl {
    @AuraEnabled(cacheable=true)
    public static String getNextFireTime(String scheduledJobId) {
        try {
            if (String.isBlank(scheduledJobId)) {
                return null;
            }

            CronTrigger cronTrigger = [
                SELECT Id, NextFireTime, State, CronExpression
                FROM CronTrigger
                WHERE Id = :scheduledJobId
                WITH USER_MODE
                LIMIT 1
            ];

            if (cronTrigger != null && cronTrigger.NextFireTime != null) {
                return cronTrigger.NextFireTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            }

            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving scheduled job details: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getBatchNextFireTimes(List<String> scheduledJobIds) {
        try {
            if (scheduledJobIds == null || scheduledJobIds.isEmpty()) {
                return new Map<String, String>();
            }

            Map<String, String> resultMap = new Map<String, String>();

            for (CronTrigger cronTrigger : [
                SELECT Id, NextFireTime, State, CronExpression
                FROM CronTrigger
                WHERE Id IN :scheduledJobIds
                WITH USER_MODE
            ]) {
                if (cronTrigger.NextFireTime != null) {
                    resultMap.put(String.valueOf(cronTrigger.Id).substring(0, 15), cronTrigger.NextFireTime.format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
                }
            }

            return resultMap;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving scheduled jobs details: ' + e.getMessage());
        }
    }
}