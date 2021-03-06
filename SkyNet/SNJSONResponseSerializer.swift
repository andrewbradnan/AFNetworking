/**
 # SNJSONResponseSerializer.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/14/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation
import SwiftyJSON

/**
 `SNJSONResponseSerializer` is a subclass of `SNHTTPResponseSerializer` that validates and decodes JSON responses.
 
 By default, `SNJSONResponseSerializer` accepts the following MIME types, which includes the official standard, `application/json`, as well as other commonly-used types:
 
 - `application/json`
 - `text/json`
 - `text/javascript`
 */
open class SNJSONResponseSerializer<T> : SNURLResponseSerializer {
    public typealias Element = T
    typealias JSONConverter = (JSON) throws -> T
    
    /**
     The acceptable HTTP status codes for responses. When non-`nil`, responses with status codes not contained by the set will result in an error during validation.
     
     See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
     */
    open var acceptableStatusCodes = Set<Int>()
    
    /**
     The acceptable MIME types for responses. When non-`nil`, responses with a `Content-Type` with MIME types that do not intersect with the set will result in an error during validation.
     */
    open var acceptableContentTypes: Set<String> = []
    
    public init(converter: (JSON) throws -> T) {
        self.jsonConverter = converter
        self.acceptableContentTypes = ["application/json", "text/json", "text/javascript"]
    }

    var jsonConverter: JSONConverter
    
    /**
     Options for reading the response JSON data and creating the Foundation objects. For possible values, see the `NSJSONSerialization` documentation section "NSJSONReadingOptions".
     */
    var readingOptions = JSONSerialization.ReadingOptions()

    /// Whether to remove keys with `NSNull` values from response JSON. Defaults to `NO`.
    var removesKeysWithNullValues = false

    /**
     Creates and returns a JSON serializer with specified reading and writing options.
 
     - Parameter readingOptions: The specified JSON reading options.
     */
    static func serializerWithReadingOptions(_ readingOptions: JSONSerialization.ReadingOptions, converter: JSONConverter) -> SNJSONResponseSerializer {
        let serializer = SNJSONResponseSerializer(converter: converter)
        serializer.readingOptions = readingOptions
        
        return serializer
    }
    
    // MARK: SNURLResponseSerialization
    open func responseObjectForResponse(_ response: URLResponse, data:Data) throws -> T {
        // check status codes
        if let http = response as? HTTPURLResponse {
            try self.checkStatus(http, data: data)
            self.checkContentType(http)
        }
        
        return try jsonConverter(JSON(data: data))
    }
}

/*
func SNJSONObjectByRemovingKeysWithNullValues(JSONObject: AnyObject, readingOptions: NSJSONReadingOptions) {
    if JSONObject is Array {
        NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:[(NSArray *)JSONObject count]];
        for (id value in (NSArray *)JSONObject) {
            [mutableArray addObject:AFJSONObjectByRemovingKeysWithNullValues(value, readingOptions)];
        }
        
        return (readingOptions & NSJSONReadingMutableContainers) ? mutableArray : [NSArray arrayWithArray:mutableArray];
    } else if ([JSONObject isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:JSONObject];
        for (id <NSCopying> key in [(NSDictionary *)JSONObject allKeys]) {
            id value = (NSDictionary *)JSONObject[key];
            if (!value || [value isEqual:[NSNull null]]) {
                [mutableDictionary removeObjectForKey:key];
            } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                mutableDictionary[key] = AFJSONObjectByRemovingKeysWithNullValues(value, readingOptions);
            }
        }
        
        return (readingOptions & NSJSONReadingMutableContainers) ? mutableDictionary : [NSDictionary dictionaryWithDictionary:mutableDictionary];
    }
    
    return JSONObject;
}
*/
