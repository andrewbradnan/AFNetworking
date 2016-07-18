/**
 # SNURLRequestSerializer.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation

public enum SNHTTPRequestQueryStringSerializationStyle {
    case Default
}

protocol SNURLRequestSerializer {

    /**
     Returns a request with the specified parameters encoded into a copy of the original request.
     
     - parameter request: The original request.
     - parameter parameters: The parameters to be encoded.
     
     - returns: A serialized request.
     */
    func requestBySerializingRequest(request: NSURLRequest, withParameters:Parameters?, body: NSData?) throws -> NSMutableURLRequest
}
