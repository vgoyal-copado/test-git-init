@IsTest
private class RollbackPermissionValidatorTest {
    
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';

    @TestSetup
    private static void setup() {
        TestUtilities.setup();
        System.runAs(TestUtilities.getRunAsUser()) {
            createData();
        }
    }

    @IsTest
    private static void testPermissionForSandbox() {
        System.runAs(TestUtilities.getRunAsUser()) {
        
            //SETUP
            Boolean result;
        
            // EXERCISE
            Test.startTest();
            result = RollbackPermissionValidator.execute(getEnvironment('sandbox').Id, getPipeline().Id);
            Test.stopTest();

            // VERIFY
            Assert.isTrue(result, 'Should allow rollback for non-production environment');
        }
    }

    @IsTest
    private static void testPermissionForProdWithCopadoAdmin() {
        System.runAs(TestUtilities.getRunAsUser()) {
            // SETUP
            Boolean result;

            // EXERCISE
            Test.startTest();
            result = RollbackPermissionValidator.execute(getEnvironment('prod').Id, getPipeline().Id);
            Test.stopTest();

            // VERIFY
            Assert.isTrue(result, 'Should allow rollback for production environment with Copado Admin');
        }
    }

    @IsTest
    private static void testPermissionForNonProdOrg() {
        User userWithNoLicense = TestUtilities.createAdminUser(ADMIN_USERNAME);
        System.runAs(userWithNoLicense) {
            // SETUP
            Boolean result;

            // EXERCISE
            Test.startTest();
            result = RollbackPermissionValidator.execute(getEnvironment('uat').Id, getPipeline().Id);
            Test.stopTest();

            // VERIFY
            Assert.isTrue(result, 'Should allow rollback for non-prod environments.');
        }
    }

    @IsTest
    private static void testPermissionForProdWithNoCopadoAdmin() {
        User userWithNoLicense = TestUtilities.createAdminUser(ADMIN_USERNAME);
        System.runAs(userWithNoLicense) {
        // SETUP
            Boolean result;

            // EXERCISE
            Test.startTest();
            result = RollbackPermissionValidator.execute(getEnvironment('prod').Id, getPipeline().Id);
            Test.stopTest();

            // VERIFY
            Assert.isFalse(result, 'Should not allow rollback for production environment without Copado Admin');
        }
    }

    private static void createData() {
        Environment devEnvironment = new Environment().type('Production/Developer').name('dev');
        Environment dev1Environment = new Environment().type('Production/Developer').name('dev1');
        Environment uatEnvironment = new Environment().type('Production/Developer').name('uat');
        Environment prodEnvironment = new Environment().type('Production/Developer').name('prod');
        Environment sandboxEnvironment = new Environment().type('Sandbox').name('sandbox');

        
        new Pipeline(new Repository().name('Test Repo'))
            .platform('SFDX')
            .add(new PipelineConnection().sourceEnvironment(dev1Environment).destinationEnvironment(sandboxEnvironment).branch('sandbox'))
            .add(new PipelineConnection().sourceEnvironment(devEnvironment).destinationEnvironment(uatEnvironment).branch('uat'))
            .add(new PipelineConnection().sourceEnvironment(uatEnvironment).destinationEnvironment(prodEnvironment).branch('prod'))
            .persist();
    }

    private static copado__Deployment_Flow__c getPipeline() {
        return [SELECT Id FROM copado__Deployment_Flow__c LIMIT 1];
    }

    private static copado__Environment__c getEnvironment(String name) {
        return [SELECT Id FROM copado__Environment__c WHERE Name =: name];
    }
}