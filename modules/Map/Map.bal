import ballerina/http;
import ballerina/log;


public function getDirectionsWithWaypoints(
    record {| float lat; float lng; |} origin,
    record {| float lat; float lng; |}[] waypoints,
    record {| float lat; float lng; |} destination,
    string googleAPIKey
) returns json|error {
    
    // Initialize HTTP client
    http:Client directionsClient = check new("https://maps.googleapis.com");
    
    // Prepare waypoints string for the API
    string waypointsString = "";
    if waypoints.length() > 0 {
        waypointsString = "&waypoints=";
        foreach int i in 0 ..< waypoints.length() {
            if i > 0 {
                waypointsString += "|";
            }
            waypointsString += string `${waypoints[i].lat},${waypoints[i].lng}`;
        }
    }
    
    // Google Directions API URL
    string path = string `/maps/api/directions/json?origin=${origin.lat},${origin.lng}&destination=${destination.lat},${destination.lng}${waypointsString}&key=${googleAPIKey}&mode=driving`;
    
    // Make HTTP GET request
    http:Response response = check directionsClient->get(path);
    
    // Check if response is successful
    if response.statusCode == 200 {
        json responsePayload = check response.getJsonPayload();
        
        // Check if the API returned routes
        if responsePayload.status == "OK" {
            return responsePayload;
        } else {
            log:printError(string `Directions API error`);
            return error("Failed to get directions: Invalid response from API");
        }
    } else {
        log:printError(string `Failed to get directions: ${response.statusCode}`);
        return error(string `Failed to get directions with status code: ${response.statusCode}`);
    }
}
