@IsTest
private class OverviewOrganizeYourTeamControllerTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
    }

    @IsTest
    static void testGetPersonas() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            copado__Persona_Definition__c standardPersona = new copado__Persona_Definition__c(
                Name = 'Developer', copado__Is_Standard__c = true
            );
            copado__Persona_Definition__c customPersonaQaTester = new copado__Persona_Definition__c(
                Name = 'QA Tester', copado__Is_Standard__c = false
            );
            copado__Persona_Definition__c customPersonaQaManager = new copado__Persona_Definition__c(
                Name = 'QA Manager', copado__Is_Standard__c = false
            );
            insert new List<copado__Persona_Definition__c>{ standardPersona, customPersonaQaTester, customPersonaQaManager };
    
            User developerUser1 = TestUtilities.createUser( false );
            developerUser1.copado__Persona_Id__c = standardPersona.Id;
            developerUser1.Username = TestUtilities.generateRandomString( 10 ) + '@fakedomain.copado';
    
            User developerUser2 = TestUtilities.createUser( false );
            developerUser2.copado__Persona_Id__c = standardPersona.Id;
            developerUser2.Username = TestUtilities.generateRandomString( 10 ) + '@fakedomain.copado';
    
            User customUserQaTester = TestUtilities.createUser( false );
            customUserQaTester.copado__Persona_Id__c = customPersonaQaTester.Id;
            customUserQaTester.Username = TestUtilities.generateRandomString( 10 ) + '@fakedomain.copado';
    
            User customUserQaManager = TestUtilities.createUser( false );
            customUserQaManager.copado__Persona_Id__c = customPersonaQaManager.Id;
            customUserQaManager.Username = TestUtilities.generateRandomString( 10 ) + '@fakedomain.copado';
    
            insert new List<User>{ developerUser1, developerUser2, customUserQaTester, customUserQaManager };

            Test.startTest();
            List<PersonaController.PersonaDefinition> result = OverviewOrganizeYourTeamController.getPersonas();
            Test.stopTest();

            Assert.areNotEqual(null, result, 'Result should not be null');
            Assert.areEqual(2, result.size(), 'Should return correct number of personas (1 standard + 1 merged custom)');

            PersonaController.PersonaDefinition standardPersonaResult = result[0];
            Assert.isTrue(standardPersonaResult.isStandard, 'First persona should be standard');

            PersonaController.PersonaDefinition mergedCustomPersona = result[1];
            Assert.areEqual(false, mergedCustomPersona.isStandard, 'Merged persona should not be standard');
            Assert.areEqual(System.Label.AssignedToCustomPersonas, mergedCustomPersona.persona.Name, 'Merged persona should have correct name');
            Assert.areEqual(2, mergedCustomPersona.numberOfUsers, 'Merged persona should have combined number of users');
        }
    }
    
    @IsTest
    static void testMergeCustomPersonas() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            List<PersonaController.PersonaDefinition> mockPersonas = createMockPersonaDefinitions();
            
            Test.startTest();
            List<PersonaController.PersonaDefinition> result = OverviewOrganizeYourTeamController.mergeCustomPersonas(mockPersonas);
            Test.stopTest();

            Assert.areEqual(2, result.size(), 'Should return correct number of personas');

            PersonaController.PersonaDefinition mergedCustomPersona = result[1];
            Assert.areEqual(false, mergedCustomPersona.isStandard, 'Merged persona should not be standard');
            Assert.areEqual('utility:user', mergedCustomPersona.iconName, 'Merged persona should have correct icon name');
            Assert.areEqual(2, mergedCustomPersona.numberOfUsers, 'Should have combined number of users');
        }
    }

    @IsTest
    static void testMergeCustomPersonasWithEmptyList() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            List<PersonaController.PersonaDefinition> emptyList = new List<PersonaController.PersonaDefinition>();

            Test.startTest();
            List<PersonaController.PersonaDefinition> result = OverviewOrganizeYourTeamController.mergeCustomPersonas(emptyList);
            Test.stopTest();

            Assert.areEqual(1, result.size(), 'Should return only the merged custom persona container');
            Assert.areEqual(0, result[0].numberOfUsers, 'Merged persona should have zero users');
        }
    }

    @IsTest
    static void testMergeCustomPersonasInvalidPersona() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            List<PersonaController.PersonaDefinition> invalidPersonas = new List<PersonaController.PersonaDefinition>();
            invalidPersonas.add(new PersonaController.PersonaDefinition());

            Test.startTest();
            List<PersonaController.PersonaDefinition> result = OverviewOrganizeYourTeamController.mergeCustomPersonas(invalidPersonas);
            Test.stopTest();

            Assert.areEqual(1, result.size(), 'Expected only one merged persona.');
            Assert.areEqual(0, result[0].numberOfUsers, 'Merged persona should have zero users.');
        }
    }

    private static List<PersonaController.PersonaDefinition> createMockPersonaDefinitions() {
        List<PersonaController.PersonaDefinition> mockPersonas = new List<PersonaController.PersonaDefinition>();

        copado__Persona_Definition__c standardDef = new copado__Persona_Definition__c(
            Name = 'Standard Persona'
        );

        PersonaController.PersonaDefinition standardPersona = new PersonaController.PersonaDefinition()
            .persona(standardDef)
            .isStandard(true);
        standardPersona.numberOfUsers = 1;
        mockPersonas.add(standardPersona);

        copado__Persona_Definition__c customDef1 = new copado__Persona_Definition__c(
            Name = 'Custom Persona 1'
        );

        PersonaController.PersonaDefinition customPersona1 = new PersonaController.PersonaDefinition()
            .persona(customDef1)
            .isStandard(false);

        customPersona1.numberOfUsers = 1;
        customPersona1.iconName = 'custom-icon';
        mockPersonas.add(customPersona1);

        copado__Persona_Definition__c customDef2 = new copado__Persona_Definition__c(
            Name = 'Custom Persona 2'
        );

        PersonaController.PersonaDefinition customPersona2 = new PersonaController.PersonaDefinition()
            .persona(customDef2)
            .isStandard(false);

        customPersona2.numberOfUsers = 1;
        customPersona2.iconName = 'custom-icon';
        mockPersonas.add(customPersona2);

        return mockPersonas;
    }
}