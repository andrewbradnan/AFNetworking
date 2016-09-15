/**
 # SNURLRequestSerializer.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation

public enum SNHTTPRequestQueryStringSerializationStyle {
    case `default`
}

protocol SNURLRequestSerializer {

    /**
     Returns a request with the specified parameters encoded into a copy of the original request.
     
     - parameter request: The original request.
     - parameter parameters: The parameters to be encoded.
     
     - returns: A serialized request.
     */
    func requestBySerializingRequest(_ request: URLRequest, withParameters:Parameters?, body: Data?) throws -> NSMutableURLRequest
}

