import ballerina/http;

configurable int port = 8080;

service / on new http:Listener(port) {
    resource function get .() returns string {
        return "Welcome to Ballerina Service!";
    }
    resource function get greeting/[string name]() returns string {
        return string `Hello, ${name}!`;
    } 
}
