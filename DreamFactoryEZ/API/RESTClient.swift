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

typealias SuccessHandler = (Bool, String?)->Void
typealias RestResultClosure = (RestCallResult) -> Void

enum RestCallResult {
    case success(result: JSON?)
    case failure(error: NSError)
    case unAuthorizedReauthenticate
    
    var bIsSuccess: Bool {
        switch (self) {
        case ( .success(_)): return true
        default: return false
        }
    }
    var json: JSON? {
        switch (self) {
        case (let .success(result)): return result
        default: return nil
        }
    }
    var error: NSError? {
        switch (self) {
        case (let .failure(error)): return error
        default: return nil
        }
    }
}
struct RestCall {
    var url: String
    var method: HTTPMethod
    var queryParams: [String : String]?
    var body: AnyObject?
}

enum HTTPMethod: String { case GET, POST, PATCH, DELETE }

class RESTClient {
    fileprivate let kRestRegister = "/user/register"
    fileprivate let kRestSignIn = "/user/session"
    fileprivate let baseInstanceUrl: String
    fileprivate let apiKey: String
    fileprivate var restActiveCallCount = 0
    
    init(apiKey:String, instanceUrl:String) {
        self.apiKey = apiKey
        self.baseInstanceUrl = instanceUrl
    }
    fileprivate var sessionToken: String? = nil
    fileprivate(set) var sessionEmail: String? = nil
    fileprivate var sessionPwd: String? = nil

    var isSignedIn: Bool {
        return (sessionToken != nil)
    }
    func signOut() {
        sessionToken = nil
        sessionEmail = nil
        sessionPwd = nil
        
        // For Testing can use expired token with presets in RESTClient
        //let kExpiredToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOjIsInVzZXJfaWQiOjIsImVtYWlsIjoidXNlcjFAemNhZ2UuY29tIiwiZm9yZXZlciI6ZmFsc2UsImlzcyI6Imh0dHBzOlwvXC9kZi1mdC1lcmljLWVsZm5lci5lbnRlcnByaXNlLmRyZWFtZmFjdG9yeS5jb21cL2FwaVwvdjJcL3VzZXJcL3Nlc3Npb24iLCJpYXQiOjE0NjI1NzA2NjEsImV4cCI6MTQ2MjU3NDI2MSwibmJmIjoxNDYyNTcwNjYxLCJqdGkiOiJkYjcyZjUxNWUxN2RiZTdlZWVjMDExNzliZGY2NTJhMiJ9.0NsO64trg3WgTh2-AUwSPhhz2XqSiXf5DXJVgHeH73Q"
        //sessionToken = kExpiredToken
        //sessionEmail = "user1@zcage.com" // Valid user
        //sessionPwd = "password" // Valid password
    }
    
    func registerWithEmail(_ email:String, password:String, registrationSuccessHandler: @escaping SuccessHandler) {
        let requestData = ["email" : email, "password" : password] as AnyObject
        
        callRestService(kRestRegister, method: .POST, queryParams: nil, body: requestData) { (callResult) in
            if callResult.bIsSuccess { // If configured for immediate registration, can go ahead and signin.
                self.signInWithEmail(email, password: password, signInHandler: registrationSuccessHandler)
            }
            else {
                registrationSuccessHandler(false, callResult.error?.localizedDescription)
            }
        }
    }
    
    func signInWithEmail(_ email:String, password:String, signInHandler: @escaping SuccessHandler) {
        let requestData = ["email" : email, "password" : password] as AnyObject
        
        callRestService(kRestSignIn, method: .POST, queryParams: nil, body: requestData) { (callResult) in
            var bSuccess = false
            if callResult.bIsSuccess {
                self.sessionPwd = password
                bSuccess = self.setUserDataFromJson(callResult.json)
            }
            signInHandler(bSuccess, callResult.error?.localizedDescription)
        }
    }

    func callRestServiceChain(_ chain: [RestCall], index: Int, resultClosure: @escaping RestResultClosure) {
        if index < chain.count {
        let restCall = chain[index]
            callRestService(restCall.url, method: restCall.method, queryParams: restCall.queryParams, body: restCall.body) { restResult in
                if restResult.bIsSuccess {
                    let bMoreItems = index < chain.count - 1
                    if bMoreItems {
                        self.callRestServiceChain(chain, index: index + 1, resultClosure: resultClosure)
                    }
                    else { // send back success
                        resultClosure(restResult)
                    }
                }
                else { // Send back first error
                    resultClosure(restResult)
                }
            }
        }
    }
    func callRestService(_ relativePath: String, method:HTTPMethod, queryParams: [String: String]?, body: AnyObject?, resultClosure:@escaping RestResultClosure) {
        
        let path = baseInstanceUrl + relativePath
        
        callCountIncrement(true)
        let request = buildRequest(path, method: method, queryParams: queryParams, body: body)
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = sessionHeaderParams()
        let session = URLSession(configuration: config)
        print("REST(\(method.rawValue))->\(request.pathAndQuery())")
        
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            self.callCountIncrement(false)
            let callResult = self.checkData(data, response: response, error: error as NSError?)
            switch callResult {
            case .unAuthorizedReauthenticate:
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
    fileprivate func sessionHeaderParams() -> [String: String] {
        var dict = ["Content-Type" : "application/json",
                    "X-DreamFactory-Api-Key": apiKey]
        if let token = sessionToken {
            dict["X-DreamFactory-Session-Token"] = token
        }
        return dict
    }
    
    fileprivate func callCountIncrement(_ bIsEntry:Bool) {
        synchronizedSelf() {
            restActiveCallCount = max(0, restActiveCallCount + (bIsEntry ? 1 : -1))
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: kRESTServerActiveCountUpdated), object: self, userInfo: ["count" : NSNumber.init(value: self.restActiveCallCount as Int)])
            }
        }
    }
    
    
    
    fileprivate func setUserDataFromJson(_ signInJson:JSON?) -> Bool {
        if let signInJson = signInJson {
            // elements: session_token, email, last_name, role_id, session_id, role, last_login_date, is_sys_admin, host, name, id
            sessionToken = signInJson["session_token"] as? String
            sessionEmail = signInJson["email"] as? String
        }
        else {
            sessionToken = nil
            sessionEmail = nil
            sessionPwd = nil
        }
        // Could set other data here
        return (sessionToken != nil)
    }
    fileprivate func checkData(_ data: Data?, response: URLResponse?, error: NSError?) -> RestCallResult {
        var parsedJSONResults: JSON?
        
        if let data = data {
            do {
                let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
                parsedJSONResults = jsonData as? JSON
            }
            catch {
                // Ignore if not JSON
            }
        }
        
        if let response_error = error {
            let error = NSError(domain: response_error.domain, code: response_error.code, userInfo: parsedJSONResults)
            return .failure(error: error)
        }
        else {
            let statusCode = (response as! HTTPURLResponse).statusCode
            if statusCode == 401 && sessionToken != nil && sessionEmail != nil && sessionPwd != nil {
                sessionToken = nil
                return .unAuthorizedReauthenticate
            }
            else if NSLocationInRange(statusCode, NSMakeRange(200, 99)) {
                return .success(result: parsedJSONResults)
            }
            else {
                let error = self.restErrorForStatusCode(statusCode, json: parsedJSONResults)
                return .failure(error: error)
            }
        }
    }
    // DreamFactory specific messaging extraction
    fileprivate func restErrorForStatusCode(_ statusCode: Int, json: JSON?) -> NSError {
        var userInfo = json
        if let pr = json {
            if let errorDict = pr["error"] {
                if let errorDict = errorDict as? JSON {
                    if let msg = errorDict["message"] as? String {
                        userInfo = [NSLocalizedDescriptionKey : msg as AnyObject]
                    }
                }
            }
        }
        let error = NSError(domain: "DreamFactoryAPI", code: statusCode, userInfo: userInfo)
        return error
    }
    fileprivate func buildRequest(_ path: String, method: HTTPMethod, queryParams: [String: String]?, body: AnyObject?) -> URLRequest {
        let request = NSMutableURLRequest()
        var requestUrl = path
        
        // build the query params into the URL. ["filter" : "true", "sort" : "1"] becomes "<url>?filter=true&sort=1
        if let queryParams = queryParams {
            let parameterString = queryParams.stringFromHttpParameters()
            requestUrl = "\(path)?\(parameterString)"
        }
        
        let URL = Foundation.URL(string: requestUrl)!
        request.url = URL
        request.timeoutInterval = 30
        
        request.httpMethod = method.rawValue
        if let body = body,
            let data = try? JSONSerialization.data(withJSONObject: body, options: []) {
            
            //else if let body = body as? NIKFile {
            //    data = body.data
            //}
            //else {
            //    data = body.data(using: String.Encoding.utf8)
            //}
            
            let postLength = "\(data.count)"
            request.setValue(postLength, forHTTPHeaderField: "Content-Length")
            request.httpBody = data
        }
        
        return request as URLRequest
    }
    // Adapted and simplified from: http://stackoverflow.com/a/34173952/4305146
    fileprivate func synchronizedSelf(_ closure: () -> ()) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        closure()
    }
}
