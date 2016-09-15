/**
 # SNHTTPSessionManager.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation
import FutureKit
import SwiftyJSON

// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

/**
 `SNHTTPSessionManager` is a subclass of `SNURLSessionManager` with convenience methods for making HTTP requests. When a `baseURL` is provided, requests made with the `GET` / `POST` / et al. convenience methods can be made with relative paths.
 
 ## Subclassing Notes
 
 Developers targeting iOS 7 or Mac OS X 10.9 or later that deal extensively with a web service are encouraged to subclass `SNHTTPSessionManager`, providing a class method that returns a shared singleton object on which authentication and other configuration can be shared across the application.
 
 For developers targeting iOS 6 or Mac OS X 10.8 or earlier, `SNHTTPRequestOperationManager` may be used to similar effect.
 
 ## Methods to Override
 
 To change the behavior of all data task operation construction, which is also used in the `GET` / `POST` / et al. convenience methods, override `dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:`.
 
 ## Serialization
 
 Requests created by an HTTP client will contain default headers and encode parameters according to the `requestSerializer` property, which is an object conforming to `<SNURLRequestSerialization>`.
 
 Responses received from the server are automatically validated and serialized by the `responseSerializers` property, which is an object conforming to `<SNURLResponseSerialization>`
 
 ## URL Construction Using Relative Paths
 
 For HTTP convenience methods, the request serializer constructs URLs from the path relative to the `-baseURL`, using `NSURL +URLWithString:relativeToURL:`, when provided. If `baseURL` is `nil`, `path` needs to resolve to a valid `NSURL` object using `NSURL +URLWithString:`.
 
 Below are a few examples of how `baseURL` and relative paths interact:
 
 NSURL *baseURL = [NSURL URLWithString:@"http://example.com/v1/"];
 [NSURL URLWithString:@"foo" relativeToURL:baseURL];                  // http://example.com/v1/foo
 [NSURL URLWithString:@"foo?bar=baz" relativeToURL:baseURL];          // http://example.com/v1/foo?bar=baz
 [NSURL URLWithString:@"/foo" relativeToURL:baseURL];                 // http://example.com/foo
 [NSURL URLWithString:@"foo/" relativeToURL:baseURL];                 // http://example.com/v1/foo
 [NSURL URLWithString:@"/foo/" relativeToURL:baseURL];                // http://example.com/foo/
 [NSURL URLWithString:@"http://example2.com/" relativeToURL:baseURL]; // http://example2.com/
 
 Also important to note is that a trailing slash will be added to any `baseURL` without one. This would otherwise cause unexpected behavior when constructing URLs using paths without a leading slash.
 
 @warning Managers for background sessions must be owned for the duration of their use. This can be accomplished by creating an application-wide or shared singleton instance.
 - Parameter R: type of ResponseObject
 */

public typealias Parameters = [String:String]

open class SNHTTPSessionManager<T, RS : SNURLResponseSerializer> : SNURLSessionManager<T, RS> where T == RS.Element /*, NSSecureCoding, NSCopying*/ {

    /// The URL used to construct requests from relative paths in methods like `requestWithMethod:URLString:parameters:`, and the `GET` / `POST` / et al. convenience methods.  When a `baseURL` is provided, requests made with the `GET` / `POST` / et al. convenience methods can be made with relative paths.
    let baseURL: URL?
    
    /**
     Requests created with `requestWithMethod:URLString:parameters:` & `multipartFormRequestWithMethod:URLString:parameters:constructingBodyWithBlock:` are constructed with a set of default headers using a parameter serialization specified by this property. By default, this is set to an instance of `SNHTTPRequestSerializer`, which serializes query string parameters for `GET`, `HEAD`, and `DELETE` requests, or otherwise URL-form-encodes HTTP message bodies.
     
     */
    open var requestSerializer: SNHTTPRequestSerializer
    
    // MARK: Initialization
    
    /// Creates and returns an `SNHTTPSessionManager` object.
    //static func manager() -> SNHTTPSessionManager<T> {
    //    return SNHTTPSessionManager<T>()
    //}
    
    /**
     Initializes an `SNHTTPSessionManager` object with the specified base URL.
     
     - Parameter url: The base URL for the HTTP client.
     */
    public convenience init(baseURL: URL? = nil, rs: RS) {
        self.init(baseURL: baseURL, sessionConfiguration: nil, rs: rs)
    }
    
    public typealias ConverterBlock = (JSON) throws -> T
    /**
     Initializes an `SNHTTPSessionManager` object with the specified base URL.
     
     This is the designated initializer.
     
     - Parameter url: The base URL for the HTTP client.
     - Parameter configuration: The configuration used to create the managed session.
     */
    public init(baseURL:URL?, sessionConfiguration:URLSessionConfiguration?, rs: RS) {
        // Ensure terminal slash for baseURL path, so that NSURL +URLWithString:relativeToURL: works as expected
        if var url = baseURL {
            url = url.ensureTrailingSlash()
            self.baseURL = url;
        }
        else {
            self.baseURL = nil
        }
        
        self.requestSerializer = SNHTTPRequestSerializer.serializer()
        
        super.init(rs: rs)
        
        //self.responseSerializer = SNJSONResponseSerializer<T, RS>(converter: converter)
    }
    
    // MARK: Making HTTP Requests
    
    /**
     Creates and runs an `NSURLSessionDataTask` with a `GET` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     - Parameter downloadProgress: A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
     
     - seealso: dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler
     */
    open func GET(_ url: String, parameters:Parameters?, downloadProgress:ProgressBlock?) -> Future<T> {
        let rt = self.dataTaskWithHTTPMethod("GET",
                            url:url,
                            parameters:parameters,
                            body: nil,
                            uploadProgress:nil,
                            downloadProgress:downloadProgress)
        return rt
    }
    
    /**
     Creates and runs an `NSURLSessionDataTask` with a `HEAD` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     
     - seealso: dataTaskWithRequest:completionHandler:
     */
    open func HEAD(_ url: String, parameters:Parameters?)-> Future<T> {
        let rt = self.dataTaskWithHTTPMethod("HEAD",
                                             url:url,
                                             parameters:parameters,
                                             body: nil,
                                             uploadProgress:nil,
                                             downloadProgress:nil)
        return rt
    }
    
    /**
     Creates and runs an `NSURLSessionDataTask` with a `POST` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     - Parameter uploadProgress: A block object to be executed when the upload progress is updated. Note this block is called on the session queue, not the main queue.
     
     - seealso: -dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:
     */
    open func POST(_ url: String, parameters:Parameters?, body: Data?, uploadProgress:ProgressBlock?) -> Future<T> {
        let rt = self.dataTaskWithHTTPMethod("POST",
                                             url:url,
                                             parameters:parameters,
                                             body: body,
                                             uploadProgress:uploadProgress,
                                             downloadProgress:nil)
        return rt
    }
    
    /**
     Creates and runs an `NSURLSessionDataTask` with a multipart `POST` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     - Parameter block: A block that takes a single argument and appends data to the HTTP body. The block argument is an object adopting the `SNMultipartFormData` protocol.
     
     - seealso: -dataTaskWithRequest:completionHandler:
     */
    
    //DEPRECATED_ATTRIBUTE;
    //    func POST(url: String, parameters:P?, constructingBodyWithBlock:(nullable void (^)(id <SNMultipartFormData> formData))block
    
    typealias MultiPartMakerBlock = (SNMultipartFormData) -> Void
    /**
     Creates and runs an `NSURLSessionDataTask` with a multipart `POST` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     - Parameter block: A block that takes a single argument and appends data to the HTTP body. The block argument is an object adopting the `SNMultipartFormData` protocol.
     - Parameter uploadProgress: A block object to be executed when the upload progress is updated. Note this block is called on the session queue, not the main queue.
     
     - seealso: -dataTaskWithRequest:uploadProgress:downloadProgress:completionHandler:
     */
    //func POST(url: String, parameters:Parameters?, constructingBodyWithBlock:MultiPartMakerBlock?, uploadProgress:ProgressBlock?) -> Future<T> {
    //
    //}
    
    /**
     Creates and runs an `NSURLSessionDataTask` with a `PUT` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     
     - seealso: -dataTaskWithRequest:completionHandler:
     */
    open func PUT(_ url: String, parameters:Parameters?) -> Future<T> {
        let rt = self.dataTaskWithHTTPMethod("PUT",
                                             url:url,
                                             parameters:parameters,
                                             body: nil,
                                             uploadProgress:nil,
                                             downloadProgress:nil)
        return rt
    }
    
    /**
     Creates and runs an `NSURLSessionDataTask` with a `PATCH` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     
     - seealso: -dataTaskWithRequest:completionHandler:
     */
    open func PATCH(_ url: String, parameters:Parameters?) -> Future<T> {
        let rt = self.dataTaskWithHTTPMethod("PATCH",
                                             url:url,
                                             parameters:parameters,
                                             body: nil,
                                             uploadProgress:nil,
                                             downloadProgress:nil)
        return rt
    }
    
    /**
     Creates and runs an `NSURLSessionDataTask` with a `DELETE` request.
     
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded according to the client request serializer.
     
     - seealso: -dataTaskWithRequest:completionHandler:
     */
    open func DELETE(_ url: String, parameters:Parameters?) -> Future<T> {
        let rt = self.dataTaskWithHTTPMethod("DELETE",
                                             url:url,
                                             parameters:parameters,
                                             body: nil,
                                             uploadProgress:nil,
                                             downloadProgress:nil)
        return rt
    }
    
    open func dataTaskWithHTTPMethod(_ method: String, url:String, parameters:Parameters?, body: Data?, uploadProgress:ProgressBlock?, downloadProgress:ProgressBlock?) -> Future<T> {
        do {
            let urlString = URL(string: url, relativeTo:self.baseURL)!.absoluteString
            
            let request = try self.requestSerializer.requestWithMethod(method, URLString:urlString, parameters:parameters, body: body)
            
            let f = self.dataTaskWithRequest(request,
                                                uploadProgress:uploadProgress,
                                                downloadProgress:downloadProgress)
            
            return f
        }
        catch {
            return Future<T>(fail: error)
        }
    }
}
