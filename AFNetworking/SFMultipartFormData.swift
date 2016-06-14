/**
 # SFMultipartFormData.swift
## SFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/7/16
 - Copyright: Copyright © 2016 SFNetworking. All rights reserved.
 */

import Foundation

/**
 The `SFMultipartFormData` protocol defines the methods supported by the parameter in the block argument of `SFHTTPRequestSerializer -multipartFormRequestWithMethod:URLString:parameters:constructingBodyWithBlock:`.
 */
protocol SFMultipartFormData {
    
    /**
     Appends the HTTP header `Content-Disposition: file; filename=#{generated filename}; name=#{name}"` and `Content-Type: #{generated mimeType}`, followed by the encoded file data and the multipart form boundary.
     
     The filename and MIME type for this data in the form will be automatically generated, using the last path component of the `fileURL` and system associated MIME type for the `fileURL` extension, respectively.
     
     - Parameter fileURL: The URL corresponding to the file whose content will be appended to the form. This parameter must not be `nil`.
     - Parameter name: The name to be associated with the specified data. This parameter must not be `nil`.
     - Parameter error: If an error occurs, upon return contains an `NSError` object that describes the problem.
     
     - Returns: `true` if the file data was successfully appended, otherwise `false`.
     */
    func appendPartWithFileURL(fileURL: NSURL, name: String) throws -> Bool
    
    /**
     Appends the HTTP header `Content-Disposition: file; filename=#{filename}; name=#{name}"` and `Content-Type: #{mimeType}`, followed by the encoded file data and the multipart form boundary.
     
     - Parameter fileURL: The URL corresponding to the file whose content will be appended to the form. This parameter must not be `nil`.
     - Parameter name: The name to be associated with the specified data. This parameter must not be `nil`.
     - Parameter fileName: The file name to be used in the `Content-Disposition` header. This parameter must not be `nil`.
     - Parameter mimeType: The declared MIME type of the file data. This parameter must not be `nil`.
     - Parameter error: If an error occurs, upon return contains an `NSError` object that describes the problem.
     
     - Returns: `true` if the file data was successfully appended otherwise `false`.
     */
    func appendPartWithFileURL(fileURL: NSURL, name:String, fileName: String, mimeType: String) throws -> Bool
    
    /**
     Appends the HTTP header `Content-Disposition: file; filename=#{filename}; name=#{name}"` and `Content-Type: #{mimeType}`, followed by the data from the input stream and the multipart form boundary.
     
     - Parameter inputStream: The input stream to be appended to the form data
     - Parameter name: The name to be associated with the specified input stream. This parameter must not be `nil`.
     - Parameter fileName: The filename to be associated with the specified input stream. This parameter must not be `nil`.
     - Parameter length: The length of the specified input stream in bytes.
     - Parameter mimeType: The MIME type of the specified data. (For example, the MIME type for a JPEG image is image/jpeg.) For a list of valid MIME types, see http://www.iana.org/assignments/media-types/. This parameter must not be `nil`.
     */
    func appendPartWithInputStream(inputStream: NSInputStream?, name: String, fileName:String, length:Int64, mimeType: String)
    
    /**
     Appends the HTTP header `Content-Disposition: file; filename=#{filename}; name=#{name}"` and `Content-Type: #{mimeType}`, followed by the encoded file data and the multipart form boundary.
     
     - Parameter data: The data to be encoded and appended to the form data.
     - Parameter name: The name to be associated with the specified data. This parameter must not be `nil`.
     - Parameter fileName: The filename to be associated with the specified data. This parameter must not be `nil`.
     - Parameter mimeType: The MIME type of the specified data. (For example, the MIME type for a JPEG image is image/jpeg.) For a list of valid MIME types, see http://www.iana.org/assignments/media-types/. This parameter must not be `nil`.
     */
    func appendPartWithFileData(data: NSData, name: String, fileName: String, mimeType: String)
    
    /**
     Appends the HTTP headers `Content-Disposition: form-data; name=#{name}"`, followed by the encoded data and the multipart form boundary.
     
     - Parameter data: The data to be encoded and appended to the form data.
     - Parameter name: The name to be associated with the specified data. This parameter must not be `nil`.
     */
    
    func appendPartWithFormData(data: NSData, name: String)
    
    
    /**
     Appends HTTP headers, followed by the encoded data and the multipart form boundary.
     
     - Parameter headers: The HTTP headers to be appended to the form data.
     - Parameter body: The data to be encoded and appended to the form data. This parameter must not be `nil`.
     */
    func appendPartWithHeaders(headers: [String:String], body: NSData)
    
    /**
     Throttles request bandwidth by limiting the packet size and adding a delay for each chunk read from the upload stream.
     
     When uploading over a 3G or EDGE connection, requests may fail with "request body stream exhausted". Setting a maximum packet size and delay according to the recommended values (`kAFUploadStream3GSuggestedPacketSize` and `kAFUploadStream3GSuggestedDelay`) lowers the risk of the input stream exceeding its allocated bandwidth. Unfortunately, there is no definite way to distinguish between a 3G, EDGE, or LTE connection over `NSURLConnection`. As such, it is not recommended that you throttle bandwidth based solely on network reachability. Instead, you should consider checking for the "request body stream exhausted" in a failure block, and then retrying the request with throttled bandwidth.
     
     - Parameter numberOfBytes: Maximum packet size, in number of bytes. The default packet size for an input stream is 16kb.
     - Parameter delay: Duration of delay each time a packet is read. By default, no delay is set.
     */
    func throttleBandwidthWithPacketSize(numberOfBytes: UInt, delay: NSTimeInterval)
    
}