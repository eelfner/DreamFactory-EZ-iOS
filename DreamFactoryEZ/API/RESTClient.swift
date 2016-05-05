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

import Foundation

let kRESTServerActiveCountUpdated = "kRESTServerActiveCountUpdated"

typealias SuccessHandler = (Bool)->Void
typealias RestResultClosure = (RestCallResult) -> Void

enum RestCallResult {
    case Success(result:JSON?)
    case Failure(error:NSError)
    
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

enum HTTPMethod: String { case GET, POST, PUT, DELETE }

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
    var sessionToken: String?
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
            registrationSuccessHandler(false)
        }
    }
    
    func signInWithEmail(email:String, password:String, signInHandler: SuccessHandler) {
        let requestData = ["email" : email, "password" : password]
        
        callRestService(kRestSignIn, method: .POST, queryParams: nil, body: requestData) { (callResult) in
            var bSuccess = false
            if callResult.bIsSuccess {
                bSuccess = self.setUserDataFromJson(callResult.json)
            }
            signInHandler(bSuccess)
        }
    }

    func callRestService(relativePath: String, method:HTTPMethod, queryParams: [String: AnyObject]?, body: AnyObject?, resultClosure:RestResultClosure) {
        
        let path = baseInstanceUrl + relativePath
        
        callCountIncrement(true)
        let request = buildRequest(path, method: method, queryParams: queryParams, body: body)
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = sessionHeaderParams()
        let session = NSURLSession(configuration: config)
        
        let task = session.dataTaskWithRequest(request, completionHandler: { data, response, error -> Void in
            self.callCountIncrement(false)
            let callResult = self.checkData(data, response: response, error: error)
            resultClosure(callResult)
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
        }
        else {
            sessionToken = nil
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
            if NSLocationInRange(statusCode, NSMakeRange(200, 99)) {
                return .Success(result: parsedJSONResults)
            }
            else {
                let error = NSError(domain: "DreamFactoryAPI", code: statusCode, userInfo: parsedJSONResults)
                return .Failure(error: error)
            }
        }
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