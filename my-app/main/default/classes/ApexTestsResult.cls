@SuppressWarnings('PMD.ExcessivePublicCount, PMD.FieldNamingConventions')
public with sharing class ApexTestsResult {
    public ResultContainer result;

    public class ResultContainer {
        public Summary summary;
        public CoverageMetrics coverage;
        public List<TestExecution> tests;
    }

    public class Summary {
        public Integer testsRan;
        public Integer passing;
        public Integer failing;
        public Integer skipped;
        public String passRate;
        public String failRate;
        public String testRunCoverage;
        public String outcome;
    }

    public class CoverageMetrics {
        public List<MetadataCoverage> coverage;
    }

    public class MetadataCoverage {
        public String name;
        public Integer totalLines;
        public Integer totalCovered;
        public Integer coveredPercent;

        public Boolean equals(Object obj) {
            MetadataCoverage objectToCompare = (MetadataCoverage) obj;
            return this.name == objectToCompare.name;
        }

        public Integer hashCode() {
            return this.name.hashCode();
        }
    }

    public class SelectedMetadataCoverage {
        public Integer codeCoverage;
        public Integer totalLines;
        public Integer coveredLines;
    }

    public class TestExecution {
        public MetadataClass ApexClass;
        public String MethodName;
        public String Outcome;
        public String Message;
        public String StackTrace;
        public Integer RunTime;

        public Boolean equals(Object obj) {
            TestExecution objectToCompare = (TestExecution) obj;
            return this.ApexClass.Name == objectToCompare.ApexClass.Name;
        }

        public Integer hashCode() {
            return this.ApexClass.Name.hashCode();
        }
    }

    public class MetadataClass {
        public String Name;
    }

    // PUBLIC

    public ApexTestsResult fromJson(String jsonItem) {
        return (ApexTestsResult) JSON.deserialize(jsonItem, ApexTestsResult.class);
    }

    public Set<String> getMetadataWithoutCoverage(Integer minimumCoveragePercent, Set<String> metadata) {
        Set<String> result = new Set<String>();
        minimumCoveragePercent = minimumCoveragePercent == null ? 75 : minimumCoveragePercent;
        for (String metadataType : metadata) {
            Integer position = this.result.coverage.coverage.indexOf(getMetadataCoverage(metadataType));
            if (position >= 0 && getCoveragePercent(this.result.coverage.coverage.get(position)) < minimumCoveragePercent) {
                result.add(metadataType);
            }
        }
        return result;
    }

    public SelectedMetadataCoverage getTestRunCoverageItems(Set<String> metadata) {
        Integer coveredLines = 0;
        Integer totalLines = 0;

        // This logic will work if there are only test classes in the commit
        if (metadata.isEmpty()) {
            coveredLines = totalLines = 1;
        } else {
            for (MetadataCoverage metadataCoverage : this.result.coverage.coverage) {
                if (metadata.contains(metadataCoverage.name)) {
                    coveredLines += metadataCoverage.totalCovered;
                    totalLines += metadataCoverage.totalLines;
                }
            }
        }

        /*  
            When totalLines and coveredLines is 0 then it means that apex class doesn't have any executable logic,
            usually that happens when we only declare member variables in the class.
            How Is Code Coverage Calculated?, check here https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_code_coverage_intro.htm
        */
        SelectedMetadataCoverage metadataCoverage = new SelectedMetadataCoverage();

        metadataCoverage.codeCoverage = totalLines == 0 && coveredLines == 0 ? 100 : (Integer) (((Double) coveredLines / (Double) totalLines) * 100);
        metadataCoverage.totalLines = totalLines;
        metadataCoverage.coveredLines = coveredLines;
        return metadataCoverage;
    }

    public Integer getPassRate() {
        return toInteger(this.result.summary.passRate);
    }

    public Integer getFailRate() {
        return toInteger(this.result.summary.failRate);
    }

    // PRIVATE

    private Integer toInteger(String percentage) {
        return Integer.valueOf(percentage.remove('%'));
    }

    private Integer getCoveragePercent(MetadataCoverage metadataCoverage) {
        /*
            When metadataCoverage.totalLines and metadataCoverage.totalCovered is 0 then it means that apex class doesn't have any executable logic,
            usually that happens when we only declare member variables in the class.
            How Is Code Coverage Calculated?, check here https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_code_coverage_intro.htm
        */
        if (metadataCoverage.totalLines == 0 && metadataCoverage.totalCovered == 0) {
            return 100;
        }

        return (Integer) (((Double) metadataCoverage.totalCovered / (Double) metadataCoverage.totalLines) * 100);
    }

    private MetadataCoverage getMetadataCoverage(String metadata) {
        MetadataCoverage metadataCoverage = new MetadataCoverage();
        metadataCoverage.name = metadata;
        return metadataCoverage;
    }
}