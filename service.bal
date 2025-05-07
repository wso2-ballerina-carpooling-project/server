
import ballerina/http;
import server.common;
import server.firebase;
import ballerina/io;
import server.auth;

string accessToken;

service /api on new http:Listener(8080){
     function init() {
        // Initialize Firebase credentials
        common:GoogleCredentials credentials = {
            serviceAccountJsonPath: "./service-account.json",
            privateKeyFilePath: "./private.key",
            tokenScope: "https://www.googleapis.com/auth/datastore"
        };

        accessToken = checkpanic firebase:generateAccessToken(credentials);
        io:println("Access Token: ", accessToken);
    }

    resource function post register(@http:Payload json payload) returns http:Response|error {
        http:Response|error response= auth:register(payload,accessToken);
        return response;
    }
    resource function post login(@http:Payload json payload) returns http:Response|error {
        http:Response|error response = auth:login(payload,accessToken);
        return response;
    }
}