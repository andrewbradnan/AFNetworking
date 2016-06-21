/**
 # SFResponseSerializer.swift
 ##  SFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/7/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

import Foundation

/**
 The `SFURLResponseSerialization` protocol is adopted by an object that decodes data into a more useful object representation, according to details in the server response. Response serializers may additionally perform validation on the incoming response and data.
 
 For example, a JSON response serializer may check for an acceptable status code (`2XX` range) and content type (`application/json`), decoding a valid JSON response into an object.
 */
public protocol SFURLResponseSerializer /* <NSObject, NSSecureCoding, NSCopying> */ {
    associatedtype Element
    
    /**
     The response object decoded from the data associated with a specified response.
     
     - Parameter response: The response to be processed.
     - Parameter data: The response data to be decoded.
     - Parameter error: The error that occurred while attempting to decode the response data.
     
     - Returns: The object decoded from the specified response data.
     */
    func responseObjectForResponse(response: NSURLResponse, data:NSData) throws -> Element
}


