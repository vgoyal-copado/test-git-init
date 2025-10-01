@IsTest
public class PersonaDefinitionConfig {
        public List<ConfigEntry> permissionSets;
        public List<ConfigEntry> permissionSetGroups;
        public List<ConfigEntry> appPermissions;
        public List<ConfigEntry> customPermissions;
        public List<ConfigEntry> licenses;
        public List<ConfigEntry> packageLicenses;
        public List<Id> credentialIds;
        public Id publicGroupId;
        public String defaultCredentialAccessLevel;
        public List<FeatureEntry> features;

        public class ConfigEntry {
            public String name;
            public Boolean isStandard;
        }
        public class FeatureEntry {
            public String name;
            public String customPermission;
            public Boolean enabled;
            public FeatureRequirements featureRequirements;
        }
        public class FeatureRequirements {
            public List<RequirementEntry> permissionSets;
            public List<RequirementEntry> permissionSetGroups;
            public List<RequirementEntry> customPermissions;
            public List<RequirementEntry> licenses;
        }
        public class RequirementEntry {
            public String name;
        }
    }