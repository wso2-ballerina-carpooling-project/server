import server.firebase as firebase;
import server.utility as utility;
import ballerina/crypto;
import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;


public function generateAuthToken(string userId, string email, string role) returns string {
    string payload = userId + ":" + email + ":" + role + ":" + time:utcNow().toString();
    string secretKey = "hello-world-sri-lanka-carpool-app";

    byte[] dataToSign = payload.toBytes();
    byte[] signature = checkpanic crypto:hmacSha256(dataToSign, secretKey.toBytes());

    return payload + "." + signature.toBase16();
}

public function hashPassword(string password) returns string {
    byte[] passwordBytes = password.toBytes();
    byte[] hash = crypto:hashSha256(passwordBytes);
    return hash.toBase16();
}

public function register(@http:Payload json payload, string accessToken) returns http:Response|error {
    string? email = check payload.email.ensureType();
    string? password = check payload.password.ensureType();
    string? firstName = check payload.firstName.ensureType();
    string? lastName = check payload.lastName.ensureType();
    string? phone = check payload.phone.ensureType();
    string? role = check payload.role.ensureType();

    // Validate required fields
    if email is () || password is () || firstName is () || lastName is () || role is () {
        return utility:createErrorResponse(400, "Missing required fields");
    }

    // Validate role
    if role != "driver" && role != "passenger" {
        return utility:createErrorResponse(400, "Role must be 'driver' or 'passenger'");
    }

    // Validate password strength
    if password.length() < 8 {
        return utility:createErrorResponse(400, "Password must be at least 8 characters long");
    }

    // Get access token

    // Check if email already exists
    map<json> emailFilter = {"email": email};
    map<json>[]|error queryResult = firebase:queryFirestoreDocuments(
                "carpooling-c6aa5",
            accessToken,
            "users",
            emailFilter
        );

    if queryResult is map<json>[] && queryResult.length() > 0 {
        return utility:createErrorResponse(409, "Email already registered");
    }

    // Process driver details if present
    record {|
        string? vehicleType;
        string? vehicleBrand;
        string? vehicleModel;
        string? vehicleRegistrationNumber;
        int? seatingCapacity;
    |}? vehicleData = ();

    if role == "driver" {
        var vehicleDetailsJson = payload?.vehicleDetails;

        if vehicleDetailsJson is json {
            string vehicleType = check vehicleDetailsJson.vehicleType.ensureType();
            string vehicleBrand = check vehicleDetailsJson.vehicleBrand.ensureType();
            string vehicleModel = check vehicleDetailsJson.vehicleModel.ensureType();
            string vehicleRegistrationNumber = check vehicleDetailsJson.vehicleRegistrationNumber.ensureType();
            int seatingCapacity = check vehicleDetailsJson.seatingCapacity.ensureType();

            // Validate driver details
            if vehicleType is "" || vehicleBrand is "" || vehicleModel is "" || seatingCapacity == 0 || vehicleRegistrationNumber == "" {
                return utility:createErrorResponse(400, "Driver details are incomplete");
            }

            vehicleData = {
                vehicleBrand: vehicleBrand,
                vehicleType: vehicleType,
                vehicleModel: vehicleModel,
                vehicleRegistrationNumber: vehicleRegistrationNumber,
                seatingCapacity: seatingCapacity
            };
        } else {
            return utility:createErrorResponse(400, "Driver details are required for driver role");
        }
    }

    // Create user document
    string userId = uuid:createType1AsString();
    string passwordHash = hashPassword(<string>password);
    string currentTime = time:utcNow().toString();

    map<json> userData = {
        "id": userId,
        "email": email,
        "firstName": firstName,
        "lastName": lastName,
        "phone": phone,
        "role": role,
        "status": "pending", // All new users start as pending
        "passwordHash": passwordHash,
        "driverDetails": vehicleData,
        "createdAt": currentTime
    };

    // Store in Firestore
    json|error createResult = firebase:createFirestoreDocument(
            "carpooling-c6aa5",
            accessToken,
            "users",
            userData
        );
    if createResult is error {
        log:printError("Failed to create user", createResult);
        return utility:createErrorResponse(500, "Failed to create user account");
    }

    // Notify about new user (in a real system, this would send an email or notification)
    // log:printInfo("New user registered: " + email + " with role: " + role);

    return utility:createSuccessResponse(201, {
                                                  "message": "Registration successful. Your account is pending approval by admin."
                                              });
}


public function login(@http:Payload json payload,string accessToken) returns http:Response|error {
        string? email = check payload.email.ensureType();
        string? password = check payload.password.ensureType();

        // Validate required fields
        if email is () || password is () {
            return utility:createErrorResponse(400, "Email and password are required");
        }

        // Get access token

        // Find user by email
        map<json> emailFilter = {"email": email};
        map<json>[]|error queryResult = firebase:queryFirestoreDocuments(
                "carpooling-c6aa5",
                accessToken,
                "users",
                emailFilter
        );

        // if queryResult is error || (queryResult is map<json>[] && queryResult.length() == 0) {
        //     return self.createErrorResponse(401, "Invalid email or password");
        // }

        map<json> user ;
        if queryResult is map<json>[] {
            user = queryResult[0];

            

        } else {
            return utility:createErrorResponse(500, "Failed to retrieve user data");
        }

        // Verify password
        string storedPasswordHash = <string>user["passwordHash"];
        string providedPasswordHash = hashPassword(<string>password);

        if storedPasswordHash != providedPasswordHash {
            return utility:createErrorResponse(401, "Invalid email or password");
        }

        // Check user status
        string status = <string>user["status"];
        string role = <string>user["role"];

        // Only allow login for admin or approved users
        if role != "admin" && status != "approved" {
            if status == "pending" {
                return utility:createErrorResponse(403, "Your account is pending approval by admin");
            } else if status == "rejected" {
                return utility:createErrorResponse(403, "Your account has been rejected");
            } else {
                return utility:createErrorResponse(403, "Your account is not active");
            }
        }

        // Generate authentication token
        string userId = <string>user["id"];
        string authToken = generateAuthToken(userId, <string>email, role);

        // Create response with user info and token
        map<json> response = {
            "id": userId,
            "email": email,
            "firstName": <string>user["firstName"],
            "lastName": <string>user["lastName"],
            "role": role,
            "status": status,
            "token": authToken
        };

        // Add driver details if available
        if user["driverDetails"] != null {
            response["driverDetails"] = user["driverDetails"];
        }

        return utility:createSuccessResponse(200, response);
    }
