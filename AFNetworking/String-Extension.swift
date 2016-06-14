/**
 # String-Extension.swift
 ##  AFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/5/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

import Foundation

extension String {
    static func isNotEmpty(s: String?) -> Bool {
        return !(s?.isEmpty ?? true)
    }
}