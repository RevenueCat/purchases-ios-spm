import Foundation

public enum VerificationReason {
    case invalidPublicKey(String)
    case signatureNotBase64(String)
    case signatureInvalidSize(Data)
    case signatureFailedVerification(String)
    case intermediateKeyFailedVerification(signature: Data)
    case intermediateKeyFailedCreation(Error)
    case intermediateKeyExpired(Date, Data)
    case intermediateKeyInvalid(Data)
    case intermediateKeyCreating(expiration: Date, data: Data)
}

// Clase wrapper para Objective-C
@objc(RCVerificationReason)
public class VerificationReasonContainer: NSObject, @unchecked Sendable {
    
    @objc public enum Reason: Int, Sendable {
        case invalidPublicKey = 0
        case signatureNotBase64 = 1
        case signatureInvalidSize = 2
        case signatureFailedVerification = 3
        case intermediateKeyFailedVerification = 4
        case intermediateKeyFailedCreation = 5
        case intermediateKeyExpired = 6
        case intermediateKeyInvalid = 7
        case intermediateKeyCreating = 8
    }
    
    @objc public let reasonType: Reason
    @objc public let details: String
    
    public let swiftReason: VerificationReason
    
    public init(_ reason: VerificationReason) {
        self.swiftReason = reason
        
        switch reason {
        case .invalidPublicKey(let value):
            self.reasonType = .invalidPublicKey
            self.details = value
        case .signatureNotBase64(let value):
            self.reasonType = .signatureNotBase64
            self.details = value
        case .signatureInvalidSize(let data):
            self.reasonType = .signatureInvalidSize
            self.details = "Size: \(data.count)"
        case .signatureFailedVerification(let value):
            self.reasonType = .signatureFailedVerification
            self.details = value
        case .intermediateKeyFailedVerification(let signature):
            self.reasonType = .intermediateKeyFailedVerification
            self.details = "Signature size: \(signature.count)"
        case .intermediateKeyFailedCreation(let error):
            self.reasonType = .intermediateKeyFailedCreation
            self.details = "Error: \(error.localizedDescription)"
        case .intermediateKeyExpired(let date, _):
            self.reasonType = .intermediateKeyExpired
            self.details = "Expired: \(date)"
        case .intermediateKeyInvalid(_):
            self.reasonType = .intermediateKeyInvalid
            self.details = "Invalid intermediate key"
        case .intermediateKeyCreating(let expiration, _):
            self.reasonType = .intermediateKeyCreating
            self.details = "Expiration: \(expiration)"
        }
    }
}

extension VerificationReason: Sendable {}
