/**
 # SNResponseSerializer.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/7/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation

/**
 The `SNURLResponseSerialization` protocol is adopted by an object that decodes data into a more useful object representation, according to details in the server response. Response serializers may additionally perform validation on the incoming response and data.
 
 For example, a JSON response serializer may check for an acceptable status code (`2XX` range) and content type (`application/json`), decoding a valid JSON response into an object.
 */
public protocol SNURLResponseSerializer /* <NSObject, NSSecureCoding, NSCopying> */ {
    associatedtype Element
    
    /**
     The acceptable HTTP status codes for responses. When non-`nil`, responses with status codes not contained by the set will result in an error during validation.
     
     See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
     */
    var acceptableStatusCodes : Set<Int> { get }
    
    /**
     The acceptable MIME types for responses. When non-`nil`, responses with a `Content-Type` with MIME types that do not intersect with the set will result in an error during validation.
     */
    var acceptableContentTypes : Set<String> { get }
    

    /**
     The response object decoded from the data associated with a specified response.
     
     - Parameter response: The response to be processed.
     - Parameter data: The response data to be decoded.
     - Parameter error: The error that occurred while attempting to decode the response data.
     
     - Returns: The object decoded from the specified response data.
     */
    func responseObjectForResponse(_ response: URLResponse, data:Data) throws -> Element
}

extension SNURLResponseSerializer {
    public func checkContentType(_ response: HTTPURLResponse) {
        if let ct = response.allHeaderFields["Content-Type" as NSObject] as? String {
            if !self.acceptableContentTypes.contains(ct) {
                fatalError("bad type")
            }
        }
    }

    public func checkStatus(_ response: HTTPURLResponse, data: Data) throws {
        let sc = response.statusCode
        if !self.acceptableStatusCodes.contains(sc) {
            throw SNError.failedResponse(sc, String(data: data, encoding: String.Encoding.utf8) ?? "Could not decode error response.")
        }
    }
}


