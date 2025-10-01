/**
 * Controller class to manage Copado Persona definitions and their related data for LWCs.
 * This class handles the retrieval and organization of persona information, including
 * standard personas and custom personas.
 */
public with sharing class PersonaController {
    private static Map<String, Integer> personaOrderByDeveloperName = new Map<String, Integer>{
        'Release Manager' => 1,
        'Developer' => 2,
        'Quality Engineer' => 3
    };
    // If you add a new value to the Map above, please change the following variable to the highest value + 1
    private static Integer indexOrderNonDefaultPersonas = 4;

    public static final String ICON_UTILITY_USER = 'utility:user';

    @AuraEnabled
    public static List<PersonaDefinition> getPersonaDefinitions(Boolean runInUserMode) {
        try {
            Map<String, PersonaDefinition> personaDefinitionsById = new Map<String, PersonaDefinition>();
            Map<String, copado__Default_Persona__mdt> defaultPersonasByName = getDefaultPersonasByName(runInUserMode);
    
            List<copado__Persona_Definition__c> personaDefinitions = runInUserMode ?
                getPersonasWithUserMode() :
                getPersonasWithSystemMode();

            for (copado__Persona_Definition__c personaDefinition : personaDefinitions) {
                PersonaDefinition personaDefinitionWrapper = new PersonaDefinition()
                    .persona(personaDefinition)
                    .iconName(getIconName(defaultPersonasByName.get(personaDefinition.Name)))
                    .isStandard(personaDefinition.copado__Is_Standard__c)
                    .order(getOrder(personaDefinition));
    
                personaDefinitionsById.put(personaDefinition.Id, personaDefinitionWrapper);
            }
    
            for (AggregateResult result : [
                SELECT copado__Persona_Id__c personaId, COUNT(Id) amountOfUsers
                FROM User
                WHERE copado__Persona_Id__c IN :personaDefinitionsById.keyset()
                WITH USER_MODE
                GROUP BY copado__Persona_Id__c
            ]) {
                personaDefinitionsById.get((String)result.get('personaId')).numberOfUsers = (Integer) result.get('amountOfUsers');
            }
    
            return personaDefinitionsById.values();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String getIconName(copado__Default_Persona__mdt defaultPersona) {
        return String.isNotBlank(defaultPersona?.copado__Icon_Name__c) ? defaultPersona?.copado__Icon_Name__c : ICON_UTILITY_USER;
    }

    private static Map<String, copado__Default_Persona__mdt> getDefaultPersonasByName(Boolean runInUserMode) {
        Map<String, copado__Default_Persona__mdt> defaultPersonasToUseByLabel = new Map<String, copado__Default_Persona__mdt>();

        List<copado__Default_Persona__mdt> defaultPersonas = runInUserMode ?
            getDefaultPersonasWithUserMode() :
            getDefaultPersonasWithSystemMode();

        List<copado__Default_Persona__mdt> defaultPersonasToUse = defaultPersonas;
        for ( copado__Default_Persona__mdt defaultPersona : defaultPersonasToUse ) {
            defaultPersonasToUseByLabel.put(defaultPersona.MasterLabel, defaultPersona);
        }

        return defaultPersonasToUseByLabel;
    }
    
    private static Integer getOrder(copado__Persona_Definition__c personaDefinition) {
        Integer order = personaOrderByDeveloperName.get(personaDefinition.Name);

        if (order == null) {
            order = indexOrderNonDefaultPersonas;
            indexOrderNonDefaultPersonas++;
        }

        return order;
    }

    private static List<copado__Persona_Definition__c> getPersonasWithUserMode() {
        return new PersonaDefinitionsSelector().getAllExtended();
    }

    /**
     * System Mode needed in order to verify the permissions of a User and display a message if permissions are missing.
     */
    private static List<copado__Persona_Definition__c> getPersonasWithSystemMode() {
        return [
            SELECT Id, Name, copado__Config_Json__c, copado__Is_Standard__c, copado__Description__c 
            FROM copado__Persona_Definition__c 
            ORDER BY CreatedDate ASC
        ];
    }

    private static List<copado__Default_Persona__mdt> getDefaultPersonasWithUserMode() {
        return [
            SELECT DeveloperName, MasterLabel, copado__Description__c, copado__Icon_Name__c 
            FROM copado__Default_Persona__mdt 
            WITH USER_MODE
        ];
    }

    /**
     * System Mode needed in order to verify the permissions of a User and display a message if permissions are missing.
     */
    private static List<copado__Default_Persona__mdt> getDefaultPersonasWithSystemMode() {
        return [
            SELECT DeveloperName, MasterLabel, copado__Description__c, copado__Icon_Name__c 
            FROM copado__Default_Persona__mdt
        ];
    }
    
    public with sharing class PersonaDefinition {
        @AuraEnabled
        public Integer numberOfUsers;
        @AuraEnabled
        public String iconName;
        @AuraEnabled
        public copado__Persona_Definition__c persona;
        @AuraEnabled
        public Boolean isStandard;

        // Set only for default persona
        @AuraEnabled
        public Integer order;

        public PersonaDefinition() {
            this.numberOfUsers = 0;
        }

        public PersonaDefinition persona(copado__Persona_Definition__c persona) {
            this.persona = persona;
            return this;
        }

        public PersonaDefinition iconName(String iconName) {
            this.iconName = iconName;
            return this;
        }

        public PersonaDefinition isStandard(Boolean isStandard) {
            this.isStandard = isStandard;
            return this;
        }

        public PersonaDefinition order(Integer order) {
            this.order = order;
            return this;
        }
    }
}