//
//  RESTClient
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//
// This class is a basic REST client configure for access DreamFactory servers.
// It handles signon, session token, and network traffic. No domain specific knowledge.
// REST call results (success and failure) are represented by RestCallResult enum which
// is used in the RestResultClosure to simplify the callback interface.
//
// Some of this is motivated by the DreamFactory iOS Example, but mostly re-written. 

import Foundation

let kRESTServerActiveCountUpdated = "kRESTServerActiveCountUpdated"

// For Testing can use expired token with presets in RESTClient
//let kExpiredToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOjIsInVzZXJfaWQiOjIsImVtYWlsIjoidXNlcjFAemNhZ2UuY29tIiwiZm9yZXZlciI6ZmFsc2UsImlzcyI6Imh0dHBzOlwvXC9kZi1mdC1lcmljLWVsZm5lci5lbnRlcnByaXNlLmRyZWFtZmFjdG9yeS5jb21cL2FwaVwvdjJcL3VzZXJcL3Nlc3Npb24iLCJpYXQiOjE0NjI1NzA2NjEsImV4cCI6MTQ2MjU3NDI2MSwibmJmIjoxNDYyNTcwNjYxLCJqdGkiOiJkYjcyZjUxNWUxN2RiZTdlZWVjMDExNzliZGY2NTJhMiJ9.0NsO64trg3WgTh2-AUwSPhhz2XqSiXf5DXJVgHeH73Q"
//var sessionToken: String? = kExpiredToken
//var sessionEmail: String? = "user1@zcage.com" // Valid user
//var sessionPwd: String? = "password" // Valid password

typealias SuccessHandler = (Bool, String?)->Void
typealias RestResultClosure = (RestCallResult) -> Void

enum RestCallResult {
    case Success(result: JSON?)
    case Failure(error: NSError)
    case UnAuthorizedReauthenticate
    
    var bIsSuccess: Bool {
        switch (self) {
        case ( .Success(_)): return true
        default: return false
        }
    }
    var json: JSON? {
        switch (self) {
        case (let .Success(result)): return result
        default: return nil
        }
    }
    var error: NSError? {
        switch (self) {
        case (let .Failure(error)): return error
        default: return nil
        }
    }
}

enum HTTPMethod: String { case GET, POST, PATCH, DELETE }

class RESTClient {
    private let kRestRegister = "/user/register"
    private let kRestSignIn = "/user/session"
    private let baseInstanceUrl: String
    private let apiKey: String
    private var restActiveCallCount = 0
    
    init(apiKey:String, instanceUrl:String) {
        self.apiKey = apiKey
        self.baseInstanceUrl = instanceUrl
    }
    var sessionToken: String? = nil
    var sessionEmail: String? = nil
    var sessionPwd: String? = nil

    var isSignedIn: Bool {
        return (sessionToken != nil)
    }
    func signOut() {
        sessionToken = nil
    }
    
    func registerWithEmail(email:String, password:String, registrationSuccessHandler: SuccessHandler) {
        let requestData = ["email" : email, "password" : password]
        
        callRestService(kRestRegister, method: .POST, queryParams: nil, body: requestData) { (callResult) in
            if callResult.bIsSuccess {
                self.signInWithEmail(email, password: password, signInHandler: registrationSuccessHandler)
            }
            registrationSuccessHandler(false, callResult.error?.localizedDescription)
        }
    }
    
    func signInWithEmail(email:String, password:String, signInHandler: SuccessHandler) {
        let requestData = ["email" : email, "password" : password]
        
        callRestService(kRestSignIn, method: .POST, queryParams: nil, body: requestData) { (callResult) in
            var bSuccess = false
            if callResult.bIsSuccess {
                bSuccess = self.setUserDataFromJson(callResult.json)
            }
            signInHandler(bSuccess, callResult.error?.localizedDescription)
        }
    }

    func callRestService(relativePath: String, method:HTTPMethod, queryParams: [String: AnyObject]?, body: AnyObject?, resultClosure:RestResultClosure) {
        
        let path = baseInstanceUrl + relativePath
        
        callCountIncrement(true)
        let request = buildRequest(path, method: method, queryParams: queryParams, body: body)
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = sessionHeaderParams()
        let session = NSURLSession(configuration: config)
        print("REST(\(method.rawValue))->\(request.pathAndQuery())")
        
        let task = session.dataTaskWithRequest(request, completionHandler: { data, response, error -> Void in
            self.callCountIncrement(false)
            let callResult = self.checkData(data, response: response, error: error)
            switch callResult {
            case .UnAuthorizedReauthenticate:
                print("REST:UnAuthorizedReauthenticate")
                self.signInWithEmail(self.sessionEmail!, password: self.sessionPwd!) { (bSuccess, _) in
                    if bSuccess && self.restActiveCallCount < 20 { // ReAuth worked, try original request again. Prevent endless looping.
                        self.callRestService(relativePath, method: method, queryParams: queryParams, body: body, resultClosure: resultClosure)
                    }
                    else {
                        resultClosure(callResult)
                    }
                }
            default:
                resultClosure(callResult)
            }
        })
        task.resume()
    }
    
    // MARK: - Rest Handling
    private func sessionHeaderParams() -> [String: String] {
        var dict = ["Content-Type" : "application/json",
                    "X-DreamFactory-Api-Key": apiKey]
        if let token = sessionToken {
            dict["X-DreamFactory-Session-Token"] = token
        }
        return dict
    }
    
    private func callCountIncrement(bIsEntry:Bool) {
        synchronizedSelf() {
            restActiveCallCount = max(0, restActiveCallCount + (bIsEntry ? 1 : -1))
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(kRESTServerActiveCountUpdated, object: self, userInfo: ["count" : NSNumber.init(long: self.restActiveCallCount)])
            }
        }
    }
    
    private func setUserDataFromJson(signInJson:JSON?) -> Bool {
        if let signInJson = signInJson {
            sessionToken = signInJson["session_token"] as? String
            sessionEmail = signInJson["user_email"] as? String
            sessionPwd = signInJson["user_passwor"] as? String
        }
        else {
            sessionToken = nil
            sessionEmail = nil
            sessionPwd = nil
        }
        // Could set other data here
        return (sessionToken != nil)
    }
    private func checkData(data: NSData?, response: NSURLResponse?, error: NSError?) -> RestCallResult {
        var parsedJSONResults: JSON?
        
        if let data = data {
            do {
                let jsonData = try NSJSONSerialization.JSONObjectWithData(data, options: [])
                parsedJSONResults = jsonData as? JSON
            }
            catch {
                // Ignore if not JSON
            }
        }
        
        if let response_error = error {
            let error = NSError(domain: response_error.domain, code: response_error.code, userInfo: parsedJSONResults)
            return .Failure(error: error)
        }
        else {
            let statusCode = (response as! NSHTTPURLResponse).statusCode
            if statusCode == 401 && sessionToken != nil && sessionEmail != nil && sessionPwd != nil {
                sessionToken = nil
                return .UnAuthorizedReauthenticate
            }
            else if NSLocationInRange(statusCode, NSMakeRange(200, 99)) {
                return .Success(result: parsedJSONResults)
            }
            else {
                let error = self.restErrorForStatusCode(statusCode, json: parsedJSONResults)
                return .Failure(error: error)
            }
        }
    }
    // DreamFactory specific messaging extraction
    private func restErrorForStatusCode(statusCode: Int, json: JSON?) -> NSError {
        var userInfo = json
        if let pr = json {
            if let errorDict = pr["error"] {
                if let errorDict = errorDict as? JSON {
                    if let msg = errorDict["message"] as? String {
                        userInfo = [NSLocalizedDescriptionKey : msg]
                    }
                }
            }
        }
        let error = NSError(domain: "DreamFactoryAPI", code: statusCode, userInfo: userInfo)
        return error
    }
    private func buildRequest(path: String, method: HTTPMethod, queryParams: [String: AnyObject]?, body: AnyObject?) -> NSURLRequest {
        let request = NSMutableURLRequest()
        var requestUrl = path
        
        // build the query params into the URL. ["filter" : "true", "sort" : "1"] becomes "<url>?filter=true&sort=1
        if let queryParams = queryParams {
            let parameterString = queryParams.stringFromHttpParameters()
            requestUrl = "\(path)?\(parameterString)"
        }
        
        let URL = NSURL(string: requestUrl)!
        request.URL = URL
        request.timeoutInterval = 30
        
        request.HTTPMethod = method.rawValue
        if let body = body {
            var data: NSData!
            if body is [String: AnyObject] || body is [AnyObject] {
                data = try? NSJSONSerialization.dataWithJSONObject(body, options: [])
            }
            //else if let body = body as? NIKFile {
            //    data = body.data
            //}
            else {
                data = body.dataUsingEncoding(NSUTF8StringEncoding)
            }
            let postLength = "\(data.length)"
            request.setValue(postLength, forHTTPHeaderField: "Content-Length")
            request.HTTPBody = data
        }
        
        return request
    }
    // Adapted and simplified from: http://stackoverflow.com/a/34173952/4305146
    private func synchronizedSelf(@noescape closure: () -> ()) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        closure()
    }
}