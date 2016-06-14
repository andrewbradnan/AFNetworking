/**
 # SFURLRequestSerializer.swift
 ##  AFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

import Foundation

public enum SFHTTPRequestQueryStringSerializationStyle {
    case Default
}

protocol SFURLRequestSerializer {

    /**
     Returns a request with the specified parameters encoded into a copy of the original request.
     
     - parameter request: The original request.
     - parameter parameters: The parameters to be encoded.
     
     - returns: A serialized request.
     */
    func requestBySerializingRequest(request: NSURLRequest, withParameters:Parameters?) throws -> NSURLRequest
}

