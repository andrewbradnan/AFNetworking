/**
 # SFURLSessionManager.swift
 ## SFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright:   Copyright © 2016 AFNetworking. All rights reserved.
 */

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

import Foundation
import FutureKit
import SwiftyJSON

/**
 `SFURLSessionManager` creates and manages an `NSURLSession` object based on a specified `NSURLSessionConfiguration` object, which conforms to `<NSURLSessionTaskDelegate>`, `<NSURLSessionDataDelegate>`, `<NSURLSessionDownloadDelegate>`, and `<NSURLSessionDelegate>`.
 
 ## Subclassing Notes
 
 This is the base class for `SFHTTPSessionManager`, which adds functionality specific to making HTTP requests. If you are looking to extend `AFURLSessionManager` specifically for HTTP, consider subclassing `AFHTTPSessionManager` instead.
 
 ## NSURLSession & NSURLSessionTask Delegate Methods
 
 `SFURLSessionManager` implements the following delegate methods:
 
 ### `NSURLSessionDelegate`
 
 - `URLSession:didBecomeInvalidWithError:`
 - `URLSession:didReceiveChallenge:completionHandler:`
 - `URLSessionDidFinishEventsForBackgroundURLSession:`
 
 ### `NSURLSessionTaskDelegate`
 
 - `URLSession:willPerformHTTPRedirection:newRequest:completionHandler:`
 - `URLSession:task:didReceiveChallenge:completionHandler:`
 - `URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:`
 - `URLSession:task:needNewBodyStream:`
 - `URLSession:task:didCompleteWithError:`
 
 ### `NSURLSessionDataDelegate`
 
 - `URLSession:dataTask:didReceiveResponse:completionHandler:`
 - `URLSession:dataTask:didBecomeDownloadTask:`
 - `URLSession:dataTask:didReceiveData:`
 - `URLSession:dataTask:willCacheResponse:completionHandler:`
 
 ### `NSURLSessionDownloadDelegate`
 
 - `URLSession:downloadTask:didFinishDownloadingToURL:`
 - `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesWritten:totalBytesExpectedToWrite:`
 - `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:`
 
 If any of these methods are overridden in a subclass, they _must_ call the `super` implementation first.
 
 ## Network Reachability Monitoring
 
 Network reachability status and change monitoring is available through the `reachabilityManager` property. Applications may choose to monitor network reachability conditions in order to prevent or suspend any outbound requests. See `AFNetworkReachabilityManager` for more details.
 
 ## NSCoding Caveats
 
 - Encoded managers do not include any block properties. Be sure to set delegate callback blocks when using `-initWithCoder:` or `NSKeyedUnarchiver`.
 
 ## NSCopying Caveats
 
 - `-copy` and `-copyWithZone:` return a new manager with a new `NSURLSession` created from the configuration of the original.
 - Operation copies do not include any delegate callback blocks, as they often strongly captures a reference to `self`, which would otherwise have the unintuitive side-effect of pointing to the _original_ session manager when copied.
 
 @warning Managers for background sessions must be owned for the duration of their use. This can be accomplished by creating an application-wide or shared singleton instance.
 */

public typealias ProgressBlock = (NSProgress)->Void

var url_session_manager_completion_group = dispatch_group_create()
var url_session_manager_creation_queue = dispatch_queue_create("com.alamofire.networking.session.manager.creation", DISPATCH_QUEUE_SERIAL)
var url_session_manager_completion_queue = dispatch_queue_create("com.alamofire.networking.session.manager.completion", DISPATCH_QUEUE_CONCURRENT)
var url_session_manager_processing_queue = dispatch_queue_create("com.alamofire.networking.session.manager.processing", DISPATCH_QUEUE_CONCURRENT)

let SFMaximumNumberOfAttemptsToRecreateBackgroundSessionUploadTask = 3

public class SFURLSessionManager<T> : NSObject, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate /* , NSSecureCoding, NSCopying*/ {
    
    
    /// The managed session.
    var session: NSURLSession
    
    /// The operation queue on which delegate callbacks are run.
    public let operationQueue = NSOperationQueue()

    /**
     Responses sent from the server in data tasks created with `dataTaskWithRequest:success:failure:` and run using the `GET` / `POST` / et al. convenience methods are automatically validated and serialized by the response serializer. By default, this property is set to an instance of `AFJSONResponseSerializer`.
     */
    var responseSerializer: SFJSONResponseSerializer<T>
    
    // MARK: Managing Security Policy
    /**
     The security policy used by created session to evaluate server trust for secure connections. `SFURLSessionManager` uses the `defaultPolicy` unless otherwise specified.
     */
    var securityPolicy = SFSecurityPolicy.defaultPolicy
    
    #if !TARGET_OS_WATCH
    // MARK: Monitoring Network Reachability
    /// The network reachability manager. `AFURLSessionManager` uses the `sharedManager` by default.
    var reachabilityManager = SFNetworkReachabilityManager.sharedManager!
    #endif
    
    
    // MARK: Getting Session Tasks

    /// The data, upload, and download tasks currently run by the managed session.
    let tasks: [NSURLSessionTask] = []
    
    /// The data tasks currently run by the managed session.
    let dataTasks: [NSURLSessionDataTask] = []
    
    /// The upload tasks currently run by the managed session.
    let uploadTasks: [NSURLSessionUploadTask] = []
    
    /// The download tasks currently run by the managed session.
    let downloadTasks: [NSURLSessionDownloadTask] = []
    
    // MARK: Managing Callback Queues
    
    private var _completionQueue: dispatch_queue_t?
    /// The dispatch queue for `completionBlock`. If `nil` (default), the main queue is used.
    var completionQueue: dispatch_queue_t {
        get {
            return _completionQueue ?? url_session_manager_completion_queue
        }
        set(value) {
            _completionQueue = value
        }
    }
    
    private var _completionGroup: dispatch_group_t?
    /// The dispatch group for `completionBlock`. If `nil` (default), a private dispatch group is used.
    public var completionGroup: dispatch_group_t {
        get {
            return _completionGroup ?? url_session_manager_completion_group
        }
        set(value) {
            _completionGroup = value
        }
    }
    
    let uploadProgress: NSProgress? = nil
    let downloadProgress: NSProgress? = nil
    var sessionConfiguration: NSURLSessionConfiguration
    var taskDelegates: [Int:SFURLSessionManagerTaskDelegate<T>] = [:]
    var taskDescriptionForSessionTasks: String {
        get {
            return self.hashValue.description
        }
    }
    var lock: NSLock
    
    public typealias BecomeInvalidBlock = (NSURLSession) throws -> Void
    public typealias ChallengeBlock = (NSURLSession, NSURLAuthenticationChallenge, NSURLCredential?) -> NSURLSessionAuthChallengeDisposition
    public typealias NSURLSessionBlock = NSURLSession->Void
    public typealias RedirectionBlock = (NSURLSession, NSURLSessionTask, NSURLResponse, NSURLRequest)->NSURLRequest?
    public typealias TaskChallengeBlock = (NSURLSession, NSURLSessionTask, NSURLAuthenticationChallenge, inout NSURLCredential?)->NSURLSessionAuthChallengeDisposition?
    public typealias TaskNeedNewBodyStreamBlock = (NSURLSession, NSURLSessionTask)->NSInputStream?
    public typealias TaskDidSendBodyDataBlock = (NSURLSession, NSURLSessionTask, Int64, Int64, Int64)->Void
    public typealias TaskDidCompleteBlock = (NSURLSession, NSURLSessionTask) throws ->Void
    public typealias TaskDidReceiveResponseBlock = (NSURLSession, NSURLSessionDataTask, NSURLResponse)->NSURLSessionResponseDisposition
    public typealias DataTaskDidBecomeDownloadTaskBlock = (NSURLSession, NSURLSessionDataTask, NSURLSessionDownloadTask)->Void
    public typealias DataTaskDidReceiveDataBlock = (NSURLSession, NSURLSessionDataTask, NSData)->Void
    public typealias DataTaskWillCacheResponseBlock = (NSURLSession, NSURLSessionDataTask, NSCachedURLResponse)->NSCachedURLResponse
    public typealias DownloadTaskDidFinishDownloadingBlock = (NSURLSession, NSURLSessionDownloadTask, NSURL)->NSURL?
    public typealias DownloadTaskDidWriteDataBlock = (NSURLSession, NSURLSessionDownloadTask, Int64, Int64, Int64)->Void
    public typealias DownloadTaskDidResumeBlock = (NSURLSession, NSURLSessionDownloadTask, Int64, Int64)->Void
    /**
     Sets a block to be executed when a connection level authentication challenge has occurred, as handled by the `NSURLSessionDelegate` method `URLSession:didReceiveChallenge:completionHandler:`.
     
     - Parameter block: A block object to be executed when a connection level authentication challenge has occurred. The block returns the disposition of the authentication challenge, and takes three arguments: the session, the authentication challenge, and a pointer to the credential that should be used to resolve the challenge.
     */
    public var sessionDidBecomeInvalid: BecomeInvalidBlock?
    /**
     Sets a block to be executed when a connection level authentication challenge has occurred, as handled by the `NSURLSessionDelegate` method `URLSession:didReceiveChallenge:completionHandler:`.
     
     - Parameter block: A block object to be executed when a connection level authentication challenge has occurred. The block returns the disposition of the authentication challenge, and takes three arguments: the session, the authentication challenge, and a pointer to the credential that should be used to resolve the challenge.
     */
    public var sessionDidReceiveAuthenticationChallenge: ChallengeBlock?
    /**
     Sets a block to be executed once all messages enqueued for a session have been delivered, as handled by the `NSURLSessionDataDelegate` method `URLSessionDidFinishEventsForBackgroundURLSession:`.
     
     - Parameter block: A block object to be executed once all messages enqueued for a session have been delivered. The block has no return value and takes a single argument: the session.
     */
    public var didFinishEventsForBackgroundURLSession: NSURLSessionBlock?
    /**
     Sets a block to be executed when an HTTP request is attempting to perform a redirection to a different URL, as handled by the `NSURLSessionTaskDelegate` method `URLSession:willPerformHTTPRedirection:newRequest:completionHandler:`.
     
     - Parameter block: A block object to be executed when an HTTP request is attempting to perform a redirection to a different URL. The block returns the request to be made for the redirection, and takes four arguments: the session, the task, the redirection response, and the request corresponding to the redirection response.
     
     ```
        let doit = { (session: NSURLSession, t: NSURLSessionTask, response: NSURLResponse, request: NSURLRequest)->NSURLRequest? in
                        return request
                }
     ```
     */
    public var taskWillPerformHTTPRedirection: RedirectionBlock?
    /**
     Sets a block to be executed when a session task has received a request specific authentication challenge, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:didReceiveChallenge:completionHandler:`.
     
     - Parameter block: A block object to be executed when a session task has received a request specific authentication challenge. The block returns the disposition of the authentication challenge, and takes four arguments: the session, the task, the authentication challenge, and a pointer to the credential that should be used to resolve the challenge.
     */
    public var taskDidReceiveAuthenticationChallenge: TaskChallengeBlock?
    /**
     Sets a block to be executed when a task requires a new request body stream to send to the remote server, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:needNewBodyStream:`.
     
     - Parameter block: A block object to be executed when a task requires a new request body stream.
     */
    public var taskNeedNewBodyStream: TaskNeedNewBodyStreamBlock?
    /**
     Sets a block to be executed periodically to track upload progress, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:`.
     
     - Parameter block: A block object to be called when an undetermined number of bytes have been uploaded to the server. This block has no return value and takes five arguments: the session, the task, the number of bytes written since the last time the upload progress block was called, the total bytes written, and the total bytes expected to be written during the request, as initially determined by the length of the HTTP body. This block may be called multiple times, and will execute on the main thread.
     */
    public var taskDidSendBodyData: TaskDidSendBodyDataBlock?
    /**
     Sets a block to be executed as the last message related to a specific task, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:didCompleteWithError:`.
     
     - Parameter block: A block object to be executed when a session task is completed. The block has no return value, and takes three arguments: the session, the task, and any error that occurred in the process of executing the task.
     */
    public var taskDidComplete: TaskDidCompleteBlock?
    /**
     Sets a block to be executed when a data task has received a response, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:didReceiveResponse:completionHandler:`.
     
     - Parameter block: A block object to be executed when a data task has received a response. The block returns the disposition of the session response, and takes three arguments: the session, the data task, and the received response.
     */
    public var dataTaskDidReceiveResponse: TaskDidReceiveResponseBlock?
    /**
     Sets a block to be executed when a data task has become a download task, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:didBecomeDownloadTask:`.
     
     - Parameter block: A block object to be executed when a data task has become a download task. The block has no return value, and takes three arguments: the session, the data task, and the download task it has become.
     */
    public var dataTaskDidBecomeDownloadTask: DataTaskDidBecomeDownloadTaskBlock?
    /**
     Sets a block to be executed when a data task receives data, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:didReceiveData:`.
     
     - Parameter block: A block object to be called when an undetermined number of bytes have been downloaded from the server. This block has no return value and takes three arguments: the session, the data task, and the data received. This block may be called multiple times, and will execute on the session manager operation queue.
     */
    public var dataTaskDidReceiveData: DataTaskDidReceiveDataBlock?
    
    /**
     Sets a block to be executed to determine the caching behavior of a data task, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:willCacheResponse:completionHandler:`.
     
     - Parameter block: A block object to be executed to determine the caching behavior of a data task. The block returns the response to cache, and takes three arguments: the session, the data task, and the proposed cached URL response.
     */
    public var dataTaskWillCacheResponse: DataTaskWillCacheResponseBlock?
    /**
     Sets a block to be executed when a download task has completed a download, as handled by the `NSURLSessionDownloadDelegate` method `URLSession:downloadTask:didFinishDownloadingToURL:`.
     
     - Parameter block: A block object to be executed when a download task has completed. The block returns the URL the download should be moved to, and takes three arguments: the session, the download task, and the temporary location of the downloaded file. If the file manager encounters an error while attempting to move the temporary file to the destination, an `AFURLSessionDownloadTaskDidFailToMoveFileNotification` will be posted, with the download task as its object, and the user info of the error.
     */
    public var downloadTaskDidFinishDownloading: DownloadTaskDidFinishDownloadingBlock?
    /**
     Sets a block to be executed periodically to track download progress, as handled by the `NSURLSessionDownloadDelegate` method `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesWritten:totalBytesExpectedToWrite:`.
     
     - Parameter block: A block object to be called when an undetermined number of bytes have been downloaded from the server. This block has no return value and takes five arguments: the session, the download task, the number of bytes read since the last time the download progress block was called, the total bytes read, and the total bytes expected to be read during the request, as initially determined by the expected content size of the `NSHTTPURLResponse` object. This block may be called multiple times, and will execute on the session manager operation queue.
     */
    public var downloadTaskDidWriteData: DownloadTaskDidWriteDataBlock?
    /**
     Sets a block to be executed when a download task has been resumed, as handled by the `NSURLSessionDownloadDelegate` method `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:`.
     
     - Parameter block: A block object to be executed when a download task has been resumed. The block has no return value and takes four arguments: the session, the download task, the file offset of the resumed download, and the total number of bytes expected to be downloaded.
     */
    public var downloadTaskDidResume: DownloadTaskDidResumeBlock?
    
    // MARK: Working Around System Bugs
    
    /**
     Whether to attempt to retry creation of upload tasks for background sessions when initial call returns `nil`. `NO` by default.
     
     @bug As of iOS 7.0, there is a bug where upload tasks created for background tasks are sometimes `nil`. As a workaround, if this property is `YES`, AFNetworking will follow Apple's recommendation to try creating the task again.
     
     - seealso: https://github.com/AFNetworking/AFNetworking/issues/1675
     */
    var attemptsToRecreateUploadTasksForBackgroundSessions = false
    
    // MARK: Initialization
    
    /**
     Creates and returns a manager for a session created with the specified configuration. This is the designated initializer.
     
     - Parameter configuration: The configuration used to create the managed session.
     */
    init(configuration: NSURLSessionConfiguration? = nil, converter: JSON throws -> T) {
        var conf = configuration
        if conf == nil {
            conf = NSURLSessionConfiguration.defaultSessionConfiguration()
        }

        self.sessionConfiguration = conf!
        self.session = NSURLSession(configuration: self.sessionConfiguration, delegate:nil, delegateQueue:self.operationQueue)
        self.responseSerializer = SFJSONResponseSerializer<T>(converter: converter) //.serializer()
        //let rs = SFJSONResponseSerializer<T>(converter: converter) //.serializer()
        self.lock = NSLock()
        
        super.init()
        
        self.operationQueue.maxConcurrentOperationCount = 1
        
        self.session = NSURLSession(configuration: self.sessionConfiguration, delegate:self, delegateQueue:self.operationQueue)
        
        
        
        #if !TARGET_OS_WATCH
            self.reachabilityManager = SFNetworkReachabilityManager.sharedManager!
        #endif
        
        self.lock = NSLock()
        self.lock.name = "SFURLSessionManagerLockName"
        
        self.session.getTasksWithCompletionHandler{ (dataTasks: [NSURLSessionDataTask], uploadTasks: [NSURLSessionUploadTask], downloadTasks:[NSURLSessionDownloadTask]) -> Void in
            for task in dataTasks {
                self.addDelegateForDataTask(task, uploadProgress:nil, downloadProgress:nil)
            }
        
            for uploadTask in uploadTasks {
                self.addDelegateForUploadTask(uploadTask, progress:nil)
            }
        
            for downloadTask in downloadTasks {
                self.addDelegateForDownloadTask(downloadTask, progress:nil, destination:nil)
            }
        }

    }
    
    
    
    /**
     Invalidates the managed session, optionally canceling pending tasks.
     
     - Parameter cancelPendingTasks: Whether or not to cancel pending tasks.
     */
    public func invalidateSessionCancelingTasks(cancelPendingTasks: Bool) {
        dispatch_async(dispatch_get_main_queue(), {
            if (cancelPendingTasks) {
                self.session.invalidateAndCancel()
            }
            else {
                self.session.finishTasksAndInvalidate()
            }
        })
    }
    
    
    
    // MARK: Running Data Tasks
    
    
    /**
     Creates an `NSURLSessionDataTask` with the specified request.
     
     - Parameter request: The HTTP request for the request.
     - Parameter completionHandler: A block object to be executed when the task finishes. This block has no return value and takes three arguments: the server response, the response object created by that serializer, and the error that occurred, if any.
     */
//    func dataTaskWithRequest(request: NSURLRequest, completionHandler: (NSURLResponse, AnyObject?, NSError?)-> Void?) {
//        return self.dataTaskWithRequest(request uploadProgress:nil downloadProgress:nil completionHandler:completionHandler];
//    }
    
    typealias CompletionHandler = (NSURLResponse, AnyObject?, NSError?)->Void
    
    /**
     Creates an `NSURLSessionDataTask` with the specified request.
     
     - Parameter request: The HTTP request for the request.
     - Parameter uploadProgressBlock: A block object to be executed when the upload progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter downloadProgressBlock: A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
     */
    public func dataTaskWithRequest(request: NSURLRequest, uploadProgress: ProgressBlock? = nil, downloadProgress:ProgressBlock? = nil) -> Future<T> {
        var dataTask: NSURLSessionDataTask
        
//        url_session_manager_create_task_safely{
            dataTask = self.session.dataTaskWithRequest(request)
//        }
        
        let rt = self.addDelegateForDataTask(dataTask, uploadProgress:uploadProgress, downloadProgress:downloadProgress)
        dataTask.resume()
        
        return rt
    }
    
    
    func addDelegateForDataTask(dataTask: NSURLSessionDataTask, uploadProgress:ProgressBlock?, downloadProgress:ProgressBlock?) -> Future<T>
    {
        let delegate = SFURLSessionManagerTaskDelegate<T>()
        delegate.manager = self
        //delegate.completionHandler = completionHandler
    
        dataTask.taskDescription = self.taskDescriptionForSessionTasks
        
        //self.setDelegate(delegate, forTask:dataTask)
        self.taskDelegates[dataTask.taskIdentifier] = delegate
        
        delegate.uploadProgressBlock = uploadProgress
        delegate.downloadProgressBlock = downloadProgress
        
        return delegate.promise.future
    }

    func addDelegateForUploadTask(uploadTask: NSURLSessionUploadTask, progress:ProgressBlock?) -> Future<T>
    //completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
    {
        let delegate = SFURLSessionManagerTaskDelegate<T>()
        delegate.manager = self
        //delegate.completionHandler = completionHandler;
    
        uploadTask.taskDescription = self.taskDescriptionForSessionTasks
    
        self.taskDelegates[uploadTask.taskIdentifier] = delegate
    
        delegate.uploadProgressBlock = progress
        return delegate.promise.future
    }
    
    func addDelegateForDownloadTask(downloadTask: NSURLSessionDownloadTask, progress: ProgressBlock?,
    destination:SFURLSessionManager<T>.TargetBlock?) -> Future<NSURL>
    {
        let delegate = SFURLSessionManagerTaskDelegate<T>()
        delegate.filePromise = Promise<NSURL>()
        delegate.manager = self
    
        if (destination != nil) {
            delegate.downloadTaskDidFinishDownloading = { (NSURLSession, task: NSURLSessionDownloadTask, location: NSURL) -> NSURL? in
                return destination!(location, task.response!)
            }
        }
    
        downloadTask.taskDescription = self.taskDescriptionForSessionTasks
    
        self.taskDelegates[downloadTask.taskIdentifier] = delegate
    
        delegate.downloadProgressBlock = progress
        return delegate.filePromise!.future
    }

    // MARK: Running Upload Tasks
    
    /**
     Creates an `NSURLSessionUploadTask` with the specified request for a local file.
     
     - Parameter request: The HTTP request for the request.
     - Parameter fileURL: A URL to the local file to be uploaded.
     - Parameter uploadProgressBlock: A block object to be executed when the upload progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter completionHandler: A block object to be executed when the task finishes. This block has no return value and takes three arguments: the server response, the response object created by that serializer, and the error that occurred, if any.
     
     - Seealso: `attemptsToRecreateUploadTasksForBackgroundSessions`
     */
    func uploadTaskWithRequest(request: NSURLRequest, fromFile fileURL:NSURL, progress: ProgressBlock?) -> NSURLSessionUploadTask? {
                               // completionHandler:CompletionHandler?
        var uploadTask: NSURLSessionUploadTask?
        
        url_session_manager_create_task_safely({
            uploadTask = self.session.uploadTaskWithRequest(request, fromFile:fileURL)
        })
        
        if (uploadTask == nil) {
            if self.attemptsToRecreateUploadTasksForBackgroundSessions {
                if (self.session.configuration.identifier != nil) {
                    for _ in 0..<SFMaximumNumberOfAttemptsToRecreateBackgroundSessionUploadTask {
                        uploadTask = self.session.uploadTaskWithRequest(request, fromFile:fileURL)
                        if uploadTask != nil { break }
                    }
                }}
        }
        
        if (uploadTask != nil) {
            self.addDelegateForUploadTask(uploadTask!, progress:progress)
        }
        
        return uploadTask

        
    }
    
    /**
     Creates an `NSURLSessionUploadTask` with the specified request for an HTTP body.
     
     - Parameter request: The HTTP request for the request.
     - Parameter bodyData: A data object containing the HTTP body to be uploaded.
     - Parameter uploadProgressBlock: A block object to be executed when the upload progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter completionHandler: A block object to be executed when the task finishes. This block has no return value and takes three arguments: the server response, the response object created by that serializer, and the error that occurred, if any.
     */
    func uploadTaskWithRequest(request: NSURLRequest, fromData bodyData:NSData, progress:ProgressBlock?) -> NSURLSessionUploadTask? {
        var uploadTask: NSURLSessionUploadTask?
        
        url_session_manager_create_task_safely({
            uploadTask = self.session.uploadTaskWithRequest(request, fromData:bodyData)
        })
        
        guard let task = uploadTask else { return nil }
        
        self.addDelegateForUploadTask(task, progress:progress)
        
        return task
    }
    
    /**
     Creates an `NSURLSessionUploadTask` with the specified streaming request.
     
     - Parameter request: The HTTP request for the request.
     - Parameter uploadProgressBlock: A block object to be executed when the upload progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter completionHandler: A block object to be executed when the task finishes. This block has no return value and takes three arguments: the server response, the response object created by that serializer, and the error that occurred, if any.
     */
    func uploadTaskWithStreamedRequest(request: NSURLRequest, progress:ProgressBlock?) -> NSURLSessionUploadTask? {
        var uploadTask: NSURLSessionUploadTask?
        
        url_session_manager_create_task_safely({
            uploadTask = self.session.uploadTaskWithStreamedRequest(request)
        })

        guard let task = uploadTask else { return nil }
        
        self.addDelegateForUploadTask(task, progress:progress)
        
        return task
    }
    
    
    // MARK: Running Download Tasks
    
    
    public typealias TargetBlock = (NSURL, NSURLResponse) -> NSURL?
    /**
     Creates an `NSURLSessionDownloadTask` with the specified request.
     
     - Parameter request: The HTTP request for the request.
     - Parameter 1: A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter destination: A block object to be executed in order to determine the destination of the downloaded file. This block takes two arguments, the target path & the server response, and returns the desired file URL of the resulting download. The temporary file used during the download will be automatically deleted after being moved to the returned URL.
     - Parameter completionHandler: A block to be executed when a task finishes. This block has no return value and takes three arguments: the server response, the path of the downloaded file, and the error describing the network or parsing error that occurred, if any.
     
     @warning If using a background `NSURLSessionConfiguration` on iOS, these blocks will be lost when the app is terminated. Background sessions may prefer to use `-setDownloadTaskDidFinishDownloadingBlock:` to specify the URL for saving the downloaded file, rather than the destination block of this method.
     */
    public func downloadTaskWithRequest(request: NSURLRequest, progress:ProgressBlock? = nil, destination:TargetBlock? = nil)-> Future<NSURL> {
        let downloadTask = self.session.downloadTaskWithRequest(request)
        
        let f = self.addDelegateForDownloadTask(downloadTask, progress:progress, destination:destination)
        downloadTask.resume()
        
        return f
    }
    
    /**
     Creates an `NSURLSessionDownloadTask` with the specified resume data.
     
     - Parameter resumeData: The data used to resume downloading.
     - Parameter downloadProgressBlock: A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter destination: A block object to be executed in order to determine the destination of the downloaded file. This block takes two arguments, the target path & the server response, and returns the desired file URL of the resulting download. The temporary file used during the download will be automatically deleted after being moved to the returned URL.
     - Parameter completionHandler: A block to be executed when a task finishes. This block has no return value and takes three arguments: the server response, the path of the downloaded file, and the error describing the network or parsing error that occurred, if any.
     */
    func downloadTaskWithResumeData(resumeData: NSData, progress:ProgressBlock?, destination:TargetBlock,
                                    completionHandler:CompletionHandler?) -> NSURLSessionDownloadTask {
        var downloadTask: NSURLSessionDownloadTask
        //url_session_manager_create_task_safely({
            downloadTask = self.session.downloadTaskWithResumeData(resumeData)
        //})
        
        self.addDelegateForDownloadTask(downloadTask, progress:progress, destination:destination)
        
        return downloadTask
    }
    
    
    // MARK: Getting Progress for Tasks
    
    
    /**
     Returns the upload progress of the specified task.
     
     - Parameter task: The session task. Must not be `nil`.
     
     - Returns: An `NSProgress` object reporting the upload progress of a task, or `nil` if the progress is unavailable.
     */
    func uploadProgressForTask(task: NSURLSessionTask) -> NSProgress? {
        return self.taskDelegates[task.taskIdentifier]?.uploadProgress
    }
    
    /**
     Returns the download progress of the specified task.
     
     - Parameter task: The session task. Must not be `nil`.
     
     - Returns: An `NSProgress` object reporting the download progress of a task, or `nil` if the progress is unavailable.
     */
    func downloadProgressForTask(task: NSURLSessionTask) -> NSProgress? {
        return self.taskDelegates[task.taskIdentifier]?.downloadProgress
    }
    
    public func URLSession(session: NSURLSession, downloadTask:NSURLSessionDownloadTask, didFinishDownloadingToURL location:NSURL) {
        if let delegate = self.taskDelegates[downloadTask.taskIdentifier] {
    
            if self.downloadTaskDidFinishDownloading != nil {
                let fileURL = self.downloadTaskDidFinishDownloading!(session, downloadTask, location)
                
                if fileURL != nil {
                    delegate.downloadFileURL = fileURL
                    do {
                        try NSFileManager.defaultManager().moveItemAtURL(location, toURL:fileURL!)
                    }
                    catch _ {
                        // TODO: error
                    }
                }
            }
        
            delegate.URLSession(session, downloadTask:downloadTask, didFinishDownloadingToURL:location)
        }
    }
    
    public func URLSession(session: NSURLSession, downloadTask:NSURLSessionDownloadTask, didWriteData bytesWritten:Int64, totalBytesWritten:Int64, totalBytesExpectedToWrite:Int64) {
        self.downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
    
    public func URLSession(session: NSURLSession, downloadTask:NSURLSessionDownloadTask, didResumeAtOffset fileOffset:Int64, expectedTotalBytes:Int64) {
        self.downloadTaskDidResume?(session, downloadTask, fileOffset, expectedTotalBytes)
    }
    
    /**
     ## NSSessionDataDelegate.didReceiveData
     
     Sent when data is available for the delegate to consume.  It is assumed that the delegate will retain and not copy the data.  As the data may be discontiguous, you should use [NSData enumerateByteRangesUsingBlock:] to access it.
     */
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        let delegate = self.taskDelegates[dataTask.taskIdentifier]
        
        delegate?.URLSession(session, dataTask:dataTask, didReceiveData:data)
    }

    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        let delegate = self.taskDelegates[task.taskIdentifier]
        
        // delegate may be nil when completing a task in the background
        if (delegate != nil) {
            delegate!.URLSession(session, task:task, didCompleteWithError:error)
            
            self.taskDelegates.removeValueForKey(task.taskIdentifier)
        }
        
        try! self.taskDidComplete?(session, task)
    }
}


// MARK: Notifications


/// Posted when a task resumes.
let SFNetworkingTaskDidResumeNotification = "com.alamofire.networking.task.resume"

/// Posted when a task finishes executing. Includes a userInfo dictionary with additional information about the task.
let SFNetworkingTaskDidCompleteNotification = "com.alamofire.networking.task.complete"

/// Posted when a task suspends its execution.
let SFNetworkingTaskDidSuspendNotification = "com.alamofire.networking.task.suspend"

/// Posted when a session is invalidated.
let SFURLSessionDidInvalidateNotification = "com.alamofire.networking.session.invalidate"

/// Posted when a session download task encountered an error when moving the temporary download file to a specified destination.
let SFURLSessionDownloadTaskDidFailToMoveFileNotification = "com.alamofire.networking.session.download.file-manager-error"

/// The raw response data of the task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if response data exists for the task.
let SFNetworkingTaskDidCompleteResponseDataKey = "com.alamofire.networking.complete.finish.responsedata"

/// The serialized response object of the task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if the response was serialized.
let SFNetworkingTaskDidCompleteSerializedResponseKey = "com.alamofire.networking.task.complete.serializedresponse"

/// The response serializer used to serialize the response. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if the task has an associated response serializer.
let SFNetworkingTaskDidCompleteResponseSerializerKey = "com.alamofire.networking.task.complete.responseserializer"

/// The file path associated with the download task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if an the response data has been stored directly to disk.
let SFNetworkingTaskDidCompleteAssetPathKey = "com.alamofire.networking.task.complete.assetpath"

/// Any error associated with the task, or the serialization of the response. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if an error exists.
let SFNetworkingTaskDidCompleteErrorKey = "com.alamofire.networking.task.complete.error"


func url_session_manager_create_task_safely(block: dispatch_block_t) {
    if #available(iOS 8.0, *) {
        block()
    }
    else {
        // Fix of bug
        // Open Radar:http://openradar.appspot.com/radar?id=5871104061079552 (status: Fixed in iOS8)
        // Issue about:https://github.com/AFNetworking/AFNetworking/issues/2093
        dispatch_sync(url_session_manager_creation_queue, block)
    }
}
