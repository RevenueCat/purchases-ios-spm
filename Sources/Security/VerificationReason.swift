import Foundation

public enum VerificationReason {
    case invalidPublicKey(String)
    case signatureRequestedButNotProvided(String)
    case signatureNotBase64(String)
    case signatureInvalidSize(String)
    case signatureFailedVerification
    case intermediateKeyFailedVerification(String)
    case intermediateKeyFailedCreation(String)
    case intermediateKeyExpired(String, String)
    case intermediateKeyInvalid(String)
    case intermediateKeyCreating(String, String)
    case requestDateMissingFromHeaders(String)
}

// Clase wrapper para Objective-C
@objc(RCVerificationReason)
public class VerificationReasonContainer: NSObject, @unchecked Sendable {
    
    @objc public enum Reason: Int, Sendable {
        case invalidPublicKey = 0
        case signatureRequestedButNotProvided = 1
        case signatureNotBase64 = 2
        case signatureInvalidSize = 3
        case signatureFailedVerification = 4
        case intermediateKeyFailedVerification = 5
        case intermediateKeyFailedCreation = 6
        case intermediateKeyExpired = 7
        case intermediateKeyInvalid = 8
        case intermediateKeyCreating = 9
        case requestDateMissingFromHeaders = 10
    }
    
    @objc public let reasonType: Reason
    @objc public let details: String
    
    public let swiftReason: VerificationReason
    
    public init(_ reason: VerificationReason) {
        self.swiftReason = reason
        
        switch reason {
        case .invalidPublicKey(let value):
            self.reasonType = .invalidPublicKey
            self.details = "Public key could not be loaded: \(value)"
        case .signatureRequestedButNotProvided(let value):
            self.reasonType = .signatureRequestedButNotProvided
            self.details = "Request to '\(value)' required a signature but none was provided"
        case .signatureNotBase64(let value):
            self.reasonType = .signatureNotBase64
            self.details = "Signature is not base64: \(value)"
        case .signatureInvalidSize(let value):
            self.reasonType = .signatureInvalidSize
            self.details = "Signature '\(value)' does not have expected size (\(Signing.SignatureComponent.totalSize))"
        case .signatureFailedVerification:
            self.reasonType = .signatureFailedVerification
            self.details = "Signature failed verification"
        case .intermediateKeyFailedVerification(let value):
            self.reasonType = .intermediateKeyFailedVerification
            self.details = "Intermediate key failed verification: \(value)"
        case .intermediateKeyFailedCreation(let value):
            self.reasonType = .intermediateKeyFailedCreation
            self.details = "Failed initializing intermediate key: \(value)"
        case .intermediateKeyExpired(let date, let data):
            self.reasonType = .intermediateKeyExpired
            self.details = "Intermediate key expired at '\(date)' (parsed from '\(data)')"
        case .intermediateKeyInvalid(let expirationDate):
            self.reasonType = .intermediateKeyInvalid
            self.details = "Found invalid intermediate key expiration date: \(expirationDate)"
        case .intermediateKeyCreating(let expiration, let data):
            self.reasonType = .intermediateKeyCreating
            self.details = "Creating intermediate key with expiration '\(expiration)': \(data)"
        case .requestDateMissingFromHeaders(let value):
            self.reasonType = .requestDateMissingFromHeaders
            self.details = "Request to '\(value)' required a request date but none was provided"
        }
    }
}

extension VerificationReason: Sendable {}
