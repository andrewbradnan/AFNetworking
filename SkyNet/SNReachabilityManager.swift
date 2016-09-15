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

enum ReachabilityError: Error {
    case unableToSetCallback
    case unableToSetDispatchQueue
    case notifierNotRunning
}

func callback(_ reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer) {
    let mgr: SNReachabilityManager = bridge(info)

    mgr.reachabilityFlags = flags
    DispatchQueue.main.async {
        mgr.reachabilityChanged.fire(flags)
    }
}

extension SCNetworkReachabilityFlags {
    public static func reachabilityFlags(_ flags: SCNetworkReachabilityFlags) -> String {
        return String(format: "%@%@%@%@%@%@%@%@%@",
                      flags.contains(.isWWAN)               ? "W" : "-",
                      flags.contains(.reachable)            ? "R" : "-",
                      flags.contains(.connectionRequired)   ? "c" : "-",
                      flags.contains(.transientConnection)  ? "t" : "-",
                      flags.contains(.interventionRequired) ? "i" : "-",
                      flags.contains(.connectionOnTraffic)  ? "C" : "-",
                      flags.contains(.connectionOnDemand)   ? "D" : "-",
                      flags.contains(.isLocalAddress)       ? "l" : "-",
                      flags.contains(.isDirect)             ? "d" : "-")
    }
}

open class SNReachabilityManager {
    
    open var reachabilityChanged = Event<SCNetworkReachabilityFlags>()
    open var reachabilityFlags: SCNetworkReachabilityFlags = []

    fileprivate let _networkReachability: SCNetworkReachability
    open var networkReachability: SCNetworkReachability {
        get {
            return _networkReachability
        }
    }
    
    open static let sharedManager = SNReachabilityManager()

    
    open var isConnectionAvailble: Bool {
        return self.isReachable && (!self.isConnectionRequired || self.canConnectWithoutUserInteraction)
    }
    open var isTransientConnection: Bool {
        return self.reachabilityFlags.contains(.transientConnection)
    }
    open var isReachable: Bool {
        return self.reachabilityFlags.contains(.reachable)
    }
    open var isConnectionRequired: Bool {
        return self.reachabilityFlags.contains(.connectionRequired)
    }
    open var isConnectionOnTraffic: Bool {
        return self.reachabilityFlags.contains(.connectionOnTraffic)
    }
    open var isInterventionRequired: Bool {
        return self.reachabilityFlags.contains(.interventionRequired)
    }
    open var isConnectionOnDemand: Bool {
        return self.reachabilityFlags.contains(.connectionOnDemand)
    }
    open var isLocalAddress: Bool {
        return self.reachabilityFlags.contains(.isLocalAddress)
    }
    open var isDirect: Bool {
        return self.reachabilityFlags.contains(.isDirect)
    }
    open var isWWAN: Bool {
        return self.reachabilityFlags.contains(.isWWAN)
    }
    open var isConnectionAutomatic: Bool {
        return self.reachabilityFlags.contains(.connectionAutomatic)
    }
    open var canConnectAutomatically: Bool {
        return self.reachabilityFlags.contains(.connectionOnDemand) || self.reachabilityFlags.contains(.connectionOnTraffic)
    }
    open var canConnectWithoutUserInteraction: Bool {
        return self.canConnectAutomatically && !self.reachabilityFlags.contains(.interventionRequired)
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
        localWifiAddress.sin_len = UInt8(MemoryLayout.size(ofValue: localWifiAddress))
        localWifiAddress.sin_family = sa_family_t(AF_INET)
        
        // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
        localWifiAddress.sin_addr.s_addr = in_addr_t(address.bigEndian)
        
        guard let ref = withUnsafePointer(to: &localWifiAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else { return nil }
        
        self.init(reachability: ref)
    }
    
    public convenience init?() {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else {
            return nil
        }
        
        self.init(reachability: defaultRouteReachability)
    }

    public init(reachability:SCNetworkReachability) {
        self._networkReachability = reachability
    }
    
    fileprivate let reachabilitySerialQueue = DispatchQueue(label: "com.phyn.reachability", attributes: [])
    fileprivate var notifierRunning: Bool = false
    
    open func startMonitoring() throws {
        self.stopMonitoring()
        
        guard !notifierRunning else { throw ReachabilityError.notifierNotRunning }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = bridge(self)
        
        if !SCNetworkReachabilitySetCallback(self.networkReachability, callback, &context) {
            stopMonitoring()
            throw ReachabilityError.unableToSetCallback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(self.networkReachability, self.reachabilitySerialQueue) {
            stopMonitoring()
            throw ReachabilityError.unableToSetDispatchQueue
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
    
    open func stopMonitoring() {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), CFRunLoopMode.commonModes as! CFString)
        notifierRunning = false
    }
}

func bridge<T : AnyObject>(_ obj : T) -> UnsafeMutableRawPointer {
    return UnsafeMutablePointer(Unmanaged.passUnretained(obj).toOpaque())
    // return unsafeAddressOf(obj) // ***
}

func bridge<T : AnyObject>(_ ptr : UnsafeMutableRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(OpaquePointer(ptr)).takeUnretainedValue()
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
