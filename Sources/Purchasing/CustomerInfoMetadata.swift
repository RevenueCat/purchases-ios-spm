import Foundation

@objc(RCCustomerInfoMetadata)
public final class CustomerInfoMetadata: NSObject {
    @objc public let paywallConfig: CustomerInfoPaywallConfig?

    init?(from uiConfigMapping: CustomerInfoResponse.UIConfig?) {
        guard let uiConfigMapping,
              let regularId = uiConfigMapping.paywall,
              let personalProOnlyId = uiConfigMapping.paywallPersonalProOnly,
              let proOnlyId = uiConfigMapping.paywallProOnly,
              let aiPassId = uiConfigMapping.paywallAiPass
        else {
            return nil
        }
        self.paywallConfig = .init(
            regularId: regularId,
            personalProOnlyId: personalProOnlyId,
            proOnlyId: proOnlyId,
            aiPassId: aiPassId
        )
    }
}

@objc(RCCustomerInfoPaywallConfig)
public final class CustomerInfoPaywallConfig: NSObject {
    @objc public let regularId: String
    @objc public let personalProOnlyId: String
    @objc public let proOnlyId: String
    @objc public let aiPassId: String

    init(regularId: String, personalProOnlyId: String, proOnlyId: String, aiPassId: String) {
        self.regularId = regularId
        self.personalProOnlyId = personalProOnlyId
        self.proOnlyId = proOnlyId
        self.aiPassId = aiPassId
    }
}

extension CustomerInfoMetadata: Sendable {}
extension CustomerInfoPaywallConfig: Sendable {}
