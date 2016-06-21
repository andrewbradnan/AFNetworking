/**
 # SFNetworkReachabilityManager.swift
## SFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/7/16
 - Copyright: Copyright © 2016 SFNetworking. All rights reserved.
 */

import Foundation
import SystemConfiguration
import SwiftCommon

enum SFNetworkReachabilityStatus : Int {
    case Unknown          = -1
    case NotReachable     = 0
    case ReachableViaWWAN = 1
    case ReachableViaWiFi = 2
}

enum ReachabilityError: ErrorType {
    case UnableToSetCallback
    case UnableToSetDispatchQueue
}

func callback(reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) {
    let mgr = Unmanaged<SFNetworkReachabilityManager>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
    
    dispatch_async(dispatch_get_main_queue()) {
        mgr.reachabilityChanged.fire(flags)
    }
}


public class SFNetworkReachabilityManager {
    
    public var reachabilityChanged = Event<SCNetworkReachabilityFlags>()
    
    private var _networkReachability: SCNetworkReachabilityRef?
    public var networkReachability: SCNetworkReachabilityRef? {
        get {
            return _networkReachability
        }
    }
    var networkReachabilityStatus: SFNetworkReachabilityStatus  // TODO: CellSink
    //var networkReachabilityStatusBlock: SFNetworkReachabilityStatusBlock    // TODO: Event
    
    public static let sharedManager = SFNetworkReachabilityManager.manager()
    
    /*
     func isConnectionAvailble()->Bool{
     
     var rechability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "www.apple.com").takeRetainedValue()
     
     var flags : SCNetworkReachabilityFlags = 0
     
     if SCNetworkReachabilityGetFlags(rechability, &flags) == 0
     {
     return false
     }
     
     let isReachable = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
     let needsConnection = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
     return (isReachable && !needsConnection)
     }
     */
    public static func managerForDomain(domain: String) -> SFNetworkReachabilityManager? {
        var rt: SFNetworkReachabilityManager?
        
        if let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, domain) {
            rt = SFNetworkReachabilityManager(reachability:reachability)
        }
        return rt
    }
    
    /*
     public static func managerForAddress(address: String, port: String? = nil) -> SFNetworkReachabilityManager {
     var hints = addrinfo(
     ai_flags: 0,
     ai_family: AF_UNSPEC,
     ai_socktype: SOCK_STREAM,
     ai_protocol: IPPROTO_TCP,
     ai_addrlen: 0,
     ai_canonname: nil,
     ai_addr: nil,
     ai_next: nil)
     
     var result: UnsafeMutablePointer<addrinfo>
     
     let error = getaddrinfo(address, port ?? "", &hints, &result)
     
     let reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, addrinfo)
     return SFNetworkReachabilityManager(reachability:reachability)
     }
     */
    
     static func manager() -> SFNetworkReachabilityManager? {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(&zeroAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else {
            return nil
        }
        
        return SFNetworkReachabilityManager(reachability: defaultRouteReachability)
        
//        var flags : SCNetworkReachabilityFlags = []
//        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
//            return nil
//        }
//        
//        let isReachable = flags.contains(.Reachable)
//        let needsConnection = flags.contains(.ConnectionRequired)
        
        // For Swift 3, replace the last two lines by
        // let isReachable = flags.contains(.reachable)
        // let needsConnection = flags.contains(.connectionRequired)
     }
     
    init(reachability:SCNetworkReachabilityRef) {
        self._networkReachability = reachability
        self.networkReachabilityStatus = .Unknown
    }
    
    public var isReachable: Bool {
        get {
            return self.isReachableViaWWAN || self.isReachableViaWiFi
        }
    }
    
    public var isReachableViaWWAN: Bool {
        get {
            return self.networkReachabilityStatus == .ReachableViaWWAN
        }
    }
    
    public var isReachableViaWiFi : Bool {
        get {
            return self.networkReachabilityStatus == .ReachableViaWiFi
        }
    }
    
    private var notifierRunning: Bool = false
    private var reachabilityRef: SCNetworkReachability?
    
    public func startMonitoring() throws {
        self.stopMonitoring()
        
        if self.networkReachability == nil {
            return
        }
        
//        let callback = { [weak self] (status: SFNetworkReachabilityStatus) in
//            if let this = self {
//                this.networkReachabilityStatus = status
//                //this.networkReachabilityStatusBlock?(status)
//            }
//        }
        
        guard !notifierRunning else { return }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutablePointer(Unmanaged.passUnretained(self).toOpaque())
        
        if !SCNetworkReachabilitySetCallback(reachabilityRef!,  { (_, flags, _) in
            print(flags)
            }, &context) {
            stopMonitoring()
            throw ReachabilityError.UnableToSetCallback
        }
        
//        if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef!, reachabilitySerialQueue) {
//            stopMonitoring()
//            throw ReachabilityError.UnableToSetDispatchQueue
//        }
        
        // Perform an intial check
        //dispatch_async(dispatch_get_main_queue()) { () -> Void in
            //let flags = self.reachabilityFlags
            //self.reachabilityChanged.fire(self.networkReachabilityStatus)
        //}
        
        notifierRunning = true
    }
    
    func stopMonitoring() {
        if self.networkReachability == nil {
            return
        }
        
        SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability!, CFRunLoopGetMain(), kCFRunLoopCommonModes)
    }
    
    
    //func localizedNetworkReachabilityStatusString() -> String {
    //    return AFStringFromNetworkReachabilityStatus(self.networkReachabilityStatus)
    // }
    
    
}


/*!
	@typedef SCNetworkReachabilityCallBack
	@discussion Type of the callback function used when the
 reachability of a network address or name changes.
	@param target The SCNetworkReachability reference being monitored
 for changes.
	@param flags The new SCNetworkReachabilityFlags representing the
 reachability status of the network address/name.
	@param info A C pointer to a user-specified block of data.
 */
//var callback = @convention(c) (SCNetworkReachability, SCNetworkReachabilityFlags, UnsafeMutablePointer<Void>) -> Void
