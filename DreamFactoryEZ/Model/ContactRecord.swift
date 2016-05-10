//
//  ContactRecord.swift
//  SampleAppSwift
//
//  Created by Timur Umayev on 1/4/16.
//  Copyright © 2016 dreamfactory. All rights reserved.
//
//  Refactored by Eric Elfner 2016-05-04

import UIKit

class ContactRecord: Equatable {
    var id: NSNumber
    var firstName: String
    var lastName: String
    var notes: String
    var skype: String
    var twitter: String
    var imageURL: String?
    
    var fullName: String {
        return "\(lastName), \(firstName)"
    }
    
    init?(json: JSON) {
        if let _id = json["id"] as? NSNumber {
            id = _id
            firstName = json.stringValue("first_name")
            lastName = json.stringValue("last_name")
            notes = json.stringValue("notes")
            skype = json.stringValue("skype")
            twitter = json.stringValue("twitter")
            imageURL = json["image_url"] as? String
        }
        else {
            return nil
        }
    }
    static func fromJsonArray(jsonArray:JSONArray)->[ContactRecord] {
        var contacts = [ContactRecord]()
        for json in jsonArray {
            if let contact = ContactRecord(json: json) {
                contacts.append(contact)
            }
        }
        return contacts
    }

}

func ==(lhs: ContactRecord, rhs: ContactRecord) -> Bool {
    return lhs.id.isEqualToNumber(rhs.id)
}
