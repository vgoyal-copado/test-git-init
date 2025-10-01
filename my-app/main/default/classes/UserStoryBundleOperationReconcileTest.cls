@IsTest
public with sharing class UserStoryBundleOperationReconcileTest {
    private static final String ADD = 'Add';
    private static final String FULL = 'Full';
    private static final String RETRIEVE_ONLY = 'RetrieveOnly';
    private static final String SELECTIVE_COMMIT = 'SelectiveCommit';
    private static final String DELETE_OPERATION = 'Delete';
    private static final String SFDX = 'SFDX';

    @TestSetup
    static void makeData() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void reconcileAddTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleClass1').type('ApexClass').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('SampleClass1').type('ApexClass').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('SampleTrigger').type('ApexTrigger').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleTrigger').type('ApexTrigger').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('Sample Raptor').type('DataRaptor').action(RETRIEVE_ONLY).category('Vlocity').userStory(userStories[1]);

            Pipeline pipeline = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipeline, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();
            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY
            Assert.areEqual(5, UserStoryBundleOperationReconciliation.reconciledTestChanges.size(), 'There should be 5 committed changes');
            assertReconciledOperations(ADD);
        }
    }

    @IsTest
    private static void reconcileDeleteTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(DELETE_OPERATION).category('SFDX').userStory(userStories[1]);

            Pipeline pipeline = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipeline, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();
            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY
            Assert.areEqual(2, UserStoryBundleOperationReconciliation.reconciledTestChanges.size(), 'There should be 3 committed changes');
            for (MetaDataItem change : UserStoryBundleOperationReconciliation.reconciledTestChanges) {
                switch on change.n {
                    when 'SampleClass' {
                        Assert.isTrue(change.a == ADD, 'Reconciled operation should be ' + ADD);
                    }
                    when 'SampleFlexiPage' {
                        Assert.isTrue(change.a == DELETE_OPERATION, 'Reconciled operation should be ' + DELETE_OPERATION);
                    }
                }
            }
        }
    }

    @IsTest
    private static void reconcileFullTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(FULL).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('SampleApexPage').type('ApexPage').action(FULL).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleApexPage').type('ApexPage').action(ADD).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(FULL).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[1]);

            Pipeline pipeline = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipeline, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();
            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY
            Assert.areEqual(3, UserStoryBundleOperationReconciliation.reconciledTestChanges.size(), 'There should be 3 committed changes');
            assertReconciledOperations(FULL);
        }
    }

    @IsTest
    private static void reconcileSelectiveCommitTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[1]);
             new UserStoryMetadata_t().name('SampleTrigger').type('ApexTrigger').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleTrigger').type('ApexTrigger').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[1]);
            Pipeline pipelineObj = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipelineObj, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();

            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY
            Assert.areEqual(2, UserStoryBundleOperationReconciliation.reconciledTestChanges.size(), 'There should be 2 committed change');
            assertReconciledOperations(SELECTIVE_COMMIT);
        }
    }

    @IsTest
    private static void reconcileSelectiveCommitForLayoutTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t()
                .name('Account-Test Layout')
                .type('Layout')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0])
                .jsonInfo('{"selectiveCommitFileId":"fileid","selectiveCommitHash":"fileNameHash"}');
            new UserStoryMetadata_t()
                .name('ApexclassTest')
                .type('ApexClass')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0])
                .jsonInfo('{"selectiveCommitFileId":"fileid1","selectiveCommitHash":"apexClassHash"}');
            new UserStoryMetadata_t()
                .name('SampleTrigger')
                .type('ApexTrigger')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0])
                .jsonInfo('{"selectiveCommitFileId":"fileid2","selectiveCommitHash":"apexTriggerHash"}');
            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0]);
            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action(RETRIEVE_ONLY)
                .category('SFDX')
                .userStory(userStories[1]);
            new UserStoryMetadata_t().name('Account-Test Layout').type('Layout').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('ApexclassTest').type('ApexClass').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('SampleTrigger').type('ApexTrigger').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[1]);
            Pipeline pipelineObj = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipelineObj, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();

            createBundledUserStories(version.Id);
            createFile(
                UserStoryBundleOperationReconciliation.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT,
                userStories[0].Id,
                '{"LightningComponentBundle:testLWC":["force-app/main/default/lwc/testLWC/testLWC.html"]}'
            );

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            List<MetaDataItem> reconciledTestChanges = UserStoryBundleOperationReconciliation.reconciledTestChanges;
            // VERIFY
            Assert.areEqual(4, reconciledTestChanges.size(), 'There should be 4 committed change');
            Assert.areEqual(
                'Account-Test Layout',
                reconciledTestChanges[0].n,
                'The name of the reconciled metadata should be Account-Test Layout' + reconciledTestChanges[0].n
            );
            Assert.areEqual(
                'Layout',
                reconciledTestChanges[0].t,
                'The type of the reconciled metadata should be layout' + reconciledTestChanges[0].t
            );
            Assert.areEqual(
                '{"selectiveCommitFileId":"fileid","selectiveCommitHash":"fileNameHash"}',
                reconciledTestChanges[0].j,
                'The jsonAdditonal info is incorrect of the reconciled metadata'
            );

            Assert.areEqual(
                'ApexclassTest',
                reconciledTestChanges[1].n,
                'The name of the reconciled metadata should be ' + reconciledTestChanges[1].n
            );
            Assert.areEqual(
                'ApexClass',
                reconciledTestChanges[1].t,
                'The type of the reconciled metadata should be Apex Class' + reconciledTestChanges[0].t
            );
            Assert.areEqual(
                '{"selectiveCommitFileId":"fileid1","selectiveCommitHash":"apexClassHash"}',
                reconciledTestChanges[1].j,
                'The jsonAdditonal info is incorrect of the reconciled metadata'
            );

            Assert.areEqual(
                'SampleTrigger',
                reconciledTestChanges[2].n,
                'The name of the reconciled metadata should be' + reconciledTestChanges[2].n
            );
            Assert.areEqual(
                'ApexTrigger',
                reconciledTestChanges[2].t,
                'The type of the reconciled metadata should be layout' + reconciledTestChanges[2].t
            );
            Assert.areEqual(
                '{"selectiveCommitFileId":"fileid2","selectiveCommitHash":"apexTriggerHash"}',
                reconciledTestChanges[2].j,
                'The jsonAdditonal info is incorrect of the reconciled metadata'
            );

            List<ContentVersion> file = new ContentVersionsSelector()
                .byFirstPublishLocationIdAndTitleAndIsLatest(
                    new Set<Id>{ bundledUS.Id },
                    new List<String>{ UserStoryBundleOperationReconciliation.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION }
                );
            Assert.areEqual(
                1,
                UserStoryBundleOperationReconciliation.bundledSelectiveCommitSelectionsOnUserStories.size(),
                'There should be 1 bundled metadata for Selective Commit'
            );
            Assert.areEqual(1, file.size(), 'For operation Selective Commit for Bundled Metadata, Selected File should be created on bundled US.');
            Map<String, Set<String>> jsonResponse = (Map<String, Set<String>>) JSON.deserialize(
                file[0]?.VersionData?.toString(),
                Map<String, Set<String>>.class
            );
            Assert.areEqual(1, jsonResponse.size(), 'In Selections file, file paths for selected file within bundled metadata should be present.');
            Assert.areEqual(
                new Set<String>{ 'force-app/main/default/lwc/testLWC/testLWC.html' },
                jsonResponse.get('LightningComponentBundle:testLWC'),
                'Correct file path for Bundled metadata should be present.'
            );
        }
    }

    @IsTest
    private static void getDataForReconcileModalTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStoryBundleOperationReconciliation.Response> responses = new List<UserStoryBundleOperationReconciliation.Response>();
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SamplePage').type('ApexPage').action(DELETE_OPERATION).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(FULL).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('SamplePage').type('ApexPage').action(ADD).category('SFDX').userStory(userStories[1]);
            Pipeline pipelineObj = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipelineObj, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();

            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            responses = UserStoryBundleOperationReconciliation.execute(getPackageVersion().Id);

            Test.stopTest();

            // VERIFY
            Assert.areEqual(4, responses.size(), 'There should be 4 committed changes');
            for (UserStoryBundleOperationReconciliation.Response response : responses) {
                switch on response.metadata.n {
                    when 'SampleClass' {
                        Assert.areEqual('Full', response.lockedOperation, 'The locked operation for SampleClass should be Full');
                    }
                    when 'SamplePage' {
                        Assert.isNull(response.lockedOperation, 'The locked operation for SamplePage should be null');
                    }
                }
            }
        }
    }

    @IsTest
    private static void reconcileBundledSelectiveCommitTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0]);
            new UserStoryMetadata_t()
                .name('testAuraBundle')
                .type('AuraDefinitionBundle')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0]);
            new UserStoryMetadata_t()
                .name('testWaveTemplateBundle')
                .type('WaveTemplateBundle')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0]);
            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[1]);
            new UserStoryMetadata_t()
                .name('testAuraBundle')
                .type('AuraDefinitionBundle')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[1]);

            createFile(
                UserStoryBundleOperationReconciliation.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT,
                userStories[0].Id,
                getSelectionsData('US 1')
            );
            createFile(
                UserStoryBundleOperationReconciliation.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT,
                userStories[1].Id,
                getSelectionsData('US 2')
            );

            Pipeline pipeline = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipeline, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();
            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY
            List<ContentVersion> file = new ContentVersionsSelector()
                .byFirstPublishLocationIdAndTitleAndIsLatest(
                    new Set<Id>{ bundledUS.Id },
                    new List<String>{ UserStoryBundleOperationReconciliation.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION }
                );
            Assert.areEqual(
                5,
                UserStoryBundleOperationReconciliation.bundledSelectiveCommitSelectionsOnUserStories.size(),
                'There should be 5 changes for Bundled Selective Commit'
            );
            Assert.areEqual(1, file.size(), 'For operation Selective Commit for Bundled Metadata, Selected File should be created on bundled US.');
            assertSelectionsForBundledMetadataContent(file[0]?.VersionData?.toString());
            assertReconciledOperations(SELECTIVE_COMMIT);
        }
    }

    @IsTest
    private static void reconcileBundledSelectiveCommitWithAddTest() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t()
                .name('testLWC')
                .type('LightningComponentBundle')
                .action(SELECTIVE_COMMIT)
                .category('SFDX')
                .userStory(userStories[0]);
            new UserStoryMetadata_t().name('testLWC').type('LightningComponentBundle').action(ADD).category('SFDX').userStory(userStories[1]);

            createFile(
                UserStoryBundleOperationReconciliation.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_COMMIT,
                userStories[0].Id,
                '{"LightningComponentBundle:testLWC":["force-app/main/default/lwc/testLWC/testLWC.css"]}'
            );

            Pipeline pipeline = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipeline, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();
            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.run(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY
            Assert.areEqual(
                1,
                UserStoryBundleOperationReconciliation.bundledSelectiveCommitSelectionsOnUserStories.size(),
                'There should be 1 Selective Commit change'
            );
            List<ContentVersion> file = new ContentVersionsSelector()
                .byFirstPublishLocationIdAndTitleAndIsLatest(
                    new Set<Id>{ bundledUS.Id },
                    new List<String>{ UserStoryBundleOperationReconciliation.CMCSF_SELECTIONS_FOR_BUNDLED_METADATA_SESSION }
                );
            Assert.areEqual(
                0,
                file.size(),
                'Reconciled operation for Bundled metadata should be add, hence no selections file should be created on bundled US.'
            );
            List<MetaDataItem> reconciledTestChanges = UserStoryBundleOperationReconciliation.reconciledTestChanges;
            Assert.areEqual(1, reconciledTestChanges.size(), 'There should be 1 committed change');
            Assert.areEqual(
                'LightningComponentBundle',
                reconciledTestChanges[0].t,
                'The type of the reconciled metadata should be Lightning Component Bundle instead of ' + reconciledTestChanges[0].t
            );
            Assert.areEqual(
                'testLWC',
                reconciledTestChanges[0].n,
                'The name of the reconciled metadata should be testLWC instead of' + reconciledTestChanges[0].n
            );
            assertReconciledOperations(ADD);
        }
    }

    @IsTest
    private static void executeReconcileWhenTestsExistOnUS() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            ExtensionConfiguration extensionConfiguration = new ExtensionConfiguration()
                .extensionTool(TestUtilities.getExtensionTool())
                .phase('Test')
                .activate();

            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('Sample Raptor').type('DataRaptor').action(RETRIEVE_ONLY).category('Vlocity').userStory(userStories[1]);

            Pipeline pipeline = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            ArtifactVersion version = createPackageVersion(createPackage(pipeline, 'User_Story_Bundle'), '53.0', bundledUS);
            new Test_t().extensionConfiguration(extensionConfiguration).userStory(new UserStory().recordId(bundledUS.Id)).persist();

            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.execute(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY

            Assert.isNull(
                UserStoryBundleOperationReconciliation.reconciledTestChanges,
                'Reconciled changes should not be populated since the reconciliation logic is not triggered'
            );
        }
    }

    @IsTest
    private static void executeReconcileWhenNoTestsExistOnAnyUS() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            List<UserStory> userStories = getUserStoryObjects(new List<String>{ 'US 1', 'US 2' });

            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleClass').type('ApexClass').action(RETRIEVE_ONLY).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(ADD).category('SFDX').userStory(userStories[0]);
            new UserStoryMetadata_t().name('SampleFlexiPage').type('FlexiPage').action(SELECTIVE_COMMIT).category('SFDX').userStory(userStories[1]);
            new UserStoryMetadata_t().name('Sample Raptor').type('DataRaptor').action(RETRIEVE_ONLY).category('Vlocity').userStory(userStories[1]);

            Pipeline pipeline = getPipelineObj('My Pipeline');
            copado__User_Story__c bundledUS = getUserStories(new List<String>{ 'Bundled US' })[0];
            copado__Artifact_Version__c version = (copado__Artifact_Version__c) createPackageVersion(
                    createPackage(pipeline, 'User_Story_Bundle'),
                    '53.0',
                    bundledUS
                )
                .persist();
            createBundledUserStories(version.Id);

            // EXERCISE
            Test.startTest();

            UserStoryBundleOperationReconciliation.Request request = new UserStoryBundleOperationReconciliation.Request();
            request.packageVersionId = getPackageVersion().Id;
            request.bundleUserStory = bundledUS;
            UserStoryBundleOperationReconciliation.execute(new List<UserStoryBundleOperationReconciliation.Request>{ request });

            Test.stopTest();

            // VERIFY
            Assert.areEqual(3, UserStoryBundleOperationReconciliation.reconciledTestChanges.size(), 'There should be 3 committed changes');
            assertReconciledOperations(ADD);
        }
    }

    private static String getSelectionsData(String userStoryName) {
        switch on userStoryName {
            when 'US 1' {
                return '{"LightningComponentBundle:testLWC":["force-app/main/default/lwc/testLWC/testLWC.html","force-app/main/default/lwc/testLWC/testLWC.css"],"AuraDefinitionBundle:testAuraBundle":["force-app/main/default/aura/testAuraBundle/testAuraBundle.cmp","force-app/main/default/aura/testAuraBundle/testAuraBundle.design"],"WaveTemplateBundle:testWaveTemplateBundle":["force-app/main/default/waveTemplates/testWaveTemplateBundle/template-info.json"]}';
            }
            when 'US 2' {
                return '{"LightningComponentBundle:testLWC":["force-app/main/default/lwc/testLWC/testLWC.js-meta.xml","force-app/main/default/lwc/testLWC/testLWC.css"],"AuraDefinitionBundle:testAuraBundle":["force-app/main/default/aura/testAuraBundle/testAuraBundle.js"]}';
            }
            when else {
                return '';
            }
        }
    }

    private static void assertSelectionsForBundledMetadataContent(String data) {
        Map<String, Set<String>> jsonResponse = (Map<String, Set<String>>) JSON.deserialize(data, Map<String, Set<String>>.class);
        Assert.areEqual(3, jsonResponse.size(), '3 different Metadata Items should be present in Selections File for Bundled Selective Commit');
        Assert.areEqual(
            new Set<String>{
                'force-app/main/default/lwc/testLWC/testLWC.js-meta.xml',
                'force-app/main/default/lwc/testLWC/testLWC.html',
                'force-app/main/default/lwc/testLWC/testLWC.css'
            },
            jsonResponse.get('LightningComponentBundle:testLWC'),
            'Lightning Component Bundle should have 3 selected files in total.'
        );
        Assert.areEqual(
            new Set<String>{
                'force-app/main/default/aura/testAuraBundle/testAuraBundle.cmp',
                'force-app/main/default/aura/testAuraBundle/testAuraBundle.js',
                'force-app/main/default/aura/testAuraBundle/testAuraBundle.design'
            },
            jsonResponse.get('AuraDefinitionBundle:testAuraBundle'),
            'Aura Definition Bundle should have 3 selected files in total.'
        );
        Assert.areEqual(
            new Set<String>{ 'force-app/main/default/waveTemplates/testWaveTemplateBundle/template-info.json' },
            jsonResponse.get('WaveTemplateBundle:testWaveTemplateBundle'),
            'Wave Template Bundle should have 1 selected file in total.'
        );
    }

    private static void assertReconciledOperations(String reconciledOperation) {
        for (MetaDataItem change : UserStoryBundleOperationReconciliation.reconciledTestChanges) {
            switch on change.n {
                when 'SampleClass' {
                    Assert.isTrue(change.a == reconciledOperation, 'Reconciled operation should be ' + reconciledOperation);
                }
                when 'SampleApexPage' {
                    Assert.isTrue(change.a == reconciledOperation, 'Reconciled operation should be ' + reconciledOperation);
                }
                when 'SampleFlexiPage' {
                    Assert.isTrue(change.a == reconciledOperation, 'Reconciled operation should be ' + reconciledOperation);
                }
                when 'testLWC' {
                    Assert.isTrue(change.a == reconciledOperation, 'Reconciled operation should be ' + reconciledOperation);
                }
                when 'testAuraBundle' {
                    Assert.isTrue(change.a == reconciledOperation, 'Reconciled operation should be ' + reconciledOperation);
                }
                when 'testWaveTemplateBundle' {
                    Assert.isTrue(change.a == reconciledOperation, 'Reconciled operation should be ' + reconciledOperation);
                }
            }
        }
    }

    private static void createData() {
        TestUtilities.createRepository().persist();
        Project project = new Project().name('My Project');
        new Pipeline().name('My Pipeline').platform('SFDX').add(project).repository(TestUtilities.getRepositoryObj());

        new UserStory().title('US 1').status('Draft').credential(createCredential(false)).project(project).persist();
        new UserStory().title('US 2').status('Draft').credential(createCredential(false)).persist();
        new UserStory().title('Bundled US').status('Draft').credential(createCredential(false)).recordType('Utility').persist();
    }

    private static Artifact createPackage(Pipeline pipeline, String recordType) {
        return new Artifact(TestUtilities.getRepositoryObj())
            .name('Test Package')
            .pipeline(pipeline)
            .type('Unlocked')
            .recordTypeId(recordType)
            .targetDevHub(createCredential(true))
            .apiVersion('53.0')
            .sourceApiVersion('1.0')
            .noNamespace(false);
    }

    private static void createBundledUserStories(Id versionId) {
        List<copado__Bundled_Story__c> bundledStories = new List<copado__Bundled_Story__c>();
        for (copado__User_Story__c userStory : [
            SELECT Id
            FROM copado__User_Story__c
        ]) {
            bundledStories.add(new copado__Bundled_Story__c(copado__User_Story__c = userStory.Id, copado__Package_Version__c = versionId));
        }
        insert bundledStories;
    }

    private static ArtifactVersion createPackageVersion(Artifact pkg, String apiVersion, copado__User_Story__c bundledUS) {
        return new ArtifactVersion(pkg)
            .name('ver 0.1')
            .versionNumber('0.1.0.1')
            .userStory(new UserStory().recordId(bundledUS.Id))
            .versionId(fflib_IDGenerator.generate(copado__Artifact_Version__c.SObjectType));
    }

    private static copado__Artifact_Version__c getPackageVersion() {
        return [SELECT Id, copado__Subscriber_Version_Id__c FROM copado__Artifact_Version__c LIMIT 1];
    }

    private static List<copado__User_Story__c> getUserStories(List<String> titles) {
        return [SELECT Id, Name FROM copado__User_Story__c WHERE copado__User_Story_Title__c IN :titles];
    }

    private static Credential createCredential(Boolean isDevHub) {
        return new Credential().devhub(isDevHub).type('Production/Developer');
    }

    private static Id getPipelineId(String name) {
        return [SELECT Id FROM copado__Deployment_Flow__c WHERE Name = :name LIMIT 1].Id;
    }

    private static Pipeline getPipelineObj(String name) {
        return new Pipeline().recordId(getPipelineId(name));
    }

    private static List<UserStory> getUserStoryObjects(List<String> titles) {
        List<UserStory> userStoryObjects = new List<UserStory>();
        for (copado__User_Story__c userStory : getUserStories(titles)) {
            userStoryObjects.add(new UserStory().recordId(userStory.Id));
        }
        return userStoryObjects;
    }

    private static Id createFile(String title, Id recordId, String body) {
        ContentVersion fileVersion = (ContentVersion) new ContentVersion_t()
            .firstPublishLocationId(recordId)
            .title(title)
            .pathOnClient(title)
            .versionData(Blob.valueOf(body))
            .persist();
        return fileVersion.ContentDocumentId;
    }
}