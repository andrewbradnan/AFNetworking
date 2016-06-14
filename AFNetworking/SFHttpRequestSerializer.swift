/**
 # SFHttpRequestSerializer.swift
 ##  AFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

import Foundation

/**
 `SFHTTPRequestSerializer` conforms to the `SFURLRequestSerialization` & `SFURLResponseSerialization` protocols, offering a concrete base implementation of query string / URL form-encoded parameter serialization and default request headers, as well as response status code and content type validation.
 
 Any request or response serializer dealing with HTTP is encouraged to subclass `SFHTTPRequestSerializer` in order to ensure consistent default behavior.
 */

class SFHTTPRequestSerializer: SFURLRequestSerializer {
    
    typealias QueryStringSerializationBlock = (NSURLRequest, parameters: Parameters) throws -> String

    var queryStringSerializer: QueryStringSerializationBlock?
    
    /// The string encoding used to serialize parameters. `NSUTF8StringEncoding` by default.
    let stringEncoding = NSUTF8StringEncoding
    
    /**
     Whether created requests can use the device’s cellular radio (if present). `YES` by default.
     
     - Seealso: NSMutableURLRequest -setAllowsCellularAccess:
     */
    let allowsCellularAccess = true
    
    /**
     The cache policy of created requests. `NSURLRequestUseProtocolCachePolicy` by default.
     
     - Seealso: NSMutableURLRequest -setCachePolicy:
     */
    let cachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy
    
    /**
     Whether created requests should use the default cookie handling. `true` by default.
     
     - Seealso: NSMutableURLRequest -setHTTPShouldHandleCookies:
     */
    let HTTPShouldHandleCookies = true
    
    /**
     Whether created requests can continue transmitting data before receiving a response from an earlier transmission. `false` by default
     
     - Seealso: NSMutableURLRequest -setHTTPShouldUsePipelining:
     */
    let HTTPShouldUsePipelining = false
    
    /**
     The network service type for created requests. `NSURLNetworkServiceTypeDefault` by default.
     
     - Seealso: NSMutableURLRequest -setNetworkServiceType:
     */
    let networkServiceType = NSURLRequestNetworkServiceType.NetworkServiceTypeDefault
    
    /**
     The timeout interval, in seconds, for created requests. The default timeout interval is 60 seconds.
     
     - Seealso: NSMutableURLRequest -setTimeoutInterval:
     */
    let timeoutInterval = NSTimeInterval(60)
    
    // MARK: Configuring HTTP Request Headers
    
    /**
     Default HTTP header field values to be applied to serialized requests. By default, these include the following:
     
     - `Accept-Language` with the contents of `NSLocale +preferredLanguages`
     - `User-Agent` with the contents of various bundle identifiers and OS designations
     
     @discussion To add or remove default request headers, use `setValue:forHTTPHeaderField:`.
     */
    let HTTPRequestHeaders: Dictionary<String,String>
    
    
    init() {
        
    }
    
    /**
     Creates and returns a serializer with default configuration.
     */
    static func serializer() -> SFHTTPRequestSerializer{}
    
    /**
     Sets the value for the HTTP headers set in request objects made by the HTTP client. If `nil`, removes the existing value for that header.
     
     - Parameter field: The HTTP header to set a default value for
     - Parameter value: The value set as default for the specified header, or `nil`
     */
    // todo: make [] accessor
    func setValue(value: String?, forHTTPHeaderField:String){
        
    }
    
    /**
     Returns the value for the HTTP headers set in the request serializer.
     
     - Parameter field: The HTTP header to retrieve the default value for
     
     - Returns: The value set as default for the specified header, or `nil`
     */
    func valueForHTTPHeaderField(field: NSString) -> String? {
        
    }
    
    /**
     Sets the "Authorization" HTTP header set in request objects made by the HTTP client to a basic authentication value with Base64-encoded username and password. This overwrites any existing value for this header.
     
     - Parameter username: The HTTP basic auth username
     - Parameter password: The HTTP basic auth password
     */
    func setAuthorizationHeaderFieldWithUsername(username: String, password:String) {
        
    }
    
    /**
     Clears any existing value for the "Authorization" HTTP header.
     */
    func clearAuthorizationHeader() {
        
    }
    
    
    // MARK: Configuring Query String Parameter Serialization
    
    
    /**
     HTTP methods for which serialized requests will encode parameters as a query string. `GET`, `HEAD`, and `DELETE` by default.
     */
    let HTTPMethodsEncodingParametersInURI: Set<String>
    
    /**
     Set the method of query string serialization according to one of the pre-defined styles.
     
     - Parameter style: The serialization style.
     
     - Seealso: AFHTTPRequestQueryStringSerializationStyle
     */
    func setQueryStringSerializationWithStyle(style: SFHTTPRequestQueryStringSerializationStyle) {
        
    }
    
    //typealias QSEncoder = NSURLRequest, ) throws -> String
    /**
     Set the a custom method of query string serialization according to the specified block.
     
     - Parameter block: A block that defines a process of encoding parameters into a query string. This block returns the query string and takes three arguments: the request, the parameters to encode, and the error that occurred when attempting to encode parameters for the given request.
     */
    func setQueryStringSerializationWithBlock(encoder: (NSURLRequest, [String:String]) throws -> String) {
        
    }
    
    
    // MARK: Creating Request Objects
    
    
    /**
     Creates an `NSMutableURLRequest` object with the specified HTTP method and URL string.
     
     If the HTTP method is `GET`, `HEAD`, or `DELETE`, the parameters will be used to construct a url-encoded query string that is appended to the request's URL. Otherwise, the parameters will be encoded according to the value of the `parameterEncoding` property, and set as the request body.
     
     - Parameter method: The HTTP method for the request, such as `GET`, `POST`, `PUT`, or `DELETE`. This parameter must not be `nil`.
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be either set as a query string for `GET` requests, or the request HTTP body.
     - Parameter error: The error that occurred while constructing the request.
     
     - Returns: An `NSMutableURLRequest` object.
     */
    func requestWithMethod(method: String, URLString:String, parameters:[String:String]?) throws -> NSMutableURLRequest {
        
    }
    
    typealias MultipartMakerBlock = SFMultipartFormData->Void
    /**
     Creates an `NSMutableURLRequest` object with the specified HTTP method and URLString, and constructs a `multipart/form-data` HTTP body, using the specified parameters and multipart form data block. See http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.2
     
     Multipart form requests are automatically streamed, reading files directly from disk along with in-memory data in a single HTTP body. The resulting `NSMutableURLRequest` object has an `HTTPBodyStream` property, so refrain from setting `HTTPBodyStream` or `HTTPBody` on this request object, as it will clear out the multipart form body stream.
     
     - Parameter method: The HTTP method for the request. This parameter must not be `GET` or `HEAD`, or `nil`.
     - Parameter URLString: The URL string used to create the request URL.
     - Parameter parameters: The parameters to be encoded and set in the request HTTP body.
     - Parameter block: A block that takes a single argument and appends data to the HTTP body. The block argument is an object adopting the `AFMultipartFormData` protocol.
     - Parameter error: The error that occurred while constructing the request.
     
     - Returns: An `NSMutableURLRequest` object
     */
    func multipartFormRequestWithMethod(method: String, URLString:String, parameters:[String:String], constructingBodyWithBlock:MultipartMakerBlock?) throws -> NSMutableURLRequest {
        
    }
    
    typealias CompletionBlock = NSError?->Void
    /**
     Creates an `NSMutableURLRequest` by removing the `HTTPBodyStream` from a request, and asynchronously writing its contents into the specified file, invoking the completion handler when finished.
     
     - Parameter request: The multipart form request. The `HTTPBodyStream` property of `request` must not be `nil`.
     - Parameter fileURL: The file URL to write multipart form contents to.
     - Parameter handler: A handler block to execute.
     
     @discussion There is a bug in `NSURLSessionTask` that causes requests to not send a `Content-Length` header when streaming contents from an HTTP body, which is notably problematic when interacting with the Amazon S3 webservice. As a workaround, this method takes a request constructed with `multipartFormRequestWithMethod:URLString:parameters:constructingBodyWithBlock:error:`, or any other request with an `HTTPBodyStream`, writes the contents to the specified file and returns a copy of the original request with the `HTTPBodyStream` property set to `nil`. From here, the file can either be passed to `AFURLSessionManager -uploadTaskWithRequest:fromFile:progress:completionHandler:`, or have its contents read into an `NSData` that's assigned to the `HTTPBody` property of the request.
     
     - Seealso: https://github.com/AFNetworking/AFNetworking/issues/1398
     */
    func requestWithMultipartFormRequest(request: NSURLRequest, writingStreamContentsToFile:NSURL, completionHandler:CompletionBlock?) -> NSMutableURLRequest {
        
    }
    
    private func shouldEncodeParameters(request: NSURLRequest) -> Bool {
        guard let method = request.HTTPMethod?.uppercaseString else { return false }
        
        return self.HTTPMethodsEncodingParametersInURI.contains(method)
    }
    
    func requestBySerializingRequest(request: NSURLRequest, withParameters parameters:Parameters?) throws -> NSURLRequest {
        if let mutableRequest = request.mutableRequest {

            for pair in self.HTTPRequestHeaders {
                if request.valueForHTTPHeaderField(pair.0) == nil {
                    mutableRequest.setValue(pair.1, forKey: pair.0)
                }
            }
            
            if let p = parameters, serialize = self.queryStringSerializer {
                var query = try serialize(request, parameters: p)
                
                if shouldEncodeParameters(request) {
                    if String.isNotEmpty(query) {
                        if mutableRequest.URL!.query != nil {
                            mutableRequest.URL = NSURL(string: request.URL!.absoluteString.stringByAppendingFormat("&%@", query))
                        }
                        else {
                            mutableRequest.URL = NSURL(string: request.URL!.absoluteString.stringByAppendingFormat("?%@", query))
                        }

                    }
                } else {
                    // #2864: an empty string is a valid x-www-form-urlencoded payload
                    query = query ?? ""
                    
                    if mutableRequest.valueForHTTPHeaderField("Content-Type") == nil {
                        mutableRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")
                    }
                    mutableRequest.HTTPBody = query.dataUsingEncoding(self.stringEncoding)
                }

//                if query == nil {
//                    switch (self.queryStringSerializationStyle) {
//                    case AFHTTPRequestQueryStringDefaultStyle:
//                        query = AFQueryStringFromParameters(parameters)
//                        break
//                    }
//                }
            }
            
            
            return mutableRequest
        }
        else {
            throw SFError.BadRequest
        }
    }
}

enum SFError : ErrorType {
    case BadRequest
}