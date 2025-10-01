@IsTest
private class EscapeUtilTest {
    @IsTest
    private static void escapeHtmlTagsTest() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<String> data = new List<String>{
                'less than < 90',
                'greater than > 900',
                'failing methods > 0',
                '"<Black&White>"',
                'single quote\' here',
                'No HTML tag in error description',
                'No new line here\n',
                'Concatenated sentences\nConcatenated sentences'
            };
            List<String> result = new List<String>();

            // EXERCISE
            result = EscapeUtil.execute(data);

            // VERIFY
            Assert.areEqual('less than &lt; 90', result[0], 'The less than operator should be escaped');
            Assert.areEqual('greater than &gt; 900', result[1], 'The greater than operator should be escaped');
            Assert.areEqual('failing methods &gt; 0', result[2], 'The less than operator should be escaped');
            Assert.areEqual('&quot;&lt;Black&amp;White&gt;&quot;', result[3], 'All the HTML characters should be escaped');
            Assert.areEqual('single quote&#39; here', result[4], 'All the HTML characters should be escaped');
            Assert.areEqual('No HTML tag in error description', result[5], 'No escaping in this description');
            Assert.areEqual('No new line here', result[6], 'There is a escape character at the end of the string');
			Assert.areEqual('Concatenated sentences Concatenated sentences', result[7], 'There is a escape character between the concatenated sentences');
        }
    }
}