import Foundation

@objc(RCCustomerInfoMetadata)
public final class CustomerInfoMetadata: NSObject {
    @objc public let paywallConfig: CustomerInfoPaywallConfig?

    init?(from uiConfigMapping: CustomerInfoResponse.UIConfig?) {
        guard let uiConfigMapping, let paywallId = uiConfigMapping.paywall else { return nil }
        self.paywallConfig = .init(paywallId: paywallId)
    }
}

@objc(RCCustomerInfoPaywallConfig)
public final class CustomerInfoPaywallConfig: NSObject {
    @objc public let paywallId: String

    init(paywallId: String) {
        self.paywallId = paywallId
    }
}

extension CustomerInfoMetadata: Sendable {}
extension CustomerInfoPaywallConfig: Sendable {}
