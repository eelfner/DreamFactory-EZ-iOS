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
    var id: Int
    var firstName: String
    var lastName: String
    var notes: String
    var skype: String
    var twitter: String
    var imageURL: String?
    
    var fullName: String {
        return "\(lastName), \(firstName)"
    }
    init() {
        id = -1
        firstName = ""
        lastName = ""
        notes = ""
        skype = ""
        twitter = ""
    }
    init?(json: JSON) {
        if let _id = json["id"] as? NSNumber {
            id = _id.intValue
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
    static func fromJsonArray(_ jsonArray:JSONArray)->[ContactRecord] {
        var contacts = [ContactRecord]()
        for json in jsonArray {
            if let contact = ContactRecord(json: json) {
                contacts.append(contact)
            }
        }
        return contacts
    }
    func asJSON() -> JSON {
        var json = ["id": id as AnyObject,
                    "first_name": firstName as AnyObject,
                    "last_name": lastName as AnyObject,
                    "notes": notes as AnyObject,
                    "skype": skype as AnyObject,
                    "twitter": twitter as AnyObject] as JSON
        if let imageURL = imageURL {
            json["image_url"] = imageURL as AnyObject?
        }
        if isNew() {
            json.removeValue(forKey: "id")
        }
        return json
    }
    func isNew() -> Bool {
        return id == -1
    }

}

func ==(lhs: ContactRecord, rhs: ContactRecord) -> Bool {
    return lhs.id == rhs.id
}
