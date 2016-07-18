/**
 # SNNetworkReachabilityManager.swift
## SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/7/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation
import SystemConfiguration
import SwiftCommon

enum SNReachabilityStatus : Int {
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
    let mgr: SNReachabilityManager = bridge(info)

    mgr.reachabilityFlags = flags
    dispatch_async(dispatch_get_main_queue()) {
        mgr.reachabilityChanged.fire(flags)
    }
}


public class SNReachabilityManager {
    
    public var reachabilityChanged = Event<SCNetworkReachabilityFlags>()
    public var reachabilityFlags: SCNetworkReachabilityFlags = []

    var networkReachabilityStatus: SNReachabilityStatus  // TODO: CellSink
    
    private var _networkReachability: SCNetworkReachabilityRef?
    public var networkReachability: SCNetworkReachabilityRef? {
        get {
            return _networkReachability
        }
    }
    
    public static let sharedManager = SNReachabilityManager()
    
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
    public convenience init?(domain: String) {
        
        if let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, domain) {
            self.init(reachability:reachability)
        }
        else {
            return nil
        }
    }
    
    /*
     public static func managerForAddress(address: String, port: String? = nil) -> SNReachabilityManager {
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
     return SNReachabilityManager(reachability:reachability)
     }
     */
    
    convenience init?(address: UInt32) {
        
        var localWifiAddress: sockaddr_in = sockaddr_in(sin_len: __uint8_t(0), sin_family: sa_family_t(0), sin_port: in_port_t(0), sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        localWifiAddress.sin_len = UInt8(sizeofValue(localWifiAddress))
        localWifiAddress.sin_family = sa_family_t(AF_INET)
        
        // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
        localWifiAddress.sin_addr.s_addr = in_addr_t(address.bigEndian)
        
        guard let ref = withUnsafePointer(&localWifiAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else { return nil }
        
        self.init(reachability: ref)
    }
    
    convenience init?() {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(&zeroAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else {
            return nil
        }
        
        self.init(reachability: defaultRouteReachability)
    }

    public init(reachability:SCNetworkReachabilityRef) {
        self._networkReachability = reachability
        self.networkReachabilityStatus = .Unknown
    }
    
    public var isReachable: Bool {
        get {
            let reachable = self.reachabilityFlags.contains(.Reachable)
            let wwan = self.isReachableViaWWAN
            let wifi = self.isReachableViaWiFi
            return reachable // || wwan || wifi
        }
    }
    
    public var isReachableViaWWAN: Bool {
        get {
            return self.reachabilityFlags.contains(.IsWWAN)
        }
    }
    
    public var isReachableViaWiFi : Bool {
        get {
            return self.reachabilityFlags.contains(.IsLocalAddress)
        }
    }
    
    private let reachabilitySerialQueue = dispatch_queue_create("com.phyn.reachability", DISPATCH_QUEUE_SERIAL)
    private var notifierRunning: Bool = false
    //private var reachabilityRef: SCNetworkReachability?
    
    public func startMonitoring() throws {
        self.stopMonitoring()
        
        if self.networkReachability == nil {
            return
        }
        
        guard !notifierRunning else { return }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = bridge(self)
        
        if !SCNetworkReachabilitySetCallback(networkReachability!, callback, &context) {
            stopMonitoring()
            throw ReachabilityError.UnableToSetCallback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(networkReachability!, self.reachabilitySerialQueue) {
            stopMonitoring()
            throw ReachabilityError.UnableToSetDispatchQueue
        }
        
        notifierRunning = true

        // Perform an intial check

        if SCNetworkReachabilityGetFlags(networkReachability!, &self.reachabilityFlags) == false {
            return
        }
        self.reachabilityChanged.fire(self.reachabilityFlags)
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


func bridge<T : AnyObject>(obj : T) -> UnsafeMutablePointer<Void> {
    return UnsafeMutablePointer(Unmanaged.passUnretained(obj).toOpaque())
    // return unsafeAddressOf(obj) // ***
}

func bridge<T : AnyObject>(ptr : UnsafeMutablePointer<Void>) -> T {
    return Unmanaged<T>.fromOpaque(COpaquePointer(ptr)).takeUnretainedValue()
    // return unsafeBitCast(ptr, T.self) // ***
}


//func bridge<T : AnyObject>(obj : T) -> UnsafePointer<Void> {
//    return UnsafePointer(OpaquePointer(bitPattern: Unmanaged.passUnretained(obj)))
//    // return unsafeAddress(of: obj) // ***
//}
//
//func bridge<T : AnyObject>(ptr : UnsafePointer<Void>) -> T {
//    return Unmanaged<T>.fromOpaque(OpaquePointer(ptr)).takeUnretainedValue()
//    // return unsafeBitCast(ptr, to: T.self) // ***
//}
