/**
 # NSURLRequest-Extension.swift
 ##  SFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/13/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

import Foundation

extension URLRequest {
    var mutableRequest: NSMutableURLRequest? {
        get {
            guard let url = self.url else {return nil }
            
            let rt = NSMutableURLRequest(url: url,
                                cachePolicy: self.cachePolicy,
                                timeoutInterval: self.timeoutInterval)

            if self.httpMethod != nil {
                rt.httpMethod = self.httpMethod!
            }
            
            return rt
        }
    }
}
