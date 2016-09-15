/**
 # SNSecurityPolicy.swift
##  SkyNet
 
 - Author: Andrew Bradnan
 - Date: 6/2/16
 - Copyright: Copyright © 2016 SkyNet. All rights reserved.
 */

import Foundation

public enum SNSSLPinningMode {
    case none
    case publicKey
    case certificate
}

/**
 `SNSecurityPolicy` evaluates server trust against pinned X.509 certificates and public keys over secure connections.
 
 Adding pinned SSL certificates to your app helps prevent man-in-the-middle attacks and other vulnerabilities. Applications dealing with sensitive customer data or financial information are strongly encouraged to route all communication over an HTTPS connection with SSL pinning configured and enabled.
 */


open class SNSecurityPolicy// : NSObject //, /*NSSecureCoding,*/ NSCopying {
{
    /**
     The criteria by which server trust should be evaluated against the pinned SSL certificates. Defaults to `.None`.
     */
    let pinningMode: SNSSLPinningMode
    
    /**
     The certificates used to evaluate server trust according to the SSL pinning mode.
     
     By default, this property is set to any (`.cer`) certificates included in the target compiling AFNetworking. Note that if you are using AFNetworking as embedded framework, no certificates will be pinned by default. Use `certificatesInBundle` to load certificates from your target, and then create a new policy by calling `policyWithPinningMode:withPinnedCertificates`.
     
     Note that if pinning is enabled, `evaluateServerTrust:forDomain:` will return true if any pinned certificate matches.
     */
    fileprivate var _pinnedCertificates = Set<Data>()
    var pinnedCertificates: Set<Data> {
        get { return _pinnedCertificates }
        set(value) {
            _pinnedCertificates = value
        
            self.pinnedPublicKeys = Set<PublicKey>(self._pinnedCertificates.flatMap { $0.publicKey } )
        }
    }
    
    fileprivate var pinnedPublicKeys = Set<PublicKey>()
    
    /// Whether or not to trust servers with an invalid or expired SSL certificates. Defaults to `false`.
    var allowInvalidCertificates: Bool = false
    
    /// Whether or not to validate the domain name in the certificate's CN field. Defaults to `true`.
    var validatesDomainName: Bool = true
    
    // MARK: Getting Certificates from the Bundle

    /**
     Returns any certificates included in the bundle. If you are using AFNetworking as an embedded framework, you must use this method to find the certificates you have included in your app bundle, and use them when creating your security policy by calling `policyWithPinningMode:withPinnedCertificates`.
     
     - Returns: The certificates included in the given bundle.
     */
    static func certificatesInBundle(_ bundle: Bundle) -> Set<Data> {
        let paths = bundle.paths(forResourcesOfType: "cer", inDirectory:".")
        let rgOfData = paths.flatMap{ (try? Data(contentsOf: URL(fileURLWithPath: $0))) }   // flatMap nixes the .None's
        
        return Set<Data>(rgOfData)
    }

    static var defaultPinnedCertificates: Set<Data> = SNSecurityPolicy.getDefaultPinnedCertificates()
        
    static func getDefaultPinnedCertificates() -> Set<Data> {
        let bundle = Bundle(for: SNSecurityPolicy.self)
        return certificatesInBundle(bundle)
    }

    
    // MARK: Getting Specific Security Policies
    
    
    /**
     Returns the shared default security policy, which does not allow invalid certificates, validates domain name, and does not validate against pinned certificates or public keys.
     
     - Returns: The default security policy.
     */
    open static let defaultPolicy = SNSecurityPolicy()
    
    
    // MARK: Initialization

    /**
     Creates and returns a security policy with the specified pinning mode.
     
     - Parameter pinningMode: The SSL pinning mode.
     - Parameter pinnedCertificates: The certificates to pin against.
     
     - Returns: A new security policy.
     */
    public init(pinningMode: SNSSLPinningMode = .none, withPinnedCertificates: Set<Data>? = SNSecurityPolicy.defaultPinnedCertificates) {
        self.pinningMode = pinningMode
        self.pinnedCertificates = withPinnedCertificates ?? []
    }
    
    // MARK: Evaluating Server Trust
    
    func secPolicy(_ domain: String?) -> SecPolicy {
        return self.validatesDomainName ? SecPolicyCreateSSL(true, domain as CFString?) : SecPolicyCreateBasicX509()
    }
    
    /**
     Whether or not the specified server trust should be accepted, based on the security policy.
     
     This method should be used when responding to an authentication challenge from a server.
     
     - Parameter serverTrust: The X.509 certificate trust of the server.
     - Parameter domain: The domain of serverTrust. If `nil`, the domain will not be validated.
     
     - Returns: Whether or not to trust the server.
     */
    func evaluateServerTrust(_ serverTrust: SecTrust, forDomain domain: String?) -> Bool
    {
        if domain != nil {
            if self.allowInvalidCertificates && self.validatesDomainName && (self.pinningMode == .none || (self.pinnedCertificates.count == 0)) {
                /* https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/OverridingSSLChainValidationCorrectly.html
                 According to the docs, you should only trust your provided certs for evaluation.  Pinned certificates are added to the trust. Without pinned certificates, there is nothing to evaluate against.
             
                 From Apple Docs:
                    "Do not implicitly trust self-signed certificates as anchors (kSecTrustOptionImplicitAnchors).  Instead, add your own (self-signed) CA certificate to the list of trusted anchors."
                */
                NSLog("In order to validate a domain name for self signed certificates, you MUST use pinning.")
                return false
            }
        }
        
        SecTrustSetPolicies(serverTrust, secPolicy(domain))
        
        if (self.pinningMode == .none) {
            return self.allowInvalidCertificates || serverTrust.isValid
        } else if (!serverTrust.isValid && !self.allowInvalidCertificates) {
            return false
        }
        
        switch (self.pinningMode) {
        
        case .certificate:
            let array = Array<Data>(self.pinnedCertificates)
            let certArray = array.flatMap { SecCertificateCreateWithData(nil, $0 as CFData) }
            
            SecTrustSetAnchorCertificates(serverTrust, certArray as CFArray)

            if !serverTrust.isValid {
                return false
            }
            
            // obtain the chain after being validated, which *should* contain the pinned certificate in the last position (if it's the Root CA)
            if let root = serverTrust.trustChain.last {
                return self.pinnedCertificates.contains(root)
            }
            else {
                return false
            }
            
        case .publicKey:
            let publicKeys = serverTrust.publicKeyTrustChain
            
            return !self.pinnedPublicKeys.isDisjoint(with: publicKeys)
        //case .None:
            // fallthrough
        default:
            return false
    }
}

}

extension Data {
    /// - seealso: AFPublicKeyForCertificate
    public var publicKey : PublicKey? {
        get {
            guard let allowedCertificate = SecCertificateCreateWithData(nil, self as CFData) else { return nil }
            
            let policy = SecPolicyCreateBasicX509()
            var allowedTrust: SecTrust?
            let os = SecTrustCreateWithCertificates([allowedCertificate], policy, &allowedTrust)
            guard let trust = allowedTrust else {
                NSLog("SecTrustCreateWithCertificates failed \(os)")
                return nil
            }
            guard let pk = SecTrustCopyPublicKey(trust) else { return nil }
            
            return PublicKey(hashValue: self.hashValue, key: pk)
        }
    }
}

/**
 This is a hashable SecKey so we can add to a Set<>
 */
public struct PublicKey : Hashable {
    public let hashValue: Int
    public let key: SecKey
}

public func ==(lhs: PublicKey, rhs: PublicKey) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

// Mark - SecTrust

extension SecTrust {
    /// - seealso: AFServerTrustIsValid
    public var isValid: Bool {
        get {
            var result = SecTrustResultType.invalid
            SecTrustEvaluate(self, &result)
            
            return result == UInt32(SecTrustResultType.unspecified) || result == UInt32(SecTrustResultType.proceed)
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
            return rt
        }
    }
    
    /// - seealso: AFCertificateTrustChainForServerTrust
    public var trustChain: [Data] {
        get {
            return self.certificates.map { (SecCertificateCopyData($0) as Data) }
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
    public var publicKeyTrustChain: [PublicKey] {
        get {
            let hashes = self.trustChain.map { $0.hashValue }
            let hashKeys = zip(hashes, self.newTrustChain.flatMap { SecTrustCopyPublicKey($0) })
            
            return hashKeys.map { PublicKey(hashValue: $0.0, key: $0.1) }
        }
    }
}
