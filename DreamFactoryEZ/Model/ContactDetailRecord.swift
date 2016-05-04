//
//  ContactDetailRecord.swift
//  SampleAppSwift
//
//  Created by Timur Umayev on 1/4/16.
//  Copyright © 2016 dreamfactory. All rights reserved.
//  Refactored by Eric Elfner 2016-05-04

import UIKit

class ContactDetailRecord {
    var id: NSNumber
    var contactId: NSNumber
    var type: String
    var phone: String
    var email: String
    var state: String
    var zipCode: String
    var country: String
    var city: String
    var address: String
    
    init?(json: JSON) {
        if let _id = json["id"] as? NSNumber,
         let _contactId = json["contact_id"] as? NSNumber {
            id = _id
            contactId = _contactId
            
            type = json.stringValue("type")
            phone = json.stringValue("phone")
            email = json.stringValue("email")
            country = json.stringValue("country")
            state = json.stringValue("state")
            zipCode = json.stringValue("state")
            country = json.stringValue("country")
            city = json.stringValue("city")
            address = json.stringValue("address")
        }
        else {
            return nil
        }
    }
}
