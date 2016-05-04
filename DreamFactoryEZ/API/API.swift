//
//  API.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-03.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//

import UIKit

let kNotificationContactNames = "kNotificationContactNames"

private let names = ["George", "Jamal", "Sally"]

private let kBaseInstanceUrl = "https://df-ft-eric-elfner.enterprise.dreamfactory.com/api/v2"
private let kRestGetNames = kBaseInstanceUrl + "/db/_table/contact?fields=first_name%2C%20last_name"
private let kRestSignIn = kBaseInstanceUrl + "/user/session"

private let kApiKey = "e71ef61795613a90bd8c03f0a742bfd67365262fec4f3fec8961beee40f7d1ed"

private var restActiveCallCount = 0

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

class API {
    static let sharedInstance = API()
    
    private var sessionToken: String?
    var isSignedIn: Bool {
        return (sessionToken != nil)
    }
    
    // MARK: - Public Interface
    func signInWithEmail(email:String, password:String, resultClosure: RestResultClosure) {
        let requestData = ["email" : email, "password" : password]
        
        callApiWithPath(kRestSignIn, method: .POST, queryParams: nil, body: requestData) { (callResult) in
            if callResult.bIsSuccess {
                if self.setUserDataFromJson(callResult.json) {
                    resultClosure(RestCallResult.Success(result: nil))
                }
                else {
                    let error = NSError(domain: "DreamFactoryAPI", code: 0, userInfo: ["Error" : "No session token found."])
                    resultClosure(RestCallResult.Failure(error: error))
                }
            }
        }
    }
    func getContacts(groupId:NSNumber?, resultClosure: RestResultClosure) {
        callApiWithPath(kRestGetNames, method: .GET, queryParams: nil, body: nil, resultClosure: resultClosure)
    }
    
    // MARK: - Rest Handling
    private func sessionHeaderParams() -> [String: String] {
        var dict = ["Content-Type" : "application/json",
                    "X-DreamFactory-Api-Key": kApiKey]
        if let token = sessionToken {
            dict["X-DreamFactory-Session-Token"] = token
        }
        return dict
    }
    
    private func callCountIncrement(bIsEntry:Bool) {
        synchronizedSelf() {
            restActiveCallCount = max(0, restActiveCallCount + (bIsEntry ? 1 : -1))
            
            dispatch_async(dispatch_get_main_queue()) {
                let bShowNetworkActivity = restActiveCallCount > 0
                UIApplication.sharedApplication().networkActivityIndicatorVisible = bShowNetworkActivity
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
    private func callApiWithPath(path: String, method:HTTPMethod, queryParams: [String: AnyObject]?, body: AnyObject?, resultClosure:RestResultClosure) {
        
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