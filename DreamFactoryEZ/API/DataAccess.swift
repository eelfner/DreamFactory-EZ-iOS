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
private let kRestGetAllContacts = "/db/_table/contact"
private let kRestGetContactGroupRelationship = "/db/_table/contact_group_relationship"
private let kRestGetGroups = "/db/_table/contact_group"
private let kRestGetContactDetail = "/db/_table/contact_info"

typealias GetContactsHandler = ([String], NSError?)->Void

protocol RegistrationDelegate {
    func userIsRegisteredSuccess(bSignedIn:Bool, message:String?)
}
protocol SignInDelegate {
    func userIsSignedInSuccess(bSignedIn:Bool, message:String?)
    func userIsSignedOut()
}
protocol ContactsDelegate {
    func setContacts(contacts:[ContactRecord])
    func dataAccessError(error:NSError?)
}
protocol ContactDetailDelegate {
    func setContactGroups(groups: [GroupRecord])
    func setContactDetails(details: [ContactDetailRecord])
    func dataAccessError(error:NSError?)
}

class DataAccess {
    static let sharedInstance = DataAccess()
    private(set) var allGroups = [GroupRecord]() // Groups will be cached here.
    
    var currentGroupID: NSNumber? = nil
    private var restClient = RESTClient(apiKey: kApiKey, instanceUrl: kBaseInstanceUrl)
    
    func isSignedIn() -> Bool {
        return restClient.isSignedIn
    }
    
    func registerWithEmail(email:String, password:String, registrationDelegate: RegistrationDelegate) {
        restClient.registerWithEmail(email, password: password) { (bSuccess, message) in
            dispatch_async(dispatch_get_main_queue()) {
                registrationDelegate.userIsRegisteredSuccess(bSuccess, message: message)
            }
        }
    }
    func signInWithEmail(email:String, password:String, signInDelegate: SignInDelegate) {
        restClient.signInWithEmail(email, password: password) { (bSignedIn, message) in
            dispatch_async(dispatch_get_main_queue()) {
                if bSignedIn {
                    self.getAllGroups()
                }
                signInDelegate.userIsSignedInSuccess(bSignedIn, message: message)
            }
        }
    }
    func signOut(signInDelegate: SignInDelegate) {
        restClient.signOut()
        dispatch_async(dispatch_get_main_queue()) {
            signInDelegate.userIsSignedOut()
        }
    }
    
    func getContacts(group:GroupRecord?, resultDelegate: ContactsDelegate) {
        if let groupId = group?.id {
            getContactsForGroup(groupId, resultDelegate: resultDelegate)
        }
        else {
            getContactsAll(resultDelegate)
        }
    }
    func getContactDetails(contactId:Int, resultDelegate: ContactDetailDelegate) {
        getContactDetailsInfo(contactId, resultDelegate: resultDelegate)
        getContactDetailsGroups(contactId, resultDelegate: resultDelegate)
    }
    private func getContactDetailsInfo(contactId:Int, resultDelegate: ContactDetailDelegate) {
        let queryParams = ["filter" : "contact_id=\(contactId)"]
        restClient.callRestService(kRestGetContactDetail, method: .GET, queryParams: queryParams, body: nil) { restResult in
            if restResult.bIsSuccess {
                var details = [ContactDetailRecord]()
                if let detailArray = restResult.json?["resource"] as? JSONArray {
                    for detailJSON in detailArray {
                        if let detail = ContactDetailRecord(json:detailJSON) {
                            details.append(detail)
                        }
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.setContactDetails(details)
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    private func getContactDetailsGroups(contactId:Int, resultDelegate: ContactDetailDelegate) {
        let queryParams = ["related" : "contact_group_by_contact_group_id", "filter" : "contact_id=\(contactId)"]
        restClient.callRestService(kRestGetContactGroupRelationship, method: .GET, queryParams: queryParams, body: nil) { restResult in
            if restResult.bIsSuccess {
                var groups = [GroupRecord]()
                if let results = restResult.json?["resource"] as? JSONArray {
                    for result in results {
                        if let groupJSON = result["contact_group_by_contact_group_id"] as? JSON {
                            if let group = GroupRecord(json:groupJSON) {
                                groups.append(group)
                            }
                        }
                    }
                }
                groups.sortInPlace({ (r1, r2) -> Bool in
                    return r1.name < r2.name
                })
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.setContactGroups(groups)
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    // Must query relationship table and specify to return the related contact data.
    // Sorting cannot be done through REST call.
    private func getContactsForGroup(groupID: NSNumber, resultDelegate: ContactsDelegate) {
        let queryParams = ["related" : "contact_by_contact_id", "filter" : "contact_group_id=\(groupID.intValue)"]
        restClient.callRestService(kRestGetContactGroupRelationship, method: .GET, queryParams: queryParams, body: nil) { restResult in
            if restResult.bIsSuccess {
                var contacts = [ContactRecord]()
                if let results = restResult.json?["resource"] as? JSONArray {
                    for result in results {
                        if let contactJSON = result["contact_by_contact_id"] as? JSON {
                            if let contact = ContactRecord(json:contactJSON) {
                                contacts.append(contact)
                            }
                        }
                    }
                }
                contacts.sortInPlace({ (r1, r2) -> Bool in
                    return r1.fullName < r2.fullName
                })
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.setContacts(contacts)
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }

    private func getContactsAll(resultDelegate: ContactsDelegate) {
        let queryParams = ["order" : "last_name asc, first_name asc"]
        restClient.callRestService(kRestGetAllContacts, method: .GET, queryParams: queryParams, body: nil) { restResult in
            if restResult.bIsSuccess {
                var contacts = [ContactRecord]()
                if let contactsArray = restResult.json?["resource"] as? JSONArray {
                    for contactJSON in contactsArray {
                        if let contact = ContactRecord(json:contactJSON) {
                            contacts.append(contact)
                        }
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.setContacts(contacts)
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    private func getAllGroups() {
        restClient.callRestService(kRestGetGroups, method: .GET, queryParams: nil, body: nil) { restResult in
            if restResult.bIsSuccess {
                var groups = [GroupRecord]()
                if let groupsArray = restResult.json?["resource"] as? JSONArray {
                    for groupJSON in groupsArray {
                        if let group = GroupRecord(json:groupJSON) {
                            groups.append(group)
                        }
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.allGroups = groups
                }
            }
            else {
                print("REST->Failed to get Groups")
            }
        }
    }

}