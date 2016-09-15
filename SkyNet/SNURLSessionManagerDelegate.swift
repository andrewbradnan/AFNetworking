/**
 # SNURLSessionManagerDelegate.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/3/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation
import FutureKit

class SNURLSessionManagerTaskDelegate<T, RS : SNURLResponseSerializer where T == RS.Element> : NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    var promise = Promise<T>()
    internal var filePromise: Promise<NSURL>?
    
    weak var manager: SNURLSessionManager<T, RS>?

    var mutableData: NSMutableData? = NSMutableData()
    
    typealias DownloadTaskDidFinishDownloadingBlock = (Foundation.URLSession, URLSessionDownloadTask, URL) -> URL?
    
    var uploadProgress: Progress
    var downloadProgress: Progress
    var downloadFileURL: URL?
    var downloadTaskDidFinishDownloading: DownloadTaskDidFinishDownloadingBlock?
    var uploadProgressBlock: ProgressBlock?
    var downloadProgressBlock: ProgressBlock?
    //var completionHandler: AFURLSessionTaskCompletionHandler?


    override init() {
        self.uploadProgress = Progress(parent:nil, userInfo:nil)
        self.uploadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown
        self.downloadProgress = Progress(parent:nil, userInfo:nil)
        self.downloadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown
    }

    // MARK: NSProgress Tracking
    
    fileprivate func setupProgressForTask(_ task: URLSessionTask) {
        self.uploadProgress.totalUnitCount = task.countOfBytesExpectedToSend
        self.downloadProgress.totalUnitCount = task.countOfBytesExpectedToReceive
        
        self.uploadProgress.isCancellable = true
        self.uploadProgress.cancellationHandler = { [weak task] in task?.cancel() }
        self.uploadProgress.isPausable = true
        self.uploadProgress.pausingHandler = { [weak task] in task?.suspend() }
        if #available(iOS 9.0, *) {
            self.uploadProgress.resumingHandler = { [weak task] in task?.resume() }
        }
        
        self.downloadProgress.isCancellable=true
        self.downloadProgress.cancellationHandler = {[weak task] in task?.cancel() }
        self.downloadProgress.isPausable = true
        self.downloadProgress.pausingHandler = {[weak task] in task?.suspend() }
        if #available(iOS 9.0, *) {
            self.downloadProgress.resumingHandler = {[weak task] in task?.resume() }
        }
        
        task.addObserver(self, forKeyPath:"countOfBytesReceived", options:.new, context:nil)
        task.addObserver(self, forKeyPath:"countOfBytesExpectedToReceive", options:.new, context:nil)
        task.addObserver(self, forKeyPath:"countOfBytesSent", options:.new, context:nil)
        task.addObserver(self, forKeyPath:"countOfBytesExpectedToSend", options:.new, context:nil)
        
        self.downloadProgress.addObserver(self, forKeyPath:"fractionCompleted", options:.new, context:nil)
        self.uploadProgress.addObserver(self, forKeyPath:"fractionCompleted", options:.new, context:nil)
    }
    
    fileprivate func cleanupProgressForTask(_ task: URLSessionTask) {
        task.removeObserver(self, forKeyPath:"countOfBytesReceived")
        task.removeObserver(self, forKeyPath:"countOfBytesExpectedToReceive")
        task.removeObserver(self, forKeyPath:"countOfBytesSent")
        task.removeObserver(self, forKeyPath:"countOfBytesExpectedToSend")
        self.downloadProgress.removeObserver(self, forKeyPath:"fractionCompleted")
        self.uploadProgress.removeObserver(self, forKeyPath:"fractionCompleted")
    }
    
    /*
        - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
            if ([object isKindOfClass:[NSURLSessionTask class]] || [object isKindOfClass:[NSURLSessionDownloadTask class]]) {
                if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesReceived))]) {
                    self.downloadProgress.completedUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
                } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))]) {
                    self.downloadProgress.totalUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
                } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesSent))]) {
                    self.uploadProgress.completedUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
                } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesExpectedToSend))]) {
                    self.uploadProgress.totalUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
                }
            }
            else if ([object isEqual:self.downloadProgress]) {
                if (self.downloadProgressBlock) {
                    self.downloadProgressBlock(object);
                }
            }
            else if ([object isEqual:self.uploadProgress]) {
                if (self.uploadProgressBlock) {
                    self.uploadProgressBlock(object);
                }
            }
}
 */

    // MARK: NSURLSessionTaskDelegate
    
    /** 
     ## NSURLSessionTaskDelegate.willPerformHTTPRedirection

        An HTTP request is attempting to perform a redirection to a different URL. You must invoke the completion routine to allow the redirection, allow the redirection with a modified request, or pass nil to the completionHandler to cause the body of the redirection response to be delivered as the payload of this request. The default is to follow redirections.

        For tasks in background sessions, redirections will always be followed and this method will not be called.
     */
    
    func urlSession(_ session: URLSession, task:URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest:URLRequest, completionHandler:@escaping (URLRequest?) -> Void) {
        
    }
    
    /**
     ## NSURLSessionTaskDelegate.didReceiveChallenge
     
     The task has received a request specific authentication challenge.  If this delegate is not implemented, the session specific authentication challenge will *NOT* be called and the behavior will be the same as using the default handling disposition.
     */
    
    func urlSession(_ session: URLSession, task:URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler:@escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
    }
    
    /**
     ## NSURLSessionTaskDelegate.needNewBodyStream
     
     Sent if a task requires a new, unopened body stream.  This may be necessary when authentication has failed for any request that involves a body stream.
     */
    
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler:@escaping (InputStream?)->Void) {
        
    }
    
    /**
     ## NSURLSessionTaskDelegate.didSendBodyData
     
     Sent periodically to notify the delegate of upload progress.  This information is also available as properties of the task.
     */
    
    func urlSession(_ session: URLSession, task:URLSessionTask, didSendBodyData bytesSent:Int64, totalBytesSent:Int64, totalBytesExpectedToSend:Int64) {
        
    }
    
    // Mark - NSURLSessionDelegate
    
    /**
     ## NSURLSessionDelegate.didBecomeInvalidWithError
     
     The last message a session receives.  A session will only become invalid because of a systemic error or when it has been explicitly invalidated, in which case the error parameter will be nil.
     */
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        
    }
    
    /**
     ## NSURLSessionDelegate.didReceiveChallenge
     
     If implemented, when a connection level authentication challenge has occurred, this delegate will be given the opportunity to provide authentication credentials to the underlying connection. Some types of authentication will apply to more than one request on a given connection to a server (SSL Server Trust challenges).  If this delegate message is not implemented, the behavior will be to use the default handling, which may involve user interaction.
     */
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
    }
    
    /**
     If an application has received an -application:handleEventsForBackgroundURLSession:completionHandler: message, the session delegate will receive this message to indicate that all messages previously enqueued for this session have been delivered.  At this time it is safe to invoke the previously stored completion handler, or to begin any internal updates that will result in invoking the completion handler.
     */
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        
    }

    // Mark - NSURLSessionDataDelegate
    
    /**
     ## NSURLSessionDataDelegate.didReceiveResponse
     
     The task has received a response and no further messages will be received until the completion block is called. The disposition allows you to cancel a request or to turn a data task into a download task. This delegate message is optional - if you do not implement it, you can get the response as a property of the task.
     
     This method will not be called for background upload tasks (which cannot be converted to download tasks).
     */

//    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
//    }
    
    /**
     ## NSURLSessionDataDelegate.didBecomeDownloadTask
     
     Notification that a data task has become a download task.  No future messages will be sent to the data task.
     */
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        
    }
    
    /**
     ## NSDataSessionDataDelegate.didBecomeStreamTask
     
     Notification that a data task has become a bidirectional stream task.  No future messages will be sent to the data task.  The newly created streamTask will carry the original request and response as properties.
     
     For requests that were pipelined, the stream object will only allow reading, and the object will immediately issue a -URLSession:writeClosedForStream:.  Pipelining can be disabled for all requests in a session, or by the NSURLRequest HTTPShouldUsePipelining property.
     
     The underlying connection is no longer considered part of the HTTP connection cache and won't count against the total number of connections per host.
     */
    @available(iOS 9.0, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        
    }
    
    /**
     ## NSSessionDataDelegate.didReceiveData
     
     Sent when data is available for the delegate to consume.  It is assumed that the delegate will retain and not copy the data.  As the data may be discontiguous, you should use [NSData enumerateByteRangesUsingBlock:] to access it.
     */
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.mutableData!.append(data)
        
        self.downloadProgress.completedUnitCount += data.count
        
        self.downloadProgressBlock?(self.downloadProgress)
    }
    
    /**
     ## NSSessionDataDelegate.willCacheResponse
     
     Invoke the completion routine with a valid NSCachedURLResponse to allow the resulting data to be cached, or pass nil to prevent caching. Note that there is no guarantee that caching will be attempted for a given resource, and you should not rely on this message to receive the resource data.
     */
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        
    }

    /**
     ## didCompleteWithError
     
     Sent as the last message related to a specific task.  Error may be nil, which implies that no error occurred and this task is complete.
     */
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
//        __block NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
//        userInfo[SNNetworkingTaskDidCompleteResponseSerializerKey] = manager.responseSerializer;
//        
//        //Performance Improvement from #2672
        var data: Data?
        if self.mutableData != nil {
            data = self.mutableData!.copy() as? Data
            self.mutableData = nil
        }
//            data = [self.mutableData copy];
//            //We no longer need the reference, so nil it out to gain back some memory.
//            self.mutableData = nil;
//        }
//        
//        if (self.downloadFileURL) {
//            userInfo[SNNetworkingTaskDidCompleteAssetPathKey] = self.downloadFileURL
//        } else if (data) {
//            userInfo[SNNetworkingTaskDidCompleteResponseDataKey] = data
//        }
        
        
        // TODO: Check for NSURLErrorCancel
        if let error = error {
            // userInfo[SNNetworkingTaskDidCompleteErrorKey] = error
            
            (manager!.completionQueue).async(group: manager!.completionGroup, execute: {
                self.promise.completeWithFail(error)
            })
        }
        else {
            if let r = task.response, let d = data {
                url_session_manager_processing_queue.async(execute: { () -> Void in
                    do {
                        let responseObject = try self.manager!.responseSerializer.responseObjectForResponse(r, data:d)
                        self.promise.completeWithSuccess(responseObject)
    //                    if (self.downloadFileURL) {
    //                        responseObject = self.downloadFileURL;
    //                    }
    //                    
    //                    userInfo[AFNetworkingTaskDidCompleteSerializedResponseKey] = responseObject
                    }
                    catch let e {
                        self.promise.completeWithFail(e)
                    }
                })
            }
            else {
                self.promise.completeWithFail(SNError.InvalidResponse)
            }
        }
    }
    
    // MARK: NSURLSessionDownloadTaskDelegate
    
    /**
     ## NSURLSessionDownloadTaskDelegate.didFinishDownloadingToURL
     
     Sent when a download task that has completed a download.  The delegate should copy or move the file at the given location to a new location as it will be removed when the delegate message returns. URLSession:task:didCompleteWithError: will still be called.
     */
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if (self.downloadTaskDidFinishDownloading != nil) {
            self.downloadFileURL = self.downloadTaskDidFinishDownloading!(session, downloadTask, location)
                
            do {
                try FileManager.default.moveItem(at: location, to:self.downloadFileURL!)
            }
            catch let e {
                self.filePromise!.completeWithFail(e)
                return
            }
        }
        
        self.downloadFileURL = self.downloadFileURL ?? location
        
        guard let url = self.downloadFileURL else { self.filePromise!.completeWithFail(SNError.NoLocation); return }
        
        self.filePromise!.completeWithSuccess(url)
    }
    
    /**
     ## NSURLSessionDownloadTaskDelegate.didWriteData
     
     Sent periodically to notify the delegate of download progress. 
     */
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        NSLog("foo")
    }
    
    /**
     ## NSURLSessionDownloadTaskDelegate.didResumeAtOffset
     
     Sent when a download has been resumed. If a download failed with an error, the -userInfo dictionary of the error will contain an NSURLSessionDownloadTaskResumeData key, whose value is the resume data.
     */
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        
    }
}
