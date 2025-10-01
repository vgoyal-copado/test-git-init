public with sharing class PollApexJob implements Schedulable {
    private Id jobId;
    private Integer delayInSeconds;
    private Integer timeoutInMinutes;
    private Datetime startTime;
    private SchedulerCallback callback;

    public PollApexJob(Request request) {
        this.jobId = request.jobId;
        this.delayInSeconds = request.delayInSeconds;
        this.timeoutInMinutes = request.timeoutInMinutes;
        this.callback = request.callback;
        this.startTime = Datetime.now();
    }

    public void execute(SchedulableContext sc) {
        try {
            AsyncApexJob job = getJob(this.jobId);

            if (job.Status == 'Completed') {
                System.debug('Job completed successfully');
                System.abortJob(sc.getTriggerId());
                callback.execute();
            } else if (job.Status == 'Failed' || job.Status == 'Aborted') {
                System.debug('Job failed or aborted. Extended Status: ' + job.ExtendedStatus);
                System.abortJob(sc.getTriggerId());
            } else if (this.startTime.addMinutes(timeoutInMinutes) < Datetime.now()) {
                System.abortJob(sc.getTriggerId());
                System.debug('Polling stopped after reaching maximum timeout limit');
                return;
            } else {
                // Schedule next poll in delay seconds
                System.debug('Schedule next poll');
                scheduleNextPoll();
            }
        } catch (Exception e) {
            System.debug('Error polling job status: ' + e.getMessage());
        }
    }

    public String nextCron() {
        Datetime nextRun = Datetime.now().addSeconds(this.delayInSeconds);
        return nextRun.second() +
            ' ' +
            nextRun.minute() +
            ' ' +
            nextRun.hour() +
            ' ' +
            nextRun.day() +
            ' ' +
            nextRun.month() +
            ' ? ' +
            nextRun.year();
    }

    private void scheduleNextPoll() {
        String cronExp = nextCron();
        System.schedule('PollApexJob ' + System.now().getTime(), cronExp, this);
    }

    private AsyncApexJob getJob(Id jobId) {
        return [SELECT Id, Status, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE Id = :jobId];
    }

    public class Request {
        public Id jobId;
        public Integer delayInSeconds;
        public Integer timeoutInMinutes;
        public SchedulerCallback callback;
    }
}