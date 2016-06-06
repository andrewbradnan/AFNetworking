/**
 # SFSecurityPolicy.swift
 ##  AFNetworking
 
 - Author: Andrew Bradnan
 - Date: 6/2/16
 - Copyright: Copyright © 2016 SFNetworking. All rights reserved.
 */

import Foundation

enum SFSSLPinningMode {
    case None
    case PublicKey
    case Certificate
}

/**
 `AFSecurityPolicy` evaluates server trust against pinned X.509 certificates and public keys over secure connections.
 
 Adding pinned SSL certificates to your app helps prevent man-in-the-middle attacks and other vulnerabilities. Applications dealing with sensitive customer data or financial information are strongly encouraged to route all communication over an HTTPS connection with SSL pinning configured and enabled.
 */


class SFSecurityPolicy : NSObject, NSSecureCoding, NSCopying {
    
    /**
     The criteria by which server trust should be evaluated against the pinned SSL certificates. Defaults to `AFSSLPinningModeNone`.
     */
    let pinningMode: SFSSLPinningMode = .None
    
    /**
     The certificates used to evaluate server trust according to the SSL pinning mode.
     
     By default, this property is set to any (`.cer`) certificates included in the target compiling AFNetworking. Note that if you are using AFNetworking as embedded framework, no certificates will be pinned by default. Use `certificatesInBundle` to load certificates from your target, and then create a new policy by calling `policyWithPinningMode:withPinnedCertificates`.
     
     Note that if pinning is enabled, `evaluateServerTrust:forDomain:` will return true if any pinned certificate matches.
     */
    private var _pinnedCertificates: Set<NSData>?
    var pinnedCertificates: Set<NSData>? {
        get { return _pinnedCertificates }
        set(value) {
            _pinnedCertificates = value
        
            self.pinnedPublicKeys = self._pinnedCertificates?.map { AFPublicKeyForCertificate($0) }
        }
    }
    
    private var pinnedPublicKeys = Set<SecKey>()
    
    /**
     Whether or not to trust servers with an invalid or expired SSL certificates. Defaults to `false`.
     */
    var allowInvalidCertificates: Bool
    
    /**
     Whether or not to validate the domain name in the certificate's CN field. Defaults to `true`.
     */
    var validatesDomainName: Bool = true
    
    
    // Mark: Getting Certificates from the Bundle
    
    
    /**
     Returns any certificates included in the bundle. If you are using AFNetworking as an embedded framework, you must use this method to find the certificates you have included in your app bundle, and use them when creating your security policy by calling `policyWithPinningMode:withPinnedCertificates`.
     
     - Returns: The certificates included in the given bundle.
     */
    static func certificatesInBundle(bundle: NSBundle) -> Set<NSData> {
        let paths = bundle.pathsForResourcesOfType("cer", inDirectory:".")
        let rgOfData = paths.flatMap{ NSData(contentsOfFile:$0) }   // flatMap nixes the .None's
        
        return Set<NSData>(rgOfData)
    }

    static var defaultPinnedCertificates: Set<NSData> = SFSecurityPolicy.getDefaultPinnedCertificates()
        
    static func getDefaultPinnedCertificates() -> Set<NSData> {
        let bundle = NSBundle(forClass: SFSecurityPolicy.self)
        return certificatesInBundle(bundle)
    }

    
    // Mark: Getting Specific Security Policies
    
    
    /**
     Returns the shared default security policy, which does not allow invalid certificates, validates domain name, and does not validate against pinned certificates or public keys.
     
     - Returns: The default security policy.
     */
    static let defaultPolicy = SFSecurityPolicy()
    
    
    // Mark: Initialization
    
    
    /**
     Creates and returns a security policy with the specified pinning mode.
     
     - Parameter pinningMode: The SSL pinning mode.
     
     - Returns: A new security policy.
     */
//    init(pinningMode: AFSSLPinningMode) {
//        self.init(pinningMode:pinningMode, withPinnedCertificates:[self defaultPinnedCertificates]];
//        
//    }
    
    /**
     Creates and returns a security policy with the specified pinning mode.
     
     - Parameter pinningMode: The SSL pinning mode.
     - Parameter pinnedCertificates: The certificates to pin against.
     
     - Returns: A new security policy.
     */
    init(pinningMode: SFSSLPinningMode, withPinnedCertificates: Set<NSData>? = SFSecurityPolicy.defaultPinnedCertificates) {
        self.SSLPinning = pinningMode
        self.pinnedCertificates = withPinnedCertificates
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.SSLPinningMode = aDecoder.decodeObjectOfClass(NSNumber.self, forKey:#selector(SSLPinningMode))
        self.allowInvalidCertificates = aDecoder.decodeBoolForKey(#selector(allowInvalidCertificates))
        self.validatesDomainName = aDecoder.decodeBoolForKey(#selector(validatesDomainName))
        self.pinnedCertificates = aDecoder.decodeObjectOfClass(NSArray.self, forKey:#selector(pinnedCertificates))

    }
    
    static var supportsSecureCoding: Bool { get { return true }}

    
    // Mark: Evaluating Server Trust
    
    
    /**
     Whether or not the specified server trust should be accepted, based on the security policy.
     
     This method should be used when responding to an authentication challenge from a server.
     
     - Parameter serverTrust: The X.509 certificate trust of the server.
     - Parameter domain: The domain of serverTrust. If `nil`, the domain will not be validated.
     
     - Returns: Whether or not to trust the server.
     */
    func evaluateServerTrust(serverTrust: SecTrustRef, forDomain domain: String?) -> Bool
    {
        if domain && self.allowInvalidCertificates && self.validatesDomainName && (self.SSLPinningMode == .None || (self.pinnedCertificates.count == 0)) {
            /* https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/OverridingSSLChainValidationCorrectly.html
             According to the docs, you should only trust your provided certs for evaluation.  Pinned certificates are added to the trust. Without pinned certificates, there is nothing to evaluate against.
         
             From Apple Docs:
                "Do not implicitly trust self-signed certificates as anchors (kSecTrustOptionImplicitAnchors).  Instead, add your own (self-signed) CA certificate to the list of trusted anchors."
            */
            NSLog("In order to validate a domain name for self signed certificates, you MUST use pinning.")
            return false
        }
        
        let p = self.validatesDomainName ? SecPolicyCreateSSL(true, domain) : SecPolicyCreateBasicX509()
        
        SecTrustSetPolicies(serverTrust, p)
        
        if (self.SSLPinningMode == .None) {
            return self.allowInvalidCertificates || AFServerTrustIsValid(serverTrust)
        } else if (!AFServerTrustIsValid(serverTrust) && !self.allowInvalidCertificates) {
            return false
        }
        
        switch (self.SSLPinningMode) {
        
        case .Certificate:
//            NSMutableArray *pinnedCertificates = [NSMutableArray array];
//            for (NSData *certificateData in self.pinnedCertificates) {
//                [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
//            }
            
            if self.pinnedCertificates != nil {
                SecTrustSetAnchorCertificates(serverTrust, Array<NSData>(self.pinnedCertificates!))
            }
            
            if !SFServerTrustIsValid(serverTrust) {
                return false
            }
            
            // obtain the chain after being validated, which *should* contain the pinned certificate in the last position (if it's the Root CA)
            let serverCertificates = AFCertificateTrustChainForServerTrust(serverTrust)
            
            return self.pinnedCertificates.contains(serverCertificates.last)
        
        case .PublicKey:
            var trustedPublicKeyCount = 0
            let publicKeys = SFPublicKeyTrustChainForServerTrust(serverTrust)
            
            return !self.pinnedPublicKeys.isDisjointWith(publicKeys)
        //case .None:
        default:
            return false
    }
        
    
    // Mark - NSCopying
   
    func copyWithZone(zone: NSZone) -> AnyObject {
        let securityPolicy = SFSecurityPolicy(pinningMode: self.pinningMode, withPinnedCertificates: self.pinnedCertificates)
        securityPolicy.allowInvalidCertificates = self.allowInvalidCertificates
        securityPolicy.validatesDomainName = self.validatesDomainName
        
        return securityPolicy
    }
}



// Mark: Constants


/**
 ## SSL Pinning Modes
 
 The following constants are provided by `AFSSLPinningMode` as possible SSL pinning modes.
 
 enum {
 AFSSLPinningModeNone,
 AFSSLPinningModePublicKey,
 AFSSLPinningModeCertificate,
 }
 
 `AFSSLPinningModeNone`
 Do not used pinned certificates to validate servers.
 
 `AFSSLPinningModePublicKey`
 Validate host certificates against public keys of pinned certificates.
 
 `AFSSLPinningModeCertificate`
 Validate host certificates against pinned certificates.
 */

}

/*
    #if !TARGET_OS_IOS && !TARGET_OS_WATCH && !TARGET_OS_TV
    func SFSecKeyGetData(key: SecKeyRef) {
        SecItemExport(
        CFDataRef data = NULL;
    
    __Require_noErr_Quiet(SecItemExport(key, kSecFormatUnknown, kSecItemPemArmour, NULL, &data), _out);
    
    return (__bridge_transfer NSData *)data;
    
    _out:
    if (data) {
    CFRelease(data);
    }
    
    return nil;
    }
    #endif
  */
    
    extension SecKeyRef : Equatable {
        
    }

public func ==(lhs: SecKey, rhs: SecKey) -> Bool {
    return lhs === rhs
}

//    func SFSecKeyIsEqualToKey(SecKeyRef key1, SecKeyRef key2) {
//    #if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
//    return [(__bridge id)key1 isEqual:(__bridge id)key2];
//    #else
//    return [AFSecKeyGetData(key1) isEqual:AFSecKeyGetData(key2)];
//    #endif
//    }

extension NSData {
    /// - seealso: AFPublicKeyForCertificate
    public var publicKey : SecKey? {
        get {
            guard let allowedCertificate = SecCertificateCreateWithData(nil, self) else { return nil }
            
            let policy = SecPolicyCreateBasicX509()
            var allowedTrust: SecTrust?
            let os = SecTrustCreateWithCertificates([allowedCertificate], policy, &allowedTrust)
            guard let trust = allowedTrust else {
                NSLog("SecTrustCreateWithCertificates failed \(os)")
                return nil
            }
                
            return SecTrustCopyPublicKey(trust)
        }
    }
}

extension SecTrust {
    /// - seealso: AFServerTrustIsValid
    public var isValid: Bool {
        get {
            var result: SecTrustResultType
            SecTrustEvaluate(self, &result)
            
            return result == UInt32(kSecTrustResultUnspecified) || result == UInt32(kSecTrustResultProceed)
        }
    }
    
    /// - Returns: the certificates from the trust chain.
    var certificates: [SecCertificate] {
        get {
            var rt = [SecCertificate]()
            
            for i in 0..<SecTrustGetCertificateCount(self) {
                if let certificate = SecTrustGetCertificateAtIndex(self, i) {
                    rt.append(certificate)
                }
            }
        }
    }
    
    /// - seealso: AFCertificateTrustChainForServerTrust
    public var trustChain: [NSData] {
        get {
            return self.certificates.map { SecCertificateCopyData($0) }
        }
    }
    
    var newTrustChain: [SecTrust] {
        get {
            let policy = SecPolicyCreateBasicX509()
            return self.certificates.flatMap { c -> SecTrust? in
                var trust: SecTrust?
                SecTrustCreateWithCertificates(c, policy, &trust)
                return trust
            }
        }
    }
    
    /// - seealso: AFPublicKeyTrustChainForServerTrust
    public var publicKeyTrustChain: [SecKeyRef] {
        get {
            return self.newTrustChain.flatMap { SecTrustCopyPublicKey($0) }
        }
    }
}
