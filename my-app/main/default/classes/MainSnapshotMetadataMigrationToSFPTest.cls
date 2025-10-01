@IsTest
private class MainSnapshotMetadataMigrationToSFPTest {

    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
    }

    @IsTest
    private static void testExecuteMethod() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            String mockContextId = fflib_IDGenerator.generate('a07');
            
            // EXERCISE
            String result = new MainSnapshotMetadataForMigrationToSFP().execute(mockContextId);
            
            // VERIFY
            Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
            Assert.isTrue(resultMap.containsKey('SFDX'), 'Result should contain SFDX key');
            Map<String, Object> sfdxScope = (Map<String, Object>)resultMap.get('SFDX');
            Assert.isTrue(sfdxScope.containsKey('included'), 'SFDX scope should contain included list');
            Assert.isTrue(sfdxScope.containsKey('excluded'), 'SFDX scope should contain excluded list');
            List<Object> includedList = (List<Object>)sfdxScope.get('included');
            Assert.isTrue(includedList.size() > 0, 'Included list should not be empty');
            Boolean hasApexTrigger = false;
            Boolean hasLightningComponentBundle = false;
            for (Object item : includedList) {
                String metadataType = (String)item;
                if (metadataType == 'ApexTrigger') {
                    hasApexTrigger = true;
                }
                if (metadataType == 'LightningComponentBundle') {
                    hasLightningComponentBundle = true;
                }
            }
            Assert.isTrue(hasApexTrigger, 'Included list should contain ApexTrigger');
            Assert.isTrue(hasLightningComponentBundle, 'Included list should contain LightningComponentBundle');
            List<Object> excludedList = (List<Object>)sfdxScope.get('excluded');
            Assert.areEqual(0, excludedList.size(), 'Excluded list should be empty');
        }
    }
}