
import ballerina/http;
import server.common;
import server.firebase;

import server.auth;
import server.Map;
import ballerina/log;

string accessToken;


function createSuccessResponse(int statusCode, json payload) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setJsonPayload(payload);
    return response;
}

// Helper function to create an error response
function createErrorResponse(int statusCode, string message) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setJsonPayload({
        "status": "ERROR",
        "message": message
    });
    return response;
}  

service /api on new http:Listener(8080){
     function init() {
        // Initialize Firebase credentials
        common:GoogleCredentials credentials = {
            serviceAccountJsonPath: "./service-account.json",
            privateKeyFilePath: "./private.key",
            tokenScope: "https://www.googleapis.com/auth/datastore"
        };

        accessToken = checkpanic firebase:generateAccessToken(credentials);
    }

    resource function post register(@http:Payload json payload) returns http:Response|error {
        http:Response|error response= auth:register(payload,accessToken);
        return response;
    }
    resource function post login(@http:Payload json payload) returns http:Response|error {
        http:Response|error response = auth:login(payload,accessToken);
        return response;
    }   
   resource function post direction(@http:Payload json payload) returns http:Response|error {
    // Extract coordinates from payload
    do {
        // Parse origin coordinates
        record {| float lat; float lng; |} origin = {
            lat: check float:fromString((check payload.origin.lat).toString()),
            lng: check float:fromString((check payload.origin.lng).toString())
        };
        
        // Parse destination coordinates
        record {| float lat; float lng; |} destination = {
            lat: check float:fromString(().toString()),
            lng: check float:fromString((check payload.destination.lng).toString())
        };
        
        // Parse waypoints
        json|error waypointsJson = payload.waypoints;
        record {| float lat; float lng; |}[] waypoints = [];
        
        if waypointsJson is json[] {
            foreach var point in waypointsJson {
                waypoints.push({
                    lat: check float:fromString((check point.lat).toString()),
                    lng: check float:fromString((check point.lng).toString())
                });
            }
        }
        
        // Get API key from configuration
        string apiKey = "AIzaSyC8GlueGNwtpZjPUjF6SWnxUHyC5GA82KE";
        
        // Call the directions service
        json|error directions = Map:getDirectionsWithWaypoints(origin, waypoints, destination, apiKey);
        
        // Process the response
        if directions is json {
            return createSuccessResponse(200, directions);
        } else {
            log:printError("Error getting directions", directions);
            return createErrorResponse(500, "Failed to retrieve directions: " + directions.message());
        }
    } on fail error err {
        log:printError("Error processing direction request", err);
        return createErrorResponse(400, "Invalid request format: " + err.message());
    }
}

// Helper function to create a success response

}


// import ballerina/http;
// import ballerina/log;
// import server.auth;
// // Protected API endpoint example
// service /api/v1 on new http:Listener(8080) {
    
//     // Public endpoint - login
//     resource function post login(@http:Payload json payload) returns http:Response|error {
//         string? email = check payload.email.ensureType();
//         string? password = check payload.password.ensureType();
        
//         if email is () || password is () {
//             return createErrorResponse(400, "Email and password are required");
//         }
        
//         // Here you would validate credentials from your database
//         // For this example, assume we found the user
//         string userId = "user123";
//         string role = "driver";
        
//         // Generate JWT token
//         string|error token = auth:generateJwtToken(userId, <string>email, role);
        
//         if token is error {
//             log:printError("Failed to generate token", token);
//             return createErrorResponse(500, "Authentication failed");
//         }
        
//         // Return token to client
//         return createSuccessResponse(200, {
//             "userId": userId,
//             "email": email,
//             "role": role,
//             "token": token
//         });
//     }
    
//     // Protected endpoint - requires authentication
//     resource function get profile(http:Request request) returns http:Response|error {
//         // Validate JWT token
//         boolean|error validation = auth:validateRequestToken(request);
        
//         if validation is error {
//             return createErrorResponse(401, validation.message());
//         }
        
//         boolean isValid = validation;
        
//         if !isValid {
//             return createErrorResponse(401, "Invalid authentication token");
//         }
        
//         // Here you would fetch the user's profile from your database
//         // For this example, we'll just return the information from the token
//         return createSuccessResponse(200, {
//             "profileComplete": true
//         });
//     }
    
//     // Protected endpoint with role check
    
// }

// // Helper functions for creating responses
// function createSuccessResponse(int statusCode, json data) returns http:Response {
//     http:Response response = new;
//     response.statusCode = statusCode;
//     response.setJsonPayload(data);
//     return response;
// }

// function createErrorResponse(int statusCode, string message) returns http:Response {
//     http:Response response = new;
//     response.statusCode = statusCode;
//     response.setJsonPayload({"error": message});
//     return response;
// }