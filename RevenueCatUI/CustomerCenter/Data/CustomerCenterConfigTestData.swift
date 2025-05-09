//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  CustomerCenterConfigTestData.swift
//
//
//  Created by Cesar de la Vega on 28/5/24.
//

import Foundation
import RevenueCat

enum CustomerCenterConfigTestData {

    @available(iOS 14.0, *)
    // swiftlint:disable:next function_body_length
    static func customerCenterData(
        lastPublishedAppVersion: String?,
        shouldWarnCustomerToUpdate: Bool = false,
        displayPurchaseHistoryLink: Bool = false,
        refundWindowDuration: CustomerCenterConfigData.HelpPath.RefundWindowDuration = .forever
    ) -> CustomerCenterConfigData {
        CustomerCenterConfigData(
            screens: [.management:
                    .init(
                        type: .management,
                        title: "Manage Subscription",
                        subtitle: "Manage your subscription details here",
                        paths: [
                            .init(
                                id: "1",
                                title: "Didn't receive purchase",
                                url: nil,
                                openMethod: nil,
                                type: .missingPurchase,
                                detail: nil,
                                refundWindowDuration: nil
                            ),
                            .init(
                                id: "2",
                                title: "Request a refund",
                                url: nil,
                                openMethod: nil,
                                type: .refundRequest,
                                detail: .promotionalOffer(CustomerCenterConfigData.HelpPath.PromotionalOffer(
                                    iosOfferId: "offer_id",
                                    eligible: true,
                                    title: "title",
                                    subtitle: "subtitle",
                                    productMapping: ["monthly": "offer_id"]
                                )),
                                refundWindowDuration: refundWindowDuration
                            ),
                            .init(
                                id: "3",
                                title: "Change plans",
                                url: nil,
                                openMethod: nil,
                                type: .changePlans,
                                detail: nil,
                                refundWindowDuration: nil
                            ),
                            .init(
                                id: "4",
                                title: "Cancel subscription",
                                url: nil,
                                openMethod: nil,
                                type: .cancel,
                                detail: .feedbackSurvey(.init(
                                    title: "Why are you cancelling?",
                                    options: [
                                        .init(
                                            id: "1",
                                            title: "Too expensive",
                                            promotionalOffer: nil
                                        ),
                                        .init(
                                            id: "2",
                                            title: "Don't use the app",
                                            promotionalOffer: nil
                                        ),
                                        .init(
                                            id: "3",
                                            title: "Bought by mistake",
                                            promotionalOffer: nil
                                        )
                                    ]
                                )),
                                refundWindowDuration: nil
                            )
                        ]
                    ),
                      .noActive: .init(
                        type: .noActive,
                        title: "No Active Subscription",
                        subtitle: "You currently have no active subscriptions",
                        paths: [
                            .init(
                                id: "9q9719171o",
                                title: "Check purchases",
                                url: nil,
                                openMethod: nil,
                                type: .missingPurchase,
                                detail: nil,
                                refundWindowDuration: nil
                            )
                        ]
                      )
            ],
            appearance: standardAppearance,
            localization: .init(
                locale: "en_US",
                localizedStrings: [
                    "cancel": "Cancel",
                    "back": "Back"
                ]
            ),
            support: .init(
                email: "test-support@revenuecat.com",
                shouldWarnCustomerToUpdate: shouldWarnCustomerToUpdate,
                displayPurchaseHistoryLink: displayPurchaseHistoryLink
            ),
            lastPublishedAppVersion: lastPublishedAppVersion,
            productId: 1
        )
    }

    @available(iOS 14.0, *)
    static let customerCenterData = customerCenterData(lastPublishedAppVersion: "1.0.0")

    static let standardAppearance = CustomerCenterConfigData.Appearance(
        accentColor: .init(light: "#007AFF", dark: "#007AFF"),
        textColor: .init(light: "#000000", dark: "#ffffff"),
        backgroundColor: .init(light: "#f5f5f7", dark: "#000000"),
        buttonTextColor: .init(light: "#ffffff", dark: "#000000"),
        buttonBackgroundColor: .init(light: "#287aff", dark: "#287aff")
    )

    static let subscriptionInformationMonthlyRenewing: PurchaseInformation = .init(
        title: "Basic",
        durationTitle: "Monthly",
        explanation: .earliestRenewal,
        price: .paid("$4.99"),
        expirationOrRenewal: .init(label: .nextBillingDate,
                                   date: .date("June 1st, 2024")),
        productIdentifier: "product_id",
        store: .appStore,
        isLifetime: false,
        isTrial: false,
        isCancelled: false,
        latestPurchaseDate: nil,
        customerInfoRequestedDate: Date()
    )

    static let subscriptionInformationFree: PurchaseInformation = .init(
        title: "Basic",
        durationTitle: "Monthly",
        explanation: .earliestRenewal,
        price: .free,
        expirationOrRenewal: .init(label: .nextBillingDate,
                                   date: .date("June 1st, 2024")),
        productIdentifier: "product_id",
        store: .appStore,
        isLifetime: false,
        isTrial: false,
        isCancelled: false,
        latestPurchaseDate: nil,
        customerInfoRequestedDate: Date()
    )

    static let subscriptionInformationYearlyExpiring: PurchaseInformation = .init(
        title: "Basic",
        durationTitle: "Yearly",
        explanation: .earliestRenewal,
        price: .paid("$49.99"),
        expirationOrRenewal: .init(label: .expires,
                                   date: .date("June 1st, 2024")),
        productIdentifier: "product_id",
        store: .appStore,
        isLifetime: false,
        isTrial: false,
        isCancelled: false,
        latestPurchaseDate: nil,
        customerInfoRequestedDate: Date()
    )

    static let consumable: PurchaseInformation = .init(
        title: "Basic",
        durationTitle: nil,
        explanation: .lifetime,
        price: .paid("$49.99"),
        expirationOrRenewal: nil,
        productIdentifier: "product_id",
        store: .appStore,
        isLifetime: true,
        isTrial: false,
        isCancelled: false,
        latestPurchaseDate: Date(),
        customerInfoRequestedDate: Date()
    )

}
