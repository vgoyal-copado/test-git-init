@SuppressWarnings('PMD.FieldNamingConventions')
public with sharing class ApexTestsViewer {
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
        public Integer totalLines;
        public Integer coveredLines;
    }

    public class CoverageMetrics {
        public List<MetadataCoverage> coverage;
        public List<MetadataCoverage> userStoryCoverage;
    }

    public class MetadataCoverage {
        public String name;
        public Integer totalLines;
        public Integer totalCovered;
        public Integer coveredPercent;

        public MetadataCoverage name(String name) {
            this.name = name;
            return this;
        }

        public MetadataCoverage totalLines(Integer totalLines) {
            this.totalLines = totalLines;
            return this;
        }

        public MetadataCoverage totalCovered(Integer totalCovered) {
            this.totalCovered = totalCovered;
            return this;
        }

        public MetadataCoverage coveredPercent(Integer coveredPercent) {
            this.coveredPercent = coveredPercent;
            return this;
        }
    }

    public class TestExecution {
        public MetadataClass ApexClass;
        public String MethodName;
        public String Outcome;
        public String Message;
        public String StackTrace;
        public Integer RunTime;
    }

    public class MetadataClass {
        public String Name;
    }
}