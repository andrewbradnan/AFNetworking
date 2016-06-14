/**
 # NSURLRequest-Extension.swift
 ##  SFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/13/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

import Foundation

extension NSURLRequest {
    var mutableRequest: NSMutableURLRequest? {
        get {
            guard let url = self.URL else {return nil }
            
            let rt = NSMutableURLRequest(URL: url,
                                cachePolicy: self.cachePolicy,
                                timeoutInterval: self.timeoutInterval)
            return rt
        }
    }
}