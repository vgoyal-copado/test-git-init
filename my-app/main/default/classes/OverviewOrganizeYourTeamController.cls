public without sharing class OverviewOrganizeYourTeamController {
    @AuraEnabled
    public static List<PersonaController.PersonaDefinition> getPersonas () {
        try {
            List<PersonaController.PersonaDefinition> personaDefinitions = PersonaController.getPersonaDefinitions(false);

            return mergeCustomPersonas( personaDefinitions );
        } catch (System.NoAccessException nae) {
            throw new AuraHandledException(System.Label.OverviewNoAccess);
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.GenericError);
        }
    }

    public static List<PersonaController.PersonaDefinition> mergeCustomPersonas (
        List<PersonaController.PersonaDefinition> personaDefinitions
    ) {
        List<PersonaController.PersonaDefinition> finalPersonas = new List<PersonaController.PersonaDefinition>();

        copado__Persona_Definition__c customPersonaDefinition = new copado__Persona_Definition__c(
            Name = System.Label.AssignedToCustomPersonas
        );

        PersonaController.PersonaDefinition customPersona = new PersonaController.PersonaDefinition()
            .persona( customPersonaDefinition )
            .isStandard( false )
            .iconName(PersonaController.ICON_UTILITY_USER);

        for ( PersonaController.PersonaDefinition persona : personaDefinitions ) {
            if (persona?.isStandard != null ) {
                if ( persona.isStandard ) {
                    finalPersonas.add( persona );
                } else {
                    customPersona.numberOfUsers += persona.numberOfUsers;
                }
            }
        }
        

        finalPersonas.add( customPersona );

        return finalPersonas;
    }
}