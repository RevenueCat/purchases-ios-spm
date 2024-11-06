//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  WebPurchaseRedemptionResult.swift
//
//  Created by Antonio Rico Diez on 29/10/24.

import Foundation

/// Represents the result of a web purchase redemption
/// - Seealso: ``Purchases/redeemWebPurchase(_:)``
public enum WebPurchaseRedemptionResult: Sendable {

    /// Represents that the web purchase was redeemed successfully
    case success(_ customerInfo: CustomerInfo)
    /// Represents that the web purchase failed to redeem
    case error(_ error: PublicError)
    /// Represents that the token was not a valid redemption token. Maybe the link was invalid or incomplete.
    case invalidToken
    /// Indicates that the web purchase has already been redeemed and can't be redeemed again.
    case alreadyRedeemed
    /// Indicates that the redemption token has expired. An email with a new redemption token
    /// might be sent depending on the value of  wasEmailSent.
    /// The email where it was sent is indicated by the obfuscatedEmail.
    case expired(_ obfuscatedEmail: String, wasEmailSent: Bool)

}