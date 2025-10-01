@IsTest
public with sharing class PersonaControllerTest {
    private static final String ADMIN_USERNAME = 'username-admin@myemail.com';
    
    @TestSetup
    private static void makeData() {
        TestUtilities.setup();
        TestUtilities.setupAdminUser(ADMIN_USERNAME);
    }

    @IsTest
    public static void testgetPersonaDefinitions() {
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
            List<PersonaController.PersonaDefinition> result = PersonaController.getPersonaDefinitions( false );
            Test.stopTest();

            for ( PersonaController.PersonaDefinition personaDefinition : result ) {
                if ( personaDefinition.persona.Name.equalsIgnoreCase( 'Developer' ) ) {
                    Assert.areEqual( true, personaDefinition.isStandard, 'Expected Persona to be a standard persona.' );
                    Assert.isNotNull( personaDefinition.iconName, 'Standard Persona did not get an icon.' );
                    Assert.areEqual( 2, personaDefinition.numberOfUsers, 'Unexpected number of users in the Persona.' );
                } else if ( personaDefinition.persona.Name.equalsIgnoreCase( 'QA Tester' ) ) {
                    Assert.areEqual( false, personaDefinition.isStandard, 'Expected Persona to be a custom persona.' );
                    Assert.areEqual( 'utility:user', personaDefinition.iconName, 'Unexpected icon name was assigned to Persona.' );
                    Assert.areEqual( 1, personaDefinition.numberOfUsers, 'Unexpected number of users in the Persona.' );
                } else if ( personaDefinition.persona.Name.equalsIgnoreCase( 'QA Manager' ) ) {
                    Assert.areEqual( false, personaDefinition.isStandard, 'Expected Persona to be a custom persona.' );
                    Assert.areEqual( 'utility:user', personaDefinition.iconName, 'Unexpected icon name was assigned to Persona.' );
                    Assert.areEqual( 1, personaDefinition.numberOfUsers, 'Unexpected number of users in the Persona.' );
                } else {
                    Assert.isTrue( false, 'Unexpected Persona returned.' );
                }
            }
        }
    }

    @IsTest
    public static void testGetPersonaDefinitionsWithNoPersonas() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Test.startTest();
            List<PersonaController.PersonaDefinition> result = PersonaController.getPersonaDefinitions( false );
            Test.stopTest();

            Assert.areEqual(0, result.size(), 'Expected no persona definitions when no personas exist in the system');
        }
    }

    @IsTest
    public static void testGetPersonaDefinitionsWithNoPersonasUserMode() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            Test.startTest();
            List<PersonaController.PersonaDefinition> result = PersonaController.getPersonaDefinitions( true );
            Test.stopTest();

            Assert.areEqual(0, result.size(), 'Expected no persona definitions when no personas exist in the system');
        }
    }

    @IsTest
    public static void testGetPersonaDefinitionsWithNoUsers() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            copado__Persona_Definition__c standardPersona = new copado__Persona_Definition__c(
                Name = 'Developer',
                copado__Is_Standard__c = true
            );
            copado__Persona_Definition__c customPersona = new copado__Persona_Definition__c(
                Name = 'Custom Persona',
                copado__Is_Standard__c = false
            );
            insert new List<copado__Persona_Definition__c>{ standardPersona, customPersona };

            Test.startTest();
            List<PersonaController.PersonaDefinition> result = PersonaController.getPersonaDefinitions( false );
            Test.stopTest();

            for (PersonaController.PersonaDefinition personaDefinition : result) {
                Assert.areEqual(0, personaDefinition.numberOfUsers, 
                    'Expected no users associated with persona ' + personaDefinition.persona.Name);
                if (personaDefinition.isStandard) {
                    Assert.areEqual('Developer', personaDefinition.persona.Name, 
                        'Unexpected standard persona name');
                } else {
                    Assert.areEqual('Custom Persona', personaDefinition.persona.Name, 
                        'Unexpected custom persona name');
                    Assert.areEqual('utility:user', personaDefinition.iconName, 
                        'Unexpected icon for custom persona');
                }
            }
        }
    }

    @IsTest
    public static void testGetPersonaDefinitionsWithNoDefaultPersonas() {
        System.runAs(TestUtilities.getRunAsUser(ADMIN_USERNAME)) {
            copado__Persona_Definition__c standardPersona = new copado__Persona_Definition__c(
                Name = 'NonDefaultPersona',
                copado__Is_Standard__c = true
            );
            insert standardPersona;

            User standardUser = TestUtilities.createUser(false);
            standardUser.copado__Persona_Id__c = standardPersona.Id;
            standardUser.Username = TestUtilities.generateRandomString(10) + '@fakedomain.copado';
            insert standardUser;

            Test.startTest();
            List<PersonaController.PersonaDefinition> result = PersonaController.getPersonaDefinitions( false );
            Test.stopTest();

            Assert.areEqual(1, result.size(), 'Expected one persona definition');
            PersonaController.PersonaDefinition resultPersona = result[0];
            Assert.areEqual('NonDefaultPersona', resultPersona.persona.Name, 
                'Unexpected persona name');
            Assert.areEqual(true, resultPersona.isStandard, 
                'Expected persona to be standard');
            Assert.areEqual('utility:user', resultPersona.iconName, 
                'Expected default icon when no default persona configuration exists');
            Assert.areEqual(1, resultPersona.numberOfUsers, 
                'Expected one user associated with the persona');
        }
    }

    private static User getRunAsStandardUser() {
        return [SELECT Id FROM User WHERE Profile.Name = 'Standard User' ORDER BY CreatedDate DESC LIMIT 1];
    }
}