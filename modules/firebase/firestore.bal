import ballerina/http;
import ballerina/io;
import ballerina/log;
import lakpahana/firebase_auth;
import server.common;



function generateAccessToken(common:GoogleCredentials credentials) returns string|error {
    firebase_auth:AuthConfig authConfig = {
        privateKeyPath: credentials.privateKeyFilePath,
        jwtConfig: {
            expTime: 3600,
            scope: credentials.tokenScope
        },
        serviceAccountPath: credentials.serviceAccountJsonPath
    };

    firebase_auth:Client authClient = check new(authConfig);
    string|error token = authClient.generateToken();
    if token is error {
        log:printError("Failed to obtain access token", token);
        return error("Failed to obtain access token");
    }
    return token;
}

function createFirestoreDocument(
    string projectId, 
    string accessToken, 
    string collection, 
    map<json> documentData
) returns error? {
    string firestoreUrl = string `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}`;
    
    http:Client firestoreClient = check new(firestoreUrl);
    http:Request request = new;
    
    request.setHeader("Authorization", string `Bearer ${accessToken}`);
    request.setHeader("Content-Type", "application/json");
    
    map<map<json>> firestoreFields = {};
    foreach var [key, value] in documentData.entries() {
        firestoreFields[key] = processFirestoreValue(value);
    }

    json payload = {
        fields: firestoreFields
    };

    request.setJsonPayload(payload);

    http:Response response = check firestoreClient->post("", request);
    
    if (response.statusCode == 200) {
        json result = check response.getJsonPayload();
        io:println("Document created successfully:", result);
    } else {
        io:println("Error creating document. Status code:", response.statusCode);
        string errorBody = check response.getTextPayload();
        io:println("Error details:", errorBody);
    }
}

function processFirestoreValue(json value) returns map<json> {
    if value is string {
        return {"stringValue": value};
    } else if value is int {
        return {"integerValue": value};
    } else if value is boolean {
        return {"booleanValue": value};
    } else if value is () {
        return {"nullValue": null};
    } else if value is map<json> {
        map<map<json>> convertedMap = {};
        foreach var [key, val] in value.entries() {
            convertedMap[key] = processFirestoreValue(val);
        }
        return {"mapValue": {"fields": convertedMap}};
    } else if value is json[] {
        json[] convertedArray = value.map(processFirestoreValue);
        return {"arrayValue": {"values": convertedArray}};
    } else {
        return {"stringValue": value.toJsonString()};
    }
}

public function main() returns error? {
    common:GoogleCredentials credentials = {
        serviceAccountJsonPath: "./service-account.json",
        privateKeyFilePath: "./private.key",
        tokenScope: "https://www.googleapis.com/auth/datastore"
    };

    string accessToken = check generateAccessToken(credentials);
    io:println("Access Token: ", accessToken);

    map<json> documentData = {
        "name": "Nalaka Dinesh",
        "age": 30,
        "active": true
    };

    check createFirestoreDocument(
        "carpooling-c6aa5", 
        accessToken, 
        "users", 
        documentData
    );
}
