/**
 # SNURLSessionManager.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
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
 `SNURLSessionManager` creates and manages an `NSURLSession` object based on a specified `NSURLSessionConfiguration` object, which conforms to `<NSURLSessionTaskDelegate>`, `<NSURLSessionDataDelegate>`, `<NSURLSessionDownloadDelegate>`, and `<NSURLSessionDelegate>`.
 
 ## Subclassing Notes
 
 This is the base class for `SNHTTPSessionManager`, which adds functionality specific to making HTTP requests. If you are looking to extend `SNURLSessionManager` specifically for HTTP, consider subclassing `AFHTTPSessionManager` instead.
 
 ## NSURLSession & NSURLSessionTask Delegate Methods
 
 `SNURLSessionManager` implements the following delegate methods:
 
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

public typealias ProgressBlock = (Progress)->Void

var url_session_manager_completion_group = DispatchGroup()
var url_session_manager_creation_queue = DispatchQueue(label: "com.alamofire.networking.session.manager.creation", attributes: [])
var url_session_manager_completion_queue = DispatchQueue(label: "com.alamofire.networking.session.manager.completion", attributes: DispatchQueue.Attributes.concurrent)
var url_session_manager_processing_queue = DispatchQueue(label: "com.alamofire.networking.session.manager.processing", attributes: DispatchQueue.Attributes.concurrent)

let SNMaximumNumberOfAttemptsToRecreateBackgroundSessionUploadTask = 3

open class SNURLSessionManager<T, ResponseSerializer : SNURLResponseSerializer where T == ResponseSerializer.Element> : NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate /* , NSSecureCoding, NSCopying*/ {
    
    
    /// The managed session.
    var session: Foundation.URLSession
    
    /// The operation queue on which delegate callbacks are run.
    open let operationQueue = OperationQueue()

    /**
     Responses sent from the server in data tasks created with `dataTaskWithRequest:success:failure:` and run using the `GET` / `POST` / et al. convenience methods are automatically validated and serialized by the response serializer. By default, this property is set to an instance of `AFJSONResponseSerializer`.
     */
    open var responseSerializer: ResponseSerializer
    
    // MARK: Managing Security Policy
    /**
     The security policy used by created session to evaluate server trust for secure connections. `SNURLSessionManager` uses the `defaultPolicy` unless otherwise specified.
     */
    open var securityPolicy = SNSecurityPolicy.defaultPolicy
    
    #if !TARGET_OS_WATCH
    // MARK: Monitoring Network Reachability
    /// The network reachability manager. `SNURLSessionManager` uses the `sharedManager` by default.
    var reachabilityManager = SNReachabilityManager.sharedManager!
    #endif
    
    
    // MARK: Getting Session Tasks

    /// The data, upload, and download tasks currently run by the managed session.
    let tasks: [URLSessionTask] = []
    
    /// The data tasks currently run by the managed session.
    let dataTasks: [URLSessionDataTask] = []
    
    /// The upload tasks currently run by the managed session.
    let uploadTasks: [URLSessionUploadTask] = []
    
    /// The download tasks currently run by the managed session.
    let downloadTasks: [URLSessionDownloadTask] = []
    
    // MARK: Managing Callback Queues
    
    fileprivate var _completionQueue: DispatchQueue?
    /// The dispatch queue for `completionBlock`. If `nil` (default), the main queue is used.
    var completionQueue: DispatchQueue {
        get {
            return _completionQueue ?? url_session_manager_completion_queue
        }
        set(value) {
            _completionQueue = value
        }
    }
    
    fileprivate var _completionGroup: DispatchGroup?
    /// The dispatch group for `completionBlock`. If `nil` (default), a private dispatch group is used.
    open var completionGroup: DispatchGroup {
        get {
            return _completionGroup ?? url_session_manager_completion_group
        }
        set(value) {
            _completionGroup = value
        }
    }
    
    let uploadProgress: Progress? = nil
    let downloadProgress: Progress? = nil
    var sessionConfiguration: URLSessionConfiguration
    var taskDelegates: [Int:SNURLSessionManagerTaskDelegate<T,ResponseSerializer>] = [:]
    var taskDescriptionForSessionTasks: String {
        get {
            return self.hashValue.description
        }
    }
    var lock: NSLock
    
    open typealias BecomeInvalidBlock = (Foundation.URLSession) throws -> Void
    open typealias ChallengeBlock = (Foundation.URLSession, URLAuthenticationChallenge, inout URLCredential?) -> Foundation.URLSession.AuthChallengeDisposition
    open typealias NSURLSessionBlock = (Foundation.URLSession)->Void
    open typealias RedirectionBlock = (Foundation.URLSession, URLSessionTask, URLResponse, URLRequest)->URLRequest?
    open typealias TaskChallengeBlock = (Foundation.URLSession, URLSessionTask, URLAuthenticationChallenge, inout URLCredential?)->Foundation.URLSession.AuthChallengeDisposition
    open typealias TaskNeedNewBodyStreamBlock = (Foundation.URLSession, URLSessionTask)->InputStream?
    open typealias TaskDidSendBodyDataBlock = (Foundation.URLSession, URLSessionTask, Int64, Int64, Int64)->Void
    open typealias TaskDidCompleteBlock = (Foundation.URLSession, URLSessionTask) throws ->Void
    open typealias TaskDidReceiveResponseBlock = (Foundation.URLSession, URLSessionDataTask, URLResponse)->Foundation.URLSession.ResponseDisposition
    open typealias DataTaskDidBecomeDownloadTaskBlock = (Foundation.URLSession, URLSessionDataTask, URLSessionDownloadTask)->Void
    open typealias DataTaskDidReceiveDataBlock = (Foundation.URLSession, URLSessionDataTask, Data)->Void
    open typealias DataTaskWillCacheResponseBlock = (Foundation.URLSession, URLSessionDataTask, CachedURLResponse)->CachedURLResponse
    open typealias DownloadTaskDidFinishDownloadingBlock = (Foundation.URLSession, URLSessionDownloadTask, URL)->URL?
    open typealias DownloadTaskDidWriteDataBlock = (Foundation.URLSession, URLSessionDownloadTask, Int64, Int64, Int64)->Void
    open typealias DownloadTaskDidResumeBlock = (Foundation.URLSession, URLSessionDownloadTask, Int64, Int64)->Void
    /**
     Sets a block to be executed when a connection level authentication challenge has occurred, as handled by the `NSURLSessionDelegate` method `URLSession:didReceiveChallenge:completionHandler:`.
     
     - Parameter block: A block object to be executed when a connection level authentication challenge has occurred. The block returns the disposition of the authentication challenge, and takes three arguments: the session, the authentication challenge, and a pointer to the credential that should be used to resolve the challenge.
     */
    open var sessionDidBecomeInvalid: BecomeInvalidBlock?
    /**
     Sets a block to be executed when a connection level authentication challenge has occurred, as handled by the `NSURLSessionDelegate` method `URLSession:didReceiveChallenge:completionHandler:`.
     
     - Parameter block: A block object to be executed when a connection level authentication challenge has occurred. The block returns the disposition of the authentication challenge, and takes three arguments: the session, the authentication challenge, and a pointer to the credential that should be used to resolve the challenge.
     */
    open var sessionDidReceiveAuthenticationChallenge: ChallengeBlock?
    /**
     Sets a block to be executed once all messages enqueued for a session have been delivered, as handled by the `NSURLSessionDataDelegate` method `URLSessionDidFinishEventsForBackgroundURLSession:`.
     
     - Parameter block: A block object to be executed once all messages enqueued for a session have been delivered. The block has no return value and takes a single argument: the session.
     */
    open var didFinishEventsForBackgroundURLSession: NSURLSessionBlock?
    /**
     Sets a block to be executed when an HTTP request is attempting to perform a redirection to a different URL, as handled by the `NSURLSessionTaskDelegate` method `URLSession:willPerformHTTPRedirection:newRequest:completionHandler:`.
     
     - Parameter block: A block object to be executed when an HTTP request is attempting to perform a redirection to a different URL. The block returns the request to be made for the redirection, and takes four arguments: the session, the task, the redirection response, and the request corresponding to the redirection response.
     
     ```
        let doit = { (session: NSURLSession, t: NSURLSessionTask, response: NSURLResponse, request: NSURLRequest)->NSURLRequest? in
                        return request
                }
     ```
     */
    open var taskWillPerformHTTPRedirection: RedirectionBlock?
    /**
     Sets a block to be executed when a session task has received a request specific authentication challenge, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:didReceiveChallenge:completionHandler:`.
     
     - Parameter block: A block object to be executed when a session task has received a request specific authentication challenge. The block returns the disposition of the authentication challenge, and takes four arguments: the session, the task, the authentication challenge, and a pointer to the credential that should be used to resolve the challenge.
     */
    open var taskDidReceiveAuthenticationChallenge: TaskChallengeBlock?
    /**
     Sets a block to be executed when a task requires a new request body stream to send to the remote server, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:needNewBodyStream:`.
     
     - Parameter block: A block object to be executed when a task requires a new request body stream.
     */
    open var taskNeedNewBodyStream: TaskNeedNewBodyStreamBlock?
    /**
     Sets a block to be executed periodically to track upload progress, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:`.
     
     - Parameter block: A block object to be called when an undetermined number of bytes have been uploaded to the server. This block has no return value and takes five arguments: the session, the task, the number of bytes written since the last time the upload progress block was called, the total bytes written, and the total bytes expected to be written during the request, as initially determined by the length of the HTTP body. This block may be called multiple times, and will execute on the main thread.
     */
    open var taskDidSendBodyData: TaskDidSendBodyDataBlock?
    /**
     Sets a block to be executed as the last message related to a specific task, as handled by the `NSURLSessionTaskDelegate` method `URLSession:task:didCompleteWithError:`.
     
     - Parameter block: A block object to be executed when a session task is completed. The block has no return value, and takes three arguments: the session, the task, and any error that occurred in the process of executing the task.
     */
    open var taskDidComplete: TaskDidCompleteBlock?
    /**
     Sets a block to be executed when a data task has received a response, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:didReceiveResponse:completionHandler:`.
     
     - Parameter block: A block object to be executed when a data task has received a response. The block returns the disposition of the session response, and takes three arguments: the session, the data task, and the received response.
     */
    open var dataTaskDidReceiveResponse: TaskDidReceiveResponseBlock?
    /**
     Sets a block to be executed when a data task has become a download task, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:didBecomeDownloadTask:`.
     
     - Parameter block: A block object to be executed when a data task has become a download task. The block has no return value, and takes three arguments: the session, the data task, and the download task it has become.
     */
    open var dataTaskDidBecomeDownloadTask: DataTaskDidBecomeDownloadTaskBlock?
    /**
     Sets a block to be executed when a data task receives data, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:didReceiveData:`.
     
     - Parameter block: A block object to be called when an undetermined number of bytes have been downloaded from the server. This block has no return value and takes three arguments: the session, the data task, and the data received. This block may be called multiple times, and will execute on the session manager operation queue.
     */
    open var dataTaskDidReceiveData: DataTaskDidReceiveDataBlock?
    
    /**
     Sets a block to be executed to determine the caching behavior of a data task, as handled by the `NSURLSessionDataDelegate` method `URLSession:dataTask:willCacheResponse:completionHandler:`.
     
     - Parameter block: A block object to be executed to determine the caching behavior of a data task. The block returns the response to cache, and takes three arguments: the session, the data task, and the proposed cached URL response.
     */
    open var dataTaskWillCacheResponse: DataTaskWillCacheResponseBlock?
    /**
     Sets a block to be executed when a download task has completed a download, as handled by the `NSURLSessionDownloadDelegate` method `URLSession:downloadTask:didFinishDownloadingToURL:`.
     
     - Parameter block: A block object to be executed when a download task has completed. The block returns the URL the download should be moved to, and takes three arguments: the session, the download task, and the temporary location of the downloaded file. If the file manager encounters an error while attempting to move the temporary file to the destination, an `AFURLSessionDownloadTaskDidFailToMoveFileNotification` will be posted, with the download task as its object, and the user info of the error.
     */
    open var downloadTaskDidFinishDownloading: DownloadTaskDidFinishDownloadingBlock?
    /**
     Sets a block to be executed periodically to track download progress, as handled by the `NSURLSessionDownloadDelegate` method `URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesWritten:totalBytesExpectedToWrite:`.
     
     - Parameter block: A block object to be called when an undetermined number of bytes have been downloaded from the server. This block has no return value and takes five arguments: the session, the download task, the number of bytes read since the last time the download progress block was called, the total bytes read, and the total bytes expected to be read during the request, as initially determined by the expected content size of the `NSHTTPURLResponse` object. This block may be called multiple times, and will execute on the session manager operation queue.
     */
    open var downloadTaskDidWriteData: DownloadTaskDidWriteDataBlock?
    /**
     Sets a block to be executed when a download task has been resumed, as handled by the `NSURLSessionDownloadDelegate` method `URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:`.
     
     - Parameter block: A block object to be executed when a download task has been resumed. The block has no return value and takes four arguments: the session, the download task, the file offset of the resumed download, and the total number of bytes expected to be downloaded.
     */
    open var downloadTaskDidResume: DownloadTaskDidResumeBlock?
    
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
    init(configuration: URLSessionConfiguration? = nil, rs: ResponseSerializer) {
        var conf = configuration
        if conf == nil {
            conf = URLSessionConfiguration.default
        }

        self.sessionConfiguration = conf!
        self.session = Foundation.URLSession(configuration: self.sessionConfiguration, delegate:nil, delegateQueue:self.operationQueue)
        self.responseSerializer = rs
        self.lock = NSLock()
        
        super.init()
        
        self.operationQueue.maxConcurrentOperationCount = 1
        
        self.session = Foundation.URLSession(configuration: self.sessionConfiguration, delegate:self, delegateQueue:self.operationQueue)
        
        #if !TARGET_OS_WATCH
            self.reachabilityManager = SNReachabilityManager.sharedManager!
        #endif
        
        self.lock = NSLock()
        self.lock.name = "SNURLSessionManagerLockName"
        
        self.session.getTasksWithCompletionHandler{ (dataTasks: [URLSessionDataTask], uploadTasks: [URLSessionUploadTask], downloadTasks:[URLSessionDownloadTask]) -> Void in
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
    open func invalidateSessionCancelingTasks(_ cancelPendingTasks: Bool) {
        DispatchQueue.main.async(execute: {
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
    
    typealias CompletionHandler = (URLResponse, AnyObject?, NSError?)->Void
    
    /**
     Creates an `NSURLSessionDataTask` with the specified request.
     
     - Parameter request: The HTTP request for the request.
     - Parameter uploadProgressBlock: A block object to be executed when the upload progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter downloadProgressBlock: A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
     */
    open func dataTaskWithRequest(_ request: URLRequest, uploadProgress: ProgressBlock? = nil, downloadProgress:ProgressBlock? = nil) -> Future<T> {
        let dataTask = self.session.dataTask(with: request)
        let rt = self.addDelegateForDataTask(dataTask, uploadProgress:uploadProgress, downloadProgress:downloadProgress)
        dataTask.resume()
        
        return rt
    }
    
    
    func addDelegateForDataTask(_ dataTask: URLSessionDataTask, uploadProgress:ProgressBlock?, downloadProgress:ProgressBlock?) -> Future<T>
    {
        let delegate = SNURLSessionManagerTaskDelegate<T, ResponseSerializer>()
        delegate.manager = self
        //delegate.completionHandler = completionHandler
    
        dataTask.taskDescription = self.taskDescriptionForSessionTasks
        
        //self.setDelegate(delegate, forTask:dataTask)
        self.taskDelegates[dataTask.taskIdentifier] = delegate
        
        delegate.uploadProgressBlock = uploadProgress
        delegate.downloadProgressBlock = downloadProgress
        
        return delegate.promise.future
    }

    func addDelegateForUploadTask(_ uploadTask: URLSessionUploadTask, progress:ProgressBlock?) -> Future<T>
    //completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
    {
        let delegate = SNURLSessionManagerTaskDelegate<T, ResponseSerializer>()
        delegate.manager = self
        //delegate.completionHandler = completionHandler;
    
        uploadTask.taskDescription = self.taskDescriptionForSessionTasks
    
        self.taskDelegates[uploadTask.taskIdentifier] = delegate
    
        delegate.uploadProgressBlock = progress
        return delegate.promise.future
    }
    
    func addDelegateForDownloadTask(_ downloadTask: URLSessionDownloadTask, progress: ProgressBlock?,
    destination:SNURLSessionManager<T,ResponseSerializer>.TargetBlock?) -> Future<NSURL>
    {
        let delegate = SNURLSessionManagerTaskDelegate<T, ResponseSerializer>()
        delegate.filePromise = Promise<URL>()
        delegate.manager = self
    
        if (destination != nil) {
            delegate.downloadTaskDidFinishDownloading = { (NSURLSession, task: URLSessionDownloadTask, location: URL) -> URL? in
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
    func uploadTaskWithRequest(_ request: URLRequest, fromFile fileURL:URL, progress: ProgressBlock?) -> URLSessionUploadTask? {
                               // completionHandler:CompletionHandler?
        var uploadTask: URLSessionUploadTask?
        
        url_session_manager_create_task_safely({
            uploadTask = self.session.uploadTask(with: request, fromFile:fileURL)
        })
        
        if (uploadTask == nil) {
            if self.attemptsToRecreateUploadTasksForBackgroundSessions {
                if (self.session.configuration.identifier != nil) {
                    for _ in 0..<SNMaximumNumberOfAttemptsToRecreateBackgroundSessionUploadTask {
                        uploadTask = self.session.uploadTask(with: request, fromFile:fileURL)
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
    func uploadTaskWithRequest(_ request: URLRequest, fromData bodyData:Data, progress:ProgressBlock?) -> URLSessionUploadTask? {
        var uploadTask: URLSessionUploadTask?
        
        url_session_manager_create_task_safely({
            uploadTask = self.session.uploadTask(with: request, from:bodyData)
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
    func uploadTaskWithStreamedRequest(_ request: URLRequest, progress:ProgressBlock?) -> URLSessionUploadTask? {
        var uploadTask: URLSessionUploadTask?
        
        url_session_manager_create_task_safely({
            uploadTask = self.session.uploadTask(withStreamedRequest: request)
        })

        guard let task = uploadTask else { return nil }
        
        self.addDelegateForUploadTask(task, progress:progress)
        
        return task
    }
    
    
    // MARK: Running Download Tasks
    
    
    open typealias TargetBlock = (URL, URLResponse) -> URL?
    /**
     Creates an `NSURLSessionDownloadTask` with the specified request.
     
     - Parameter request: The HTTP request for the request.
     - Parameter 1: A block object to be executed when the download progress is updated. Note this block is called on the session queue, not the main queue.
     - Parameter destination: A block object to be executed in order to determine the destination of the downloaded file. This block takes two arguments, the target path & the server response, and returns the desired file URL of the resulting download. The temporary file used during the download will be automatically deleted after being moved to the returned URL.
     - Parameter completionHandler: A block to be executed when a task finishes. This block has no return value and takes three arguments: the server response, the path of the downloaded file, and the error describing the network or parsing error that occurred, if any.
     
     @warning If using a background `NSURLSessionConfiguration` on iOS, these blocks will be lost when the app is terminated. Background sessions may prefer to use `-setDownloadTaskDidFinishDownloadingBlock:` to specify the URL for saving the downloaded file, rather than the destination block of this method.
     */
    open func downloadTaskWithRequest(_ request: URLRequest, progress:ProgressBlock? = nil, destination:TargetBlock? = nil)-> Future<NSURL> {
        let downloadTask = self.session.downloadTask(with: request)
        
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
    func downloadTaskWithResumeData(_ resumeData: Data, progress:ProgressBlock?, destination:TargetBlock,
                                    completionHandler:CompletionHandler?) -> URLSessionDownloadTask {
        var downloadTask: URLSessionDownloadTask
        //url_session_manager_create_task_safely({
            downloadTask = self.session.downloadTask(withResumeData: resumeData)
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
    func uploadProgressForTask(_ task: URLSessionTask) -> Progress? {
        return self.taskDelegates[task.taskIdentifier]?.uploadProgress
    }
    
    /**
     Returns the download progress of the specified task.
     
     - Parameter task: The session task. Must not be `nil`.
     
     - Returns: An `NSProgress` object reporting the download progress of a task, or `nil` if the progress is unavailable.
     */
    func downloadProgressForTask(_ task: URLSessionTask) -> Progress? {
        return self.taskDelegates[task.taskIdentifier]?.downloadProgress
    }
    
    open func urlSession(_ session: URLSession, downloadTask:URLSessionDownloadTask, didFinishDownloadingTo location:URL) {
        if let delegate = self.taskDelegates[downloadTask.taskIdentifier] {
    
            if self.downloadTaskDidFinishDownloading != nil {
                let fileURL = self.downloadTaskDidFinishDownloading!(session, downloadTask, location)
                
                if fileURL != nil {
                    delegate.downloadFileURL = fileURL
                    do {
                        try FileManager.default.moveItem(at: location, to:fileURL!)
                    }
                    catch _ {
                        // TODO: error
                    }
                }
            }
        
            delegate.urlSession(session, downloadTask:downloadTask, didFinishDownloadingTo:location)
        }
    }
    
    open func urlSession(_ session: URLSession, downloadTask:URLSessionDownloadTask, didWriteData bytesWritten:Int64, totalBytesWritten:Int64, totalBytesExpectedToWrite:Int64) {
        self.downloadTaskDidWriteData?(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        
        if let delegate = self.taskDelegates[downloadTask.taskIdentifier] {
            delegate.downloadProgress.completedUnitCount = totalBytesWritten
            delegate.downloadProgress.totalUnitCount = totalBytesExpectedToWrite

            delegate.downloadProgressBlock?(delegate.downloadProgress)
        }
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        var totalUnitCount = Int64(totalBytesExpectedToSend)
        if(totalUnitCount == NSURLSessionTransferSizeUnknown) {
            if let contentLength = task.originalRequest?.value(forHTTPHeaderField: "Content-Length") {
                totalUnitCount = Int64(contentLength) ?? NSURLSessionTransferSizeUnknown
            }
        }
        
        self.taskDidSendBodyData?(session, task, bytesSent, totalBytesSent, totalUnitCount)
        
        if let delegate = self.taskDelegates[task.taskIdentifier] {
            delegate.uploadProgress.completedUnitCount = totalBytesSent
            delegate.uploadProgress.totalUnitCount = totalUnitCount
            
            delegate.uploadProgressBlock?(delegate.uploadProgress)
        }
    }
    
    open func urlSession(_ session: URLSession, downloadTask:URLSessionDownloadTask, didResumeAtOffset fileOffset:Int64, expectedTotalBytes:Int64) {
        self.downloadTaskDidResume?(session, downloadTask, fileOffset, expectedTotalBytes)
    }
    
    /**
     ## NSSessionDataDelegate.didReceiveData
     
     Sent when data is available for the delegate to consume.  It is assumed that the delegate will retain and not copy the data.  As the data may be discontiguous, you should use [NSData enumerateByteRangesUsingBlock:] to access it.
     */
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let delegate = self.taskDelegates[dataTask.taskIdentifier]
        
        delegate?.urlSession(session, dataTask:dataTask, didReceive:data)
    }

    
    open func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var disposition = Foundation.URLSession.AuthChallengeDisposition.performDefaultHandling
        
        var credential: URLCredential?
        
        if ((self.sessionDidReceiveAuthenticationChallenge) != nil) {
            disposition = self.sessionDidReceiveAuthenticationChallenge!(session, challenge, &credential)
        }
        else {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if self.securityPolicy.evaluateServerTrust(challenge.protectionSpace.serverTrust!, forDomain:challenge.protectionSpace.host) {
                    credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                    if (credential != nil) {
                        disposition = .useCredential
                    }
                    else {
                        disposition = .performDefaultHandling
                    }
                }
                else {
                    disposition = .cancelAuthenticationChallenge
                }
            }
            else {
                disposition = .performDefaultHandling
            }
        }
        
        completionHandler(disposition, credential)
    }
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var disposition = Foundation.URLSession.AuthChallengeDisposition.performDefaultHandling

        var credential: URLCredential?
        
        if (self.taskDidReceiveAuthenticationChallenge != nil) {
            disposition = self.taskDidReceiveAuthenticationChallenge!(session, task, challenge, &credential)
        }
        else {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if self.securityPolicy.evaluateServerTrust(challenge.protectionSpace.serverTrust!, forDomain: challenge.protectionSpace.host) {
                    disposition = .useCredential
                    credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                }
                else {
                    disposition = .cancelAuthenticationChallenge
                }
            }
            else {
                disposition = .performDefaultHandling
            }
        }
        
        completionHandler(disposition, credential);
    }
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // delegate may be nil when completing a task in the background
        if let delegate = self.taskDelegates[task.taskIdentifier] {

            delegate.downloadProgress.completedUnitCount = Int64(delegate.mutableData!.length)
            delegate.downloadProgress.totalUnitCount = Int64(delegate.mutableData!.length)
            delegate.downloadProgressBlock?(delegate.downloadProgress)
            
            delegate.urlSession(session, task:task, didCompleteWithError:error)
            
            self.taskDelegates.removeValue(forKey: task.taskIdentifier)
        }
        
        try! self.taskDidComplete?(session, task)
    }
}


// MARK: Notifications


/// Posted when a task resumes.
let SNNetworkingTaskDidResumeNotification = "com.alamofire.networking.task.resume"

/// Posted when a task finishes executing. Includes a userInfo dictionary with additional information about the task.
let SNNetworkingTaskDidCompleteNotification = "com.alamofire.networking.task.complete"

/// Posted when a task suspends its execution.
let SNNetworkingTaskDidSuspendNotification = "com.alamofire.networking.task.suspend"

/// Posted when a session is invalidated.
let SNURLSessionDidInvalidateNotification = "com.alamofire.networking.session.invalidate"

/// Posted when a session download task encountered an error when moving the temporary download file to a specified destination.
let SNURLSessionDownloadTaskDidFailToMoveFileNotification = "com.alamofire.networking.session.download.file-manager-error"

/// The raw response data of the task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if response data exists for the task.
let SNNetworkingTaskDidCompleteResponseDataKey = "com.alamofire.networking.complete.finish.responsedata"

/// The serialized response object of the task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if the response was serialized.
let SNNetworkingTaskDidCompleteSerializedResponseKey = "com.alamofire.networking.task.complete.serializedresponse"

/// The response serializer used to serialize the response. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if the task has an associated response serializer.
let SNNetworkingTaskDidCompleteResponseSerializerKey = "com.alamofire.networking.task.complete.responseserializer"

/// The file path associated with the download task. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if an the response data has been stored directly to disk.
let SNNetworkingTaskDidCompleteAssetPathKey = "com.alamofire.networking.task.complete.assetpath"

/// Any error associated with the task, or the serialization of the response. Included in the userInfo dictionary of the `AFNetworkingTaskDidCompleteNotification` if an error exists.
let SNNetworkingTaskDidCompleteErrorKey = "com.alamofire.networking.task.complete.error"


func url_session_manager_create_task_safely(_ block: ()->()) {
    block()
}
