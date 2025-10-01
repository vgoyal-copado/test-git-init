@SuppressWarnings('PMD.EmptyCatchBlock')
public with sharing class EscapeUtil {
    @InvocableMethod(
        label='Escape message on result'
        description='This method will escape the HTML tags in error message.'
        category='Evaluate Apex tests criteria'
    )
    public static List<String> execute(List<String> data) {
        List<String> results = new List<String>();
        try {
            for (String message : data) {
                results.add(message.trim().escapeHtml4().replaceAll('\n', ' '));
            }
        } catch (Exception ex) {
            //ignoring the exception here.
        }
        return results;
    }
}