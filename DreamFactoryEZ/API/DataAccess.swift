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
// This is implemented as a singleton to simplify code and only access a specific server.
// A more generic implementation would have server instance injected.

import Foundation

private let kApiKey = "e71ef61795613a90bd8c03f0a742bfd67365262fec4f3fec8961beee40f7d1ed"
let kBaseInstanceUrl = "https://df-ft-eric-elfner.enterprise.dreamfactory.com/api/v2"
private let kRestContact = "/db/_table/contact"
private let kRestContactGroupRelationship = "/db/_table/contact_group_relationship"
private let kRestGroup = "/db/_table/contact_group"
private let kRestContactDetail = "/db/_table/contact_info"

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
protocol ContactUpdateDelegate {
    func setContact(contact:ContactRecord)
    func dataAccessError(error:NSError?)
}
protocol ContactDeleteDelegate {
    func contactDeleteSuccess()
    func dataAccessError(error:NSError?)
}
protocol ContactDetailDelegate {
    func setContactGroups(groups: [GroupRecord])
    func setContactDetails(details: [ContactDetailRecord])
    func dataAccessError(error:NSError?)
}
protocol ContactDetailUpdateDelegate {
    func dataAccessSuccess()
    func dataAccessError(error:NSError?)
}
protocol ContactDetailDeleteDelegate {
    func dataAccessSuccess()
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
    func signedInUser() -> String? {
        return restClient.sessionEmail
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
    
    func getContact(id:Int, resultDelegate: ContactUpdateDelegate) {
        restClient.callRestService(kRestContact + "/\(id)", method: .GET, queryParams: nil, body: nil) { restResult in
            var contact:ContactRecord?
            if restResult.bIsSuccess {
                if let contactJson = restResult.json {
                    contact = ContactRecord(json:contactJson)
                }
            }
            if let contact = contact {
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.setContact(contact)
                }
            }
            else {
                let error = restResult.error ?? NSError(domain: "DreamFactory API", code: 500, userInfo: [NSLocalizedDescriptionKey : "Could not create Contact from API result."])
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.dataAccessError(error)
                }
            }
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
    
    func removeContact(contact: ContactRecord, fromGroupId: Int, resultDelegate: ContactDetailDelegate) {
        // Do not have the ID of the record to remove, but can set id_field and remove with those.
        let queryParams: [String: AnyObject] = ["id_field": "contact_group_id,contact_id"]
        let records: JSONArray = [["contact_group_id": fromGroupId, "contact_id": contact.id]]
        let requestBody: [String: AnyObject] = ["resource": records]

        restClient.callRestService(kRestContactGroupRelationship, method: .DELETE, queryParams: queryParams, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                self.getContactDetails(contact.id, resultDelegate: resultDelegate) // Refresh
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    
    func removeContactForId(id:Int, delegate:ContactDeleteDelegate) {
        let filterQueryParams: [String: AnyObject] = ["filter": "contact_id=\(id)"]
        var calls = [RestCall]()
        calls.append(RestCall(url: kRestContactGroupRelationship, method: .DELETE, queryParams: filterQueryParams, body: nil))
        calls.append(RestCall(url: kRestContactDetail, method: .DELETE, queryParams: filterQueryParams, body: nil))
        calls.append(RestCall(url: kRestContact + "/\(id)", method: .DELETE, queryParams: nil, body: nil))
        
        restClient.callRestServiceChain(calls, index: 0) { restResult in
            dispatch_async(dispatch_get_main_queue()) {
                if restResult.bIsSuccess {
                    delegate.contactDeleteSuccess()
                }
                else {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    private func removeContactFromTableForId(id: Int, resultClosure: RestResultClosure) {
        restClient.callRestService(kRestContact + "/\(id)", method: .DELETE, queryParams: nil, body: nil, resultClosure: resultClosure)
    }
    private func removeContactRelationWithContactId(contactId: Int, resultClosure: RestResultClosure) {
        let queryParams: [String: AnyObject] = ["filter": "contact_id=\(contactId)"]
        restClient.callRestService(kRestContactGroupRelationship, method: .DELETE, queryParams: queryParams, body: nil, resultClosure: resultClosure)
    }
    private func removeContactInfoWithContactId(contactId: Int, resultClosure: RestResultClosure) {
        let queryParams: [String: AnyObject] = ["filter": "contact_id=\(contactId)"]
        restClient.callRestService(kRestContactDetail, method: .DELETE, queryParams: queryParams, body: nil, resultClosure: resultClosure)
    }
    
//    private func removeContactImageFolderWithContactId(contactId: NSNumber, success: SuccessClosure, failure: ErrorClosure) {
//        
//        // delete all files and folders in the target folder
//        let queryParams: [String: AnyObject] = ["force": "1"]
//        
//        callApiWithPath(Routing.ResourceFolder(folderPath: "\(contactId)").path, method: "DELETE", queryParams: queryParams, body: nil, headerParams: sessionHeaderParams, success: success, failure: failure)
//    }

    func addOrUpdateContact(contactRecord: ContactRecord, delegate: ContactUpdateDelegate) {
        let requestBody: JSON = ["resource" : [contactRecord.asJSON()]] // DreamFactory REST API body with {"resource" = [ { record }, ... ] }
        let methodType: HTTPMethod = contactRecord.isNew() ? .POST : .PATCH
        
        restClient.callRestService(kRestContact, method: methodType, queryParams: nil, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                if let resultArray = restResult.json?["resource"] as? JSONArray {
                    if resultArray.count == 1 {
                        if let idNum = resultArray[0]["id"] as? NSNumber {
                            self.getContact(idNum.integerValue, resultDelegate: delegate)
                        }
                    }
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }

    func addContact(contact: ContactRecord, toGroupId: Int, resultDelegate: ContactDetailDelegate) {
        let records: JSONArray = [["contact_group_id": toGroupId, "contact_id": contact.id]]
        let requestBody: [String: AnyObject] = ["resource": records]
        restClient.callRestService(kRestContactGroupRelationship, method: .POST, queryParams: nil, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                self.getContactDetails(contact.id, resultDelegate: resultDelegate) // Refresh
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }

    func addOrUpdateAddress(detailRecord: ContactDetailRecord, delegate: ContactDetailUpdateDelegate) {
        let requestBody: JSON = ["resource" : [detailRecord.asJSON()]] // DreamFactory REST API body with {"resource" = [ { record }, ... ] }
        let methodType: HTTPMethod = detailRecord.isNew() ? .POST : .PATCH

        restClient.callRestService(kRestContactDetail, method: methodType, queryParams: nil, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                dispatch_async(dispatch_get_main_queue()) {
                    delegate.dataAccessSuccess()
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    func removeAddressForId(id:Int, delegate: ContactDetailDeleteDelegate) {
        restClient.callRestService(kRestContactDetail + "/\(id)", method: .DELETE, queryParams: nil, body: nil) { restResult in
            if restResult.bIsSuccess {
                dispatch_async(dispatch_get_main_queue()) {
                    delegate.dataAccessSuccess()
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    
    private func getContactDetailsInfo(contactId:Int, resultDelegate: ContactDetailDelegate) {
        let queryParams = ["filter" : "contact_id=\(contactId)"]
        restClient.callRestService(kRestContactDetail, method: .GET, queryParams: queryParams, body: nil) { restResult in
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
        restClient.callRestService(kRestContactGroupRelationship, method: .GET, queryParams: queryParams, body: nil) { restResult in
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
        restClient.callRestService(kRestContactGroupRelationship, method: .GET, queryParams: queryParams, body: nil) { restResult in
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
        restClient.callRestService(kRestContact, method: .GET, queryParams: queryParams, body: nil) { restResult in
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
        restClient.callRestService(kRestGroup, method: .GET, queryParams: nil, body: nil) { restResult in
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
                    groups.sortInPlace({ (r1, r2) -> Bool in
                        r1.name < r2.name
                    })
                    self.allGroups = groups
                }
            }
            else {
                print("REST->Failed to get Groups")
            }
        }
    }
}








