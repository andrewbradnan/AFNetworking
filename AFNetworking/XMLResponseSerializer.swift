/**
 # XMLResponseSerializer.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/28/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation
import SWXMLHash

/**
 `XMLResponseSerializer` is a subclass of `SFHTTPResponseSerializer` that validates and decodes XML responses.
 
 By default, `XMLResponseSerializer` accepts the following MIME types, which includes the official standard, `application/json`, as well as other commonly-used types:
 
 - `text/xml`
 */
public class XMLResponseSerializer<T> : SFHTTPResponseSerializer<NSData> {
    
    public typealias Converter = XMLIndexer throws -> T
    
    public init(converter: Converter) {
        self.xmlConverter = converter
        super.init(converter: { return $0 })
        self.acceptableContentTypes = ["text/xml"]
    }
    
    var xmlConverter: Converter
    
    // MARK: SFURLResponseSerialization
    func responseObjectForResponse(response: NSURLResponse, data:NSData) throws -> T {
        // check status codes
        if let http = response as? NSHTTPURLResponse {
            let sc = http.statusCode
            if !self.acceptableStatusCodes.contains(sc) {
                throw SFError.FailedResponse(sc, String(data: data, encoding: NSUTF8StringEncoding) ?? "Could not decode error response.")
            }
            
            self.checkContentType(http)
        }
        
        let xml = SWXMLHash.parse(data)
        return try xmlConverter(xml)
    }
}
