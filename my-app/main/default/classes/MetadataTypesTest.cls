@IsTest
private class MetadataTypesTest {
    @TestSetup
    private static void setUp() {
        TestUtilities.setup();
    }

    @IsTest
    private static void testSupportedMetadataTypes() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE

            List<String> supportedMetadataTypes = MetadataTypes.supportedMetadataTypes();

            // VERIFY
            Assert.areNotEqual(null, supportedMetadataTypes, 'The list should not be null.');
            Assert.areEqual(supportedMetadataTypes, getSortedList(supportedMetadataTypes), 'The list should be sorted.');
        }
    }

    @IsTest
    private static void testSupportedMetadataTypesInPartialRefresh() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            List<String> supportedTypesInPartialRefresh = MetadataTypes.supportedMetadataTypesInPartialRefresh();

            // VERIFY

            Assert.areNotEqual(null, supportedTypesInPartialRefresh, 'The list should not be null.');
            Assert.areEqual(supportedTypesInPartialRefresh, getSortedList(supportedTypesInPartialRefresh), 'The list should be sorted.');
            // Ensure that unsupported types are not included
            for (String type : MetadataTypes.METADATA_TYPES_NOT_SUPPORTED_IN_PARTIAL_REFRESH) {
                Assert.isTrue(!supportedTypesInPartialRefresh.contains(type), 'Unsupported types should not be included.');
            }
        }
    }

    @IsTest
    private static void testMetadataTypesNotSupportedInCommitPageFilters() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            List<String> unsupportedTypes = MetadataTypes.metadataTypesNotSupportedInCommitPageFilters();

            // VERIFY
            Assert.areNotEqual(null, unsupportedTypes, 'The list should not be null.');
            Assert.isTrue(unsupportedTypes.contains('EmailTemplateFolder'), 'EmailTemplateFolder should be in the unsupported list.');
        }
    }

    @IsTest
    private static void testMetadataTypesSupportedInGitSnapshot() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // EXERCISE
            List<String> supportedTypesInGitSnapshot = MetadataTypes.metadataTypesSupportedInGitSnapshot();

            // VERIFY
            Assert.areNotEqual(null, supportedTypesInGitSnapshot, 'The list should not be null.');
            Assert.areEqual(supportedTypesInGitSnapshot, getSortedList(supportedTypesInGitSnapshot), 'The list should be sorted.');
            // Ensure that unsupported types are not included
            for (String type : MetadataTypes.METADATA_TYPES_NOT_SUPPORTED_IN_GIT_SNAPSHOT) {
                Assert.isTrue(!supportedTypesInGitSnapshot.contains(type), 'Unsupported types should not be included.');
            }
        }
    }

    private static List<String> getSortedList(List<String> metadataList) {
        List<String> result = new List<String>(metadataList);
        result.sort();
        return result;
    }
}