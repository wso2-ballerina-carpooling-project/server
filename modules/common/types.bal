public type GoogleCredentials record {|
    string serviceAccountJsonPath;
    string privateKeyFilePath;
    string tokenScope;
|};

public type user record {|
    string userId;
    string firstname;
    string lastname;
    string email;
    string phone;
    string password;
    string role;
    boolean status;
|};

public type vehicle record{|
    string userId;
    string vehicleType;
    string vehicleModel;
    string vehicleRegNumber;
    int noOfSeat;
|};


public type ServiceAccount record {
    string 'type;
    string project_id;
    string private_key_id;
    string private_key;
    string client_email;
    string client_id;
    string auth_uri;
    string token_uri;
    string auth_provider_x509_cert_url;
    string client_x509_cert_url;
    string universe_domain;
};

public type FirebaseConfig record {
    string? apiKey = ();
    string? authDomain = ();
    string? databaseURL = ();
    string? projectId = ();
    string? storageBucket = ();
    string? messagingSenderId = ();
    string? appId = ();
    string? measurementId = ();
};

public type JWTConfig record {
    string scope;
    decimal expTime;
};

public type ClientError distinct error;

public type AuthConfig record {
    # Service account file path
    string serviceAccountPath;
    # Firebase config
    readonly & FirebaseConfig? firebaseConfig = ();
    # JWT config
    readonly & JWTConfig jwtConfig;
    # Private key file path
    string privateKeyPath = PRIVATE_KEY_PATH;
};
