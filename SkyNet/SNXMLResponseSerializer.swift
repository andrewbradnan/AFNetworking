/**
 # SNXMLResponseSerializer.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/28/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation
import SWXMLHash

/**
 `XMLResponseSerializer` is a subclass of `SNHTTPResponseSerializer` that validates and decodes XML responses.
 
 By default, `XMLResponseSerializer` accepts the following MIME types, which includes the official standard, `application/json`, as well as other commonly-used types:
 
 - `text/xml`
 */
public class SNXMLResponseSerializer<T> : SNURLResponseSerializer {
    public typealias Element = T
    public typealias Converter = XMLIndexer throws -> T
    
    /**
     The acceptable HTTP status codes for responses. When non-`nil`, responses with status codes not contained by the set will result in an error during validation.
     
     See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
     */
    public var acceptableStatusCodes = Set<Int>()
    
    /**
     The acceptable MIME types for responses. When non-`nil`, responses with a `Content-Type` with MIME types that do not intersect with the set will result in an error during validation.
     */
    public var acceptableContentTypes: Set<String> = []
    

    public init(converter: Converter) {
        self.xmlConverter = converter
        self.acceptableContentTypes = ["text/xml"]
        for sc in 200..<300 {
            self.acceptableStatusCodes.insert(sc)
        }
    }
    
    var xmlConverter: Converter
    
    // MARK: SNURLResponseSerialization
    public func responseObjectForResponse(response: NSURLResponse, data:NSData) throws -> T {
        // check status codes
        if let http = response as? NSHTTPURLResponse {
            try self.checkStatus(http, data:data)
            self.checkContentType(http)
        }
        
        let xml = SWXMLHash.parse(data)
        return try xmlConverter(xml)
    }
}
