//
//  GroupRecord.swift
//  SampleAppSwift
//
//  Created by Timur Umayev on 1/4/16.
//  Copyright © 2016 dreamfactory. All rights reserved.
//
//  Refactored by Eric Elfner 2016-05-04

import UIKit

class GroupRecord {
    let id: Int
    var name: String
    
    init?(json: JSON) {
        if let _id = json["id"] as? NSNumber,
            let _name = json["name"] as? String {
            id = _id.intValue
            name = _name
        }
        else {
            return nil
        }
    }
}
