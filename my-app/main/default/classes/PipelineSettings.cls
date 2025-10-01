@SuppressWarnings('PMD.PropertyNamingConventions')
// PropertyNamingConventions: Needed for Skeleton Attributes, as we are using a name starting by uppercase

public inherited sharing class PipelineSettings implements CopadoDomain {

    /************ VLOCITY ************/

    // SKELETON Attribute
    // Parameter name starts with a capital letter for execution signature to look like static execution.
    public static VlocitySetting VlocitySetting {
        get {
            if (VlocitySetting == null) {
                VlocitySetting = new VlocitySetting();
            }
            return VlocitySetting;
        }
        set;
    }

    /*
        SENSITIVE CLASS
        - Changes in this class will potentially impact many usages and use cases.
        - Please get an architect approval before changing this class.
        - [TDD] If the change is approved please start by creating a Unit test for your change first.
        - When the change is done execute the PipelineInitializer Domain test suite not just your test.
        - If the new test is not included in the test suite, make sure to add it.
        - Pull request for changes happened in this class must contain an architect approval.
    */

    public inherited sharing class VlocitySetting implements CopadoService {

        public EnableVlocitySettingResult enable(EnableVlocitySettingRequest request) {
            Savepoint sp = Database.setSavepoint();

            try {
                return EnableVlocitySettingImpl.execute(request);
            } catch (Exception ex) {
                Database.rollback(sp);
                throw new ApplicationException(ex.getMessage());
            }
        }

        public DisableVlocitySettingResult disable(DisableVlocitySettingRequest request) {
            Savepoint sp = Database.setSavepoint();

            try {
                return DisableVlocitySettingImpl.execute(request);
            } catch (Exception ex) {
                Database.rollback(sp);
                throw new ApplicationException(ex.getMessage());
            }
        }

        public VlocitySettingStatusResult status(VlocitySettingStatusRequest request) {

            try {
                return VlocitySettingStatusImpl.execute(request);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class EnableVlocitySettingRequest implements CopadoServiceRequest {
        public Id pipelineId; // Required, Pipeline Id
    }
    
    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class DisableVlocitySettingRequest implements CopadoServiceRequest {
        public Id pipelineId; // Required, Pipeline Id
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class VlocitySettingStatusRequest implements CopadoServiceRequest {
        public Id pipelineId; // Required, Pipeline Id
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class EnableVlocitySettingResult implements CopadoServiceResult {
        public Boolean status; // true if vlocity is enabled
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class DisableVlocitySettingResult implements CopadoServiceResult {
        public Boolean status; // true if vlocity is disabled
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class VlocitySettingStatusResult implements CopadoServiceResult {
        public Boolean status; // true if vlocity is enabled, otherwise false
        public copado__System_Property__c systemProperty; // System property with api name "vlocity_enabled" if exists otherwise null
    }

   
    /************ VLOCITY ************/


    /************ NEW COMMIT EXP ************/

    // SKELETON Attribute
    // Parameter name starts with a capital letter for execution signature to look like static execution.
    public static NewCommitExpSetting NewCommitExpSetting {
        get {
            if (NewCommitExpSetting == null) {
                NewCommitExpSetting = new NewCommitExpSetting();
            }
            return NewCommitExpSetting;
        }
        set;
    }

    /*
        SENSITIVE CLASS
        - Changes in this class will potentially impact many usages and use cases.
        - Please get an architect approval before changing this class.
        - [TDD] If the change is approved please start by creating a Unit test for your change first.
        - When the change is done execute the PipelineInitializer Domain test suite not just your test.
        - If the new test is not included in the test suite, make sure to add it.
        - Pull request for changes happened in this class must contain an architect approval.
    */
    public inherited sharing class NewCommitExpSetting implements CopadoService {

        public EnableNewCommitExpSettingResult enable(EnableNewCommitExpSettingRequest request) {
            try {
                return EnableNewCommitExpSettingImpl.execute(request);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }

        public NewCommitExpSettingStatusResult status(NewCommitExpSettingStatusRequest request) {

            try {
                return NewCommitExpSettingStatusImpl.execute(request);
            } catch (Exception ex) {
                throw new ApplicationException(ex.getMessage());
            }
        }
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class EnableNewCommitExpSettingRequest implements CopadoServiceRequest {
        public Id pipelineId; // Required, Pipeline Id
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class NewCommitExpSettingStatusRequest implements CopadoServiceRequest {
        public Id pipelineId; // Required, Pipeline Id
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class EnableNewCommitExpSettingResult implements CopadoServiceResult {
        public Boolean status; // true if new commit experience is enabled
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class NewCommitExpSettingStatusResult implements CopadoServiceResult {
        @AuraEnabled public Boolean status; // true if new commit experience is enabled, otherwise false
        public copado__System_Property__c systemProperty; // System property with api name "new_commit_experience_enabled" if exists otherwise null
        @AuraEnabled public List<NewCommitExpSettingDependency> unmetDependencies; // List of dependencies for the new commit experience setting
    }

    @JsonAccess(serializable='always' deserializable='always')
    public inherited sharing class NewCommitExpSettingDependency {
        @AuraEnabled public String name;
        @AuraEnabled public String value;

        public NewCommitExpSettingDependency(String name, String value) {
            this.name = name;
            this.value = value;
        }
    }

    /************ NEW COMMIT EXP ************/
    
}