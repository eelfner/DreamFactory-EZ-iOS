//
//  ContactDetailRecord.swift
//  SampleAppSwift
//
//  Created by Timur Umayev on 1/4/16.
//  Copyright © 2016 dreamfactory. All rights reserved.
//
//  Refactored by Eric Elfner 2016-05-04

import UIKit

class ContactDetailRecord: CustomStringConvertible {
    var id: Int
    var contactId: Int
    var type: String
    var phone: String
    var email: String
    var state: String
    var zipCode: String
    var country: String
    var city: String
    var address: String
    
    var description: String {
        var d = ""
        
        if phone != "" { d += phone + "\n" }
        if email != "" { d += email + "\n" }
        if address != "" { d += address + "\n" }
        if city != "" || state != "" || zipCode != "" { d += "\(city), \(state) \(zipCode)\n" }
        if country != "" {d += country + "\n" }
        
        if d.hasSuffix("\n") {
            d = d.substring(to: d.characters.index(before: d.endIndex))
        }
        return d
    }
    init(contactId:Int) {
        id = -1
        self.contactId = contactId
        type = "Work"
        phone = ""
        email = ""
        state = ""
        zipCode = ""
        country = ""
        city = ""
        address = ""
    }
    init?(json: JSON) {
        if let _id = json["id"] as? NSNumber,
         let _contactId = json["contact_id"] as? NSNumber {
            id = _id.intValue
            contactId = _contactId.intValue
            
            type = json.stringValue("info_type").uppercased()
            phone = json.stringValue("phone")
            email = json.stringValue("email")
            country = json.stringValue("country")
            state = json.stringValue("state")
            zipCode = json.stringValue("zip")
            country = json.stringValue("country")
            city = json.stringValue("city")
            address = json.stringValue("address")
        }
        else {
            return nil
        }
    }
    func asJSON() -> JSON {
        var json = JSON()
        if !isNew() {
            json["id"] = id as AnyObject
        }
        json["contact_id"] = contactId as AnyObject
        json["info_type"] = type.lowercased() as AnyObject
        json["phone"] = phone as AnyObject
        json["email"] = email as AnyObject
        json["address"] = address as AnyObject
        json["city"] = city as AnyObject
        json["state"] = state as AnyObject
        json["city"] = city as AnyObject
        json["zip"] = zipCode as AnyObject
        json["country"] = country as AnyObject

        return json
    }
    func isNew() -> Bool {
        return id == -1
    }
}
