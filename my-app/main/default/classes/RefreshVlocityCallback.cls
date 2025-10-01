@SuppressWarnings('PMD.AvoidGlobalModifier')
global class RefreshVlocityCallback implements copado.MCCallBack {
    global static void execute(copado__Function__c function, copado__Result__c result, String status) {
        /*
            We no longer need this callback class since with US-0159221,
            we will remove the dependency on any fired copado event to know the status of the function execution.
            We shall rather poll the status of the function result record to get the right status
        */
    }
}