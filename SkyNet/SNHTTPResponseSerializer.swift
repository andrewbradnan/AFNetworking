/**
 # SNHTTPResponseSerializer.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/7/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation

/**
 `SNHTTPResponseSerializer` conforms to the `SNURLRequestSerialization` & `SNURLResponseSerialization` protocols, offering a concrete base implementation of query string / URL form-encoded parameter serialization and default request headers, as well as response status code and content type validation.
 
 Any request or response serializer dealing with HTTP is encouraged to subclass `SNHTTPResponseSerializer` in order to ensure consistent default behavior.
 */
open class SNHTTPResponseSerializer<T> : SNURLResponseSerializer  {
    public typealias Element = T
    
    typealias ConverterBlock = (Data) throws -> T
    
    var converter: ConverterBlock
    
    init(converter: @escaping ConverterBlock) {
        self.converter = converter
        for sc in 200..<300 {
            self.acceptableStatusCodes.insert(sc)
        }
    }
    
    /**
     The string encoding used to serialize data received from the server, when no string encoding is specified by the response. `NSUTF8StringEncoding` by default.
     */
    let stringEncoding: String.Encoding = String.Encoding.utf8
    
    /// Creates and returns a serializer with default configuration.
    //public static func serializer() -> SNHTTPResponseSerializer { return SNHTTPResponseSerializer() }
    
    // MARK: Configuring Response Serialization
    
    /**
     The acceptable HTTP status codes for responses. When non-`nil`, responses with status codes not contained by the set will result in an error during validation.
     
     See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
     */
    open var acceptableStatusCodes = Set<Int>()
    
    /**
     The acceptable MIME types for responses. When non-`nil`, responses with a `Content-Type` with MIME types that do not intersect with the set will result in an error during validation.
     */
    open var acceptableContentTypes: Set<String> = []
    
    open func responseObjectForResponse(_ response: URLResponse, data: Data) throws -> T {
        
        return try converter(data)
    }
}
