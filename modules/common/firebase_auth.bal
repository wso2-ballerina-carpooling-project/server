import ballerina/io;
import ballerina/jwt;
import ballerina/log;
import ballerina/oauth2;
import ballerina/time;

public client isolated class Client {
    private ServiceAccount? serviceAccount;
    private FirebaseConfig? firebaseConfig;
    private JWTConfig? jwtConfig;
    private string? jwt = ();
    private string PRIVATE_KEY_PATH;

    public isolated function init(AuthConfig authConfig) returns error? {
        self.serviceAccount = ();
        self.firebaseConfig = ();
        self.jwtConfig = ();
        self.PRIVATE_KEY_PATH = PRIVATE_KEY_PATH;
        self.serviceAccount = check self.getServiceAccount(authConfig.serviceAccountPath.cloneReadOnly());
        self.firebaseConfig = self.getFirebaseConfig(authConfig.firebaseConfig.cloneReadOnly());
        self.jwtConfig = authConfig.jwtConfig;
        self.PRIVATE_KEY_PATH = authConfig.privateKeyPath;
        check self.createPrivateKey();
        return;
    }

    isolated function getServiceAccount(string path) returns ServiceAccount|error {
        json serviceAccountFileInput = check io:fileReadJson(path);
        return check serviceAccountFileInput.cloneWithType(ServiceAccount);
    }

    isolated function createPrivateKey() returns error? {
        lock {
            ServiceAccount? serviceAccount = self.serviceAccount;
            if serviceAccount is () {
                return error("Service Account is not provided");
            }
            string[] privateKeyLine = re `\n`.split(serviceAccount.private_key);
            stream<string, io:Error?> lineStream = privateKeyLine.toStream();
            check io:fileWriteLinesFromStream(self.PRIVATE_KEY_PATH, lineStream);
        }

    }

    isolated function getFirebaseConfig(FirebaseConfig? firebaseConfig) returns FirebaseConfig|() {
        if (firebaseConfig is FirebaseConfig) {
            return firebaseConfig;
        }
        return ();
    }

    isolated function generateJWT(ServiceAccount serviceAccount) returns string|error {
        lock {

            JWTConfig? jwtConfig = self.jwtConfig;
            if jwtConfig is () {
                return error("JWT Config is not provided");
            }
            int timeNow = time:utcNow()[0];
            int expTime = timeNow + <int>jwtConfig.expTime;
            jwt:IssuerConfig issuerConfig = {
                issuer: serviceAccount.client_email,
                audience: serviceAccount.token_uri,
                expTime: jwtConfig.expTime,
                signatureConfig: {
                    algorithm: jwt:RS256,
                    config: {
                        keyFile: self.PRIVATE_KEY_PATH
                    }
                },
                customClaims: {
                    iss: serviceAccount.client_email,
                    scope: jwtConfig.scope,
                    aud: serviceAccount.token_uri,
                    iat: timeNow,
                    exp: expTime
                }
            };
            string jwt = check jwt:issue(issuerConfig);
            self.jwt = jwt;
            return jwt;
        }
    }

    isolated function isJWTExpired(string jwt) returns boolean|error {
        [jwt:Header, jwt:Payload] [_, payload] = check jwt:decode(jwt);
        int? exp = payload.exp;
        if (exp is int) {
            int timeNow = time:utcNow()[0];
            return exp < timeNow;
        }
        return error("Error in decoding JWT");
    }

    public isolated function generateToken() returns string|error {
        string jwt = "";
        lock {
            ServiceAccount? serviceAccount = self.serviceAccount.cloneReadOnly();
            if serviceAccount is () {
                return error("Service Account is not provided");
            }
            if self.jwt is () {
                jwt = check self.generateJWT(serviceAccount);
            }

            boolean|error isExpired = self.isJWTExpired(jwt);

            if isExpired is error {
                error er = isExpired;
                log:printError(er.message());
                return er;
            }

            if isExpired {
                jwt = check self.generateJWT(serviceAccount);
            }

            oauth2:JwtBearerGrantConfig jwtBearerGrantConfig = {
                tokenUrl: serviceAccount.token_uri,
                assertion: jwt
            };
            oauth2:ClientOAuth2Provider oauth2Provider = new (jwtBearerGrantConfig);
            string|error response = oauth2Provider.generateToken();

            if (response is error) {

                log:printError(response.message());
                return response;
            }

            return response;
        }

    }

}
