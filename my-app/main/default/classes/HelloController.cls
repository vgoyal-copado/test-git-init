public with sharing class HelloController {
    @AuraEnabled(cacheable=true)
    public static String getGzipData() {
      //  String input = 'This is some large JSON or data string you want to compress.';
       // Blob inputBlob = Blob.valueOf(input);

        // GZIP compress the input
      //  Blob compressedBlob = gzipBlob(inputBlob);

        // Encode the compressed blob to Base64 string
        String base64Encoded = 'H4sIAAAAAAAAAwvJyCxWAKLi/NxUhZzEovRUBa9gfz+F/CKFlMSSRIXikqLMvHSFyvxShfLEvBKFknyF5PzcgqLU4mI9AHyZZOM8AAAA';
        return base64Encoded;
    }

    // private static Blob gzipBlob(Blob input) {
    //     // Use the built-in Compression class for GZIP (available in Apex)
    //     // Note: Compression is limited in Salesforce — workaround using JavaScript decompression
    //     return Compression.compress(input, CompressionAlgorithm.GZIP);
    // }
}