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

private let kApiKey = "8047af4ebcc748e5cb49db3bc75349d2f798151468feb28ed70eab943567a6b2"
let kBaseInstanceUrl = "https://ft-ericdf.oraclecloud2.dreamfactory.com/api/v2"
private let kRestContact = "/db/_table/contact"
private let kRestContactGroupRelationship = "/db/_table/contact_group_relationship"
private let kRestGroup = "/db/_table/contact_group"
private let kRestContactDetail = "/db/_table/contact_info"

typealias GetContactsHandler = ([String], NSError?)->Void

protocol RegistrationDelegate {
    func userIsRegisteredSuccess(_ bSignedIn:Bool, message:String?)
}
protocol SignInDelegate {
    func userIsSignedInSuccess(_ bSignedIn:Bool, message:String?)
    func userIsSignedOut()
}
protocol ContactsDelegate {
    func setContacts(_ contacts:[ContactRecord])
    func dataAccessError(_ error:NSError?)
}
protocol ContactUpdateDelegate {
    func setContact(_ contact:ContactRecord)
    func dataAccessError(_ error:NSError?)
}
protocol ContactDeleteDelegate {
    func contactDeleteSuccess()
    func dataAccessError(_ error:NSError?)
}
protocol ContactDetailDelegate {
    func setContactGroups(_ groups: [GroupRecord])
    func setContactDetails(_ details: [ContactDetailRecord])
    func dataAccessError(_ error:NSError?)
}
protocol ContactDetailUpdateDelegate {
    func dataAccessSuccess()
    func dataAccessError(_ error:NSError?)
}
protocol ContactDetailDeleteDelegate {
    func dataAccessSuccess()
    func dataAccessError(_ error:NSError?)
}
class DataAccess {
    static let sharedInstance = DataAccess()
    fileprivate(set) var allGroups = [GroupRecord]() // Groups will be cached here.
    
    var currentGroupID: NSNumber? = nil
    fileprivate var restClient = RESTClient(apiKey: kApiKey, instanceUrl: kBaseInstanceUrl)
    
    func isSignedIn() -> Bool {
        return restClient.isSignedIn
    }
    func signedInUser() -> String? {
        return restClient.sessionEmail
    }
    func registerWithEmail(_ email:String, password:String, registrationDelegate: RegistrationDelegate) {
        restClient.registerWithEmail(email, password: password) { (bSuccess, message) in
            DispatchQueue.main.async {
                registrationDelegate.userIsRegisteredSuccess(bSuccess, message: message)
            }
        }
    }
    func signInWithEmail(_ email:String, password:String, signInDelegate: SignInDelegate) {
        restClient.signInWithEmail(email, password: password) { (bSignedIn, message) in
            DispatchQueue.main.async {
                if bSignedIn {
                    self.getAllGroups()
                }
                signInDelegate.userIsSignedInSuccess(bSignedIn, message: message)
            }
        }
    }
    func signOut(_ signInDelegate: SignInDelegate) {
        restClient.signOut()
        DispatchQueue.main.async {
            signInDelegate.userIsSignedOut()
        }
    }
    
    func getContact(_ id:Int, resultDelegate: ContactUpdateDelegate) {
        restClient.callRestService(kRestContact + "/\(id)", method: .GET, queryParams: nil, body: nil) { restResult in
            var contact:ContactRecord?
            if restResult.bIsSuccess {
                if let contactJson = restResult.json {
                    contact = ContactRecord(json:contactJson)
                }
            }
            if let contact = contact {
                DispatchQueue.main.async {
                    resultDelegate.setContact(contact)
                }
            }
            else {
                let error = restResult.error ?? NSError(domain: "DreamFactory API", code: 500, userInfo: [NSLocalizedDescriptionKey : "Could not create Contact from API result."])
                DispatchQueue.main.async {
                    resultDelegate.dataAccessError(error)
                }
            }
        }
    }
    
    func getContacts(_ group:GroupRecord?, resultDelegate: ContactsDelegate) {
        if let groupId = group?.id {
            getContactsForGroup(NSNumber.init(value: groupId), resultDelegate: resultDelegate)
        }
        else {
            getContactsAll(resultDelegate)
        }
    }
    
    func getContactDetails(_ contactId:Int, resultDelegate: ContactDetailDelegate) {
        getContactDetailsInfo(contactId, resultDelegate: resultDelegate)
        getContactDetailsGroups(contactId, resultDelegate: resultDelegate)
    }
    
    func removeContact(_ contact: ContactRecord, fromGroupId: Int, resultDelegate: ContactDetailDelegate) {
        // Do not have the ID of the record to remove, but can set id_field and remove with those.
        let queryParams: [String: String] = ["id_field": "contact_group_id,contact_id"]
        let records: JSONArray = [["contact_group_id": fromGroupId as AnyObject, "contact_id": contact.id as AnyObject]]
        let requestBody = ["resource": records] as AnyObject

        restClient.callRestService(kRestContactGroupRelationship, method: .DELETE, queryParams: queryParams, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                self.getContactDetails(contact.id, resultDelegate: resultDelegate) // Refresh
            }
            else {
                DispatchQueue.main.async {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    
    func removeContactForId(_ id:Int, delegate:ContactDeleteDelegate) {
        let filterQueryParams: [String: String] = ["filter": "contact_id=\(id)"]
        var calls = [RestCall]()
        calls.append(RestCall(url: kRestContactGroupRelationship, method: .DELETE, queryParams: filterQueryParams, body: nil))
        calls.append(RestCall(url: kRestContactDetail, method: .DELETE, queryParams: filterQueryParams, body: nil))
        calls.append(RestCall(url: kRestContact + "/\(id)", method: .DELETE, queryParams: nil, body: nil))
        
        restClient.callRestServiceChain(calls, index: 0) { restResult in
            DispatchQueue.main.async {
                if restResult.bIsSuccess {
                    delegate.contactDeleteSuccess()
                }
                else {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    fileprivate func removeContactFromTableForId(_ id: Int, resultClosure: @escaping RestResultClosure) {
        restClient.callRestService(kRestContact + "/\(id)", method: .DELETE, queryParams: nil, body: nil, resultClosure: resultClosure)
    }
    fileprivate func removeContactRelationWithContactId(_ contactId: Int, resultClosure: @escaping RestResultClosure) {
        let queryParams: [String: String] = ["filter": "contact_id=\(contactId)"]
        restClient.callRestService(kRestContactGroupRelationship, method: .DELETE, queryParams: queryParams, body: nil, resultClosure: resultClosure)
    }
    fileprivate func removeContactInfoWithContactId(_ contactId: Int, resultClosure: @escaping RestResultClosure) {
        let queryParams: [String: String] = ["filter": "contact_id=\(contactId)"]
        restClient.callRestService(kRestContactDetail, method: .DELETE, queryParams: queryParams, body: nil, resultClosure: resultClosure)
    }
    
//    private func removeContactImageFolderWithContactId(contactId: NSNumber, success: SuccessClosure, failure: ErrorClosure) {
//        
//        // delete all files and folders in the target folder
//        let queryParams: [String: AnyObject] = ["force": "1"]
//        
//        callApiWithPath(Routing.ResourceFolder(folderPath: "\(contactId)").path, method: "DELETE", queryParams: queryParams, body: nil, headerParams: sessionHeaderParams, success: success, failure: failure)
//    }

    func addOrUpdateContact(_ contactRecord: ContactRecord, delegate: ContactUpdateDelegate) {
        let requestBody = ["resource" : [contactRecord.asJSON()]] as AnyObject // DreamFactory REST API body with {"resource" = [ { record }, ... ] }
        let methodType: HTTPMethod = contactRecord.isNew() ? .POST : .PATCH
        
        restClient.callRestService(kRestContact, method: methodType, queryParams: nil, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                if let resultArray = restResult.json?["resource"] as? JSONArray {
                    if resultArray.count == 1 {
                        if let idNum = resultArray[0]["id"] as? NSNumber {
                            self.getContact(idNum.intValue, resultDelegate: delegate)
                        }
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }

    func addContact(_ contact: ContactRecord, toGroupId: Int, resultDelegate: ContactDetailDelegate) {
        let records: JSONArray = [["contact_group_id": toGroupId as AnyObject, "contact_id": contact.id as AnyObject]]
        let requestBody = ["resource": records as AnyObject] as AnyObject
        restClient.callRestService(kRestContactGroupRelationship, method: .POST, queryParams: nil, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                self.getContactDetails(contact.id, resultDelegate: resultDelegate) // Refresh
            }
            else {
                DispatchQueue.main.async {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }

    func addOrUpdateAddress(_ detailRecord: ContactDetailRecord, delegate: ContactDetailUpdateDelegate) {
        let requestBody = ["resource" : [detailRecord.asJSON()]] as AnyObject  // DreamFactory REST API body with {"resource" = [ { record }, ... ] }
        let methodType: HTTPMethod = detailRecord.isNew() ? .POST : .PATCH

        restClient.callRestService(kRestContactDetail, method: methodType, queryParams: nil, body: requestBody) { restResult in
            if restResult.bIsSuccess {
                DispatchQueue.main.async {
                    delegate.dataAccessSuccess()
                }
            }
            else {
                DispatchQueue.main.async {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    func removeAddressForId(_ id:Int, delegate: ContactDetailDeleteDelegate) {
        restClient.callRestService(kRestContactDetail + "/\(id)", method: .DELETE, queryParams: nil, body: nil) { restResult in
            if restResult.bIsSuccess {
                DispatchQueue.main.async {
                    delegate.dataAccessSuccess()
                }
            }
            else {
                DispatchQueue.main.async {
                    delegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    
    fileprivate func getContactDetailsInfo(_ contactId:Int, resultDelegate: ContactDetailDelegate) {
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
                DispatchQueue.main.async {
                    resultDelegate.setContactDetails(details)
                }
            }
            else {
                DispatchQueue.main.async {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    
    fileprivate func getContactDetailsGroups(_ contactId:Int, resultDelegate: ContactDetailDelegate) {
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
                groups.sort(by: { (r1, r2) -> Bool in
                    return r1.name < r2.name
                })
                DispatchQueue.main.async {
                    resultDelegate.setContactGroups(groups)
                }
            }
            else {
                DispatchQueue.main.async {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    
    // Must query relationship table and specify to return the related contact data.
    // Sorting cannot be done through REST call.
    fileprivate func getContactsForGroup(_ groupID: NSNumber, resultDelegate: ContactsDelegate) {
        let queryParams = ["related" : "contact_by_contact_id", "filter" : "contact_group_id=\(groupID.int32Value)"]
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
                contacts.sort(by: { (r1, r2) -> Bool in
                    return r1.fullName < r2.fullName
                })
                DispatchQueue.main.async {
                    resultDelegate.setContacts(contacts)
                }
            }
            else {
                DispatchQueue.main.async {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }

    fileprivate func getContactsAll(_ resultDelegate: ContactsDelegate) {
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
                DispatchQueue.main.async {
                    resultDelegate.setContacts(contacts)
                }
            }
            else {
                DispatchQueue.main.async {
                    resultDelegate.dataAccessError(restResult.error)
                }
            }
        }
    }
    
    fileprivate func getAllGroups() {
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
                DispatchQueue.main.async {
                    groups.sort(by: { (r1, r2) -> Bool in
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








