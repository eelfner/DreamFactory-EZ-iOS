//
//  DataAccess.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-05.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//
// This class handles server data calls by mapping between domain data
// and the RESTClient generic data. Server calls are made asynchronously and callbacks
// are by delegate protocols and always made on the main thread.
//
// Although this is implemented as a Singleton, it only has the restClient as state
// data so could easily also be changed to be injected.

import Foundation

private let kApiKey = "e71ef61795613a90bd8c03f0a742bfd67365262fec4f3fec8961beee40f7d1ed"
private let kBaseInstanceUrl = "https://df-ft-eric-elfner.enterprise.dreamfactory.com/api/v2"
private let kRestGetNames = "/db/_table/contact?fields=first_name%2C%20last_name"

typealias GetContactsHandler = ([String], NSError?)->Void

protocol SignInDelegate {
    func userIsSignedIn(bSignedIn:Bool)
}
protocol ContactsDelegate {
    func setContacts(contacts:[String])
    func dataAccessError(error:NSError?)
}

class DataAccess {
    static let sharedInstance = DataAccess()
    
    private var restClient = RESTClient(apiKey: kApiKey, instanceUrl: kBaseInstanceUrl)
    
    func isSignedIn() -> Bool {
        return restClient.isSignedIn
    }
    
    func signInWithEmail(email:String, password:String, signInDelegate: SignInDelegate) {
        restClient.signInWithEmail(email, password: password) { (bSignedIn) in
            dispatch_async(dispatch_get_main_queue()) {
                signInDelegate.userIsSignedIn(bSignedIn)
            }
        }
    }
    func signOut(signInDelegate: SignInDelegate) {
        restClient.signOut()
        dispatch_async(dispatch_get_main_queue()) {
            signInDelegate.userIsSignedIn(false)
        }
    }
    
    func getContacts(groupId:NSNumber?, resultDelegate: ContactsDelegate) {
        restClient.callRestService(kRestGetNames, method: .GET, queryParams: nil, body: nil) { restResult in
            if restResult.bIsSuccess {
                //print("Result \(restResult.json)")
                var newNames = [String]()
                if let contactsArray = restResult.json?["resource"] as? JSONArray {
                    for contact in contactsArray {
                        if let fName = contact["first_name"], let lName = contact["last_name"] {
                            let name = "\(lName), \(fName)"
                            newNames.append(name)
                            newNames.sortInPlace()
                        }
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.setContacts(newNames)
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    print("Error \(restResult.error)")
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }

}