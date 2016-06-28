/**
 # SFJSONResponseSerializer.swift
## SFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/14/16
 - Copyright: Copyright © 2016 SFNetworking. All rights reserved.
 */

import Foundation
import SwiftyJSON
//import SWXMLHash

/**
 `SFJSONResponseSerializer` is a subclass of `SFHTTPResponseSerializer` that validates and decodes JSON responses.
 
 By default, `SFJSONResponseSerializer` accepts the following MIME types, which includes the official standard, `application/json`, as well as other commonly-used types:
 
 - `application/json`
 - `text/json`
 - `text/javascript`
 */
class SFJSONResponseSerializer<T> : SFURLResponseSerializer {
    typealias Element = T
    typealias JSONConverter = JSON throws -> T
    
    init(converter: JSON throws -> T) {
        self.jsonConverter = converter
//        self.acceptableContentTypes = ["application/json", "text/json", "text/javascript"]
    }

    var jsonConverter: JSONConverter
    
    /**
     Options for reading the response JSON data and creating the Foundation objects. For possible values, see the `NSJSONSerialization` documentation section "NSJSONReadingOptions".
     */
    var readingOptions = NSJSONReadingOptions()

    /// Whether to remove keys with `NSNull` values from response JSON. Defaults to `NO`.
    var removesKeysWithNullValues = false

    /**
     Creates and returns a JSON serializer with specified reading and writing options.
 
     - Parameter readingOptions: The specified JSON reading options.
     */
    static func serializerWithReadingOptions(readingOptions: NSJSONReadingOptions, converter: JSONConverter) -> SFJSONResponseSerializer {
        let serializer = SFJSONResponseSerializer(converter: converter)
        serializer.readingOptions = readingOptions
        
        return serializer
    }
    
    // MARK: SFURLResponseSerialization
    func responseObjectForResponse(response: NSURLResponse, data:NSData) throws -> T {
        // check status codes
//        if let http = response as? NSHTTPURLResponse {
//            let sc = http.statusCode
//            if !self.acceptableStatusCodes.contains(sc) {
//                throw SFError.FailedResponse(sc, String(data: data, encoding: NSUTF8StringEncoding) ?? "Could not decode error response.")
//            }
//
//            self.checkContentType(http)
//        }
        
        return try jsonConverter(JSON(data: data))
    }
}

/*
func SFJSONObjectByRemovingKeysWithNullValues(JSONObject: AnyObject, readingOptions: NSJSONReadingOptions) {
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