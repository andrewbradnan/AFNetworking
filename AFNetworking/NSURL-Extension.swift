/**
 # NSURL-Extension.swift
 ##  AFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/5/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

import Foundation

extension NSURL {
    func ensureTrailingSlash() -> NSURL {
        if self.path.length > 0 && !self.absoluteString.hasSuffix("/") {
            return self.URLByAppendingPathComponent("")
        }
        return self
    }
    
}