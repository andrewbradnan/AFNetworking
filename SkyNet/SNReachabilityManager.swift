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

enum ReachabilityError: ErrorType {
    case UnableToSetCallback
    case UnableToSetDispatchQueue
    case NotifierNotRunning
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

    private let _networkReachability: SCNetworkReachabilityRef
    public var networkReachability: SCNetworkReachabilityRef {
        get {
            return _networkReachability
        }
    }
    
    public static let sharedManager = SNReachabilityManager()

    
    public var isConnectionAvailble: Bool {
        return self.isReachable && !self.isConnectionRequired
    }
    
    public var isTransientConnection: Bool {
        return self.reachabilityFlags.contains(.TransientConnection)
    }
    public var isReachable: Bool {
        return self.reachabilityFlags.contains(.Reachable)
    }
    public var isConnectionRequired: Bool {
        return self.reachabilityFlags.contains(.ConnectionRequired)
    }
    public var isConnectionOnTraffic: Bool {
        return self.reachabilityFlags.contains(.ConnectionOnTraffic)
    }
    public var isInterventionRequired: Bool {
        return self.reachabilityFlags.contains(.InterventionRequired)
    }
    public var isConnectionOnDemand: Bool {
        return self.reachabilityFlags.contains(.ConnectionOnDemand)
    }
    public var isLocalAddress: Bool {
        return self.reachabilityFlags.contains(.IsLocalAddress)
    }
    public var isDirect: Bool {
        return self.reachabilityFlags.contains(.IsDirect)
    }
    public var isWWAN: Bool {
        return self.reachabilityFlags.contains(.IsWWAN)
    }
    public var isConnectionAutomatic: Bool {
        return self.reachabilityFlags.contains(.ConnectionAutomatic)
    }

    public convenience init?(domain: String) {
        
        if let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, domain) {
            self.init(reachability:reachability)
        }
        else {
            return nil
        }
    }
    
    public convenience init?(address: UInt32) {
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
    }
    
    private let reachabilitySerialQueue = dispatch_queue_create("com.phyn.reachability", DISPATCH_QUEUE_SERIAL)
    private var notifierRunning: Bool = false
    
    public func startMonitoring() throws {
        self.stopMonitoring()
        
        guard !notifierRunning else { throw ReachabilityError.NotifierNotRunning }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = bridge(self)
        
        if !SCNetworkReachabilitySetCallback(self.networkReachability, callback, &context) {
            stopMonitoring()
            throw ReachabilityError.UnableToSetCallback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(self.networkReachability, self.reachabilitySerialQueue) {
            stopMonitoring()
            throw ReachabilityError.UnableToSetDispatchQueue
        }
        
        notifierRunning = true

        // Perform an intial check
        var flags: SCNetworkReachabilityFlags = []

        if SCNetworkReachabilityGetFlags(self.networkReachability, &flags) == false {
            return
        }
        self.reachabilityFlags = flags
        self.reachabilityChanged.fire(self.reachabilityFlags)
    }
    
    func stopMonitoring() {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes)
    }
}

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
