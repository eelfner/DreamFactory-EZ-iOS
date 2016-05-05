//
//  JSON.swift
//  DreamFactoryEZ
//
//  Created by Eric Elfner on 2016-05-04.
//  Copyright © 2016 Eric Elfner. All rights reserved.
//
// Basic helpers for JSON. Would recommend using SwiftyJSON, but this project is built for no 3rd party requirements.

import Foundation

typealias JSON = [String: AnyObject]
typealias JSONArray = [JSON]

extension Dictionary {
    func stringValue(key: Key) -> String {
        let value = (self[key] as? String) ?? ""
        return value
    }
}
extension String {
    
    /** Percent escape value to be added to a URL query value as specified in RFC 3986
     - Returns: Percent escaped string.
     */
    
    func stringByAddingPercentEncodingForURLQueryValue() -> String? {
        let characterSet = NSMutableCharacterSet.alphanumericCharacterSet()
        characterSet.addCharactersInString("-._~")
        
        return self.stringByAddingPercentEncodingWithAllowedCharacters(characterSet)
    }
}

extension Dictionary {
    
    /** Build string representation of HTTP parameter dictionary of keys and objects
     This percent escapes in compliance with RFC 3986
     - Returns: String representation in the form of key1=value1&key2=value2 where the keys and values are percent escaped
     */
    
    func stringFromHttpParameters() -> String {
        let parameterArray = self.map { (key, value) -> String in
            let percentEscapedKey = (key as! String).stringByAddingPercentEncodingForURLQueryValue()!
            let percentEscapedValue = (value as! String).stringByAddingPercentEncodingForURLQueryValue()!
            return "\(percentEscapedKey)=\(percentEscapedValue)"
        }
        
        return parameterArray.joinWithSeparator("&")
    }
}
