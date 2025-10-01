@IsTest
public class MetaCacheServiceMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;
    private Map<String, String> headers;
    
    public MetaCacheServiceMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
        this.headers = new Map<String, String>();
    }
    
    public MetaCacheServiceMock addHeader(String key, String value) {
        this.headers.put(key, value);
        return this;
    }
    
    public HttpResponse respond(HttpRequest request) {
        // Validates Request
        System.assertEquals('POST', request.getMethod(), 'Expected POST method');
        System.assert(request.getEndpoint().contains('api/v3/cache-pipeline/'), 
            'Unexpected endpoint');
        
        // Creates Response
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        response.setBody(body);
        
        // Adds headers
        for(String header : headers.keySet()) {
            response.setHeader(header, headers.get(header));
        }
        
        return response;
    }
}