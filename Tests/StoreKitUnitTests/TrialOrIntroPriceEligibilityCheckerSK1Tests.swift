//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  TrialOrIntroPriceEligibilityCheckerSK1Tests.swift
//
//  Created by César de la Vega on 9/1/21.

import Nimble
@testable import RevenueCat
import StoreKitTest
import XCTest

// swiftlint:disable type_name

@available(iOS 14.0, tvOS 14.0, macOS 11.0, watchOS 7.0, *)
class TrialOrIntroPriceEligibilityCheckerSK1Tests: StoreKitConfigTestCase {

    private var receiptFetcher: MockReceiptFetcher!
    private var trialOrIntroPriceEligibilityChecker: TrialOrIntroPriceEligibilityChecker!
    private var mockIntroEligibilityCalculator: MockIntroEligibilityCalculator!
    private var mockBackend: MockBackend!
    private var mockOfferingsAPI: MockOfferingsAPI!
    private var mockProductsManager: MockProductsManager!
    private var mockSystemInfo: MockSystemInfo!
    private var diagnosticsTracker: DiagnosticsTrackerType?

    @available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
    var mockDiagnosticsTracker: MockDiagnosticsTracker {
        get throws {
            return try XCTUnwrap(self.diagnosticsTracker as? MockDiagnosticsTracker)
        }
    }

    static let eventTimestamp1: Date = .init(timeIntervalSince1970: 1694029328)
    static let eventTimestamp2: Date = .init(timeIntervalSince1970: 1694022321)
    let mockDateProvider = MockDateProvider(stubbedNow: eventTimestamp1,
                                            subsequentNows: eventTimestamp2)

    override func setUpWithError() throws {
        try super.setUpWithError()
        let platformInfo = Purchases.PlatformInfo(flavor: "xyz", version: "123")
        self.mockSystemInfo = MockSystemInfo(platformInfo: platformInfo,
                                             finishTransactions: true,
                                             storeKitVersion: .storeKit1)
        receiptFetcher = MockReceiptFetcher(requestFetcher: MockRequestFetcher(), systemInfo: mockSystemInfo)
        self.mockProductsManager = MockProductsManager(diagnosticsTracker: nil,
                                                       systemInfo: mockSystemInfo,
                                                       requestTimeout: Configuration.storeKitRequestTimeoutDefault)
        mockIntroEligibilityCalculator = MockIntroEligibilityCalculator(productsManager: mockProductsManager,
                                                                        receiptParser: MockReceiptParser())
        mockBackend = MockBackend()

        self.mockOfferingsAPI = try XCTUnwrap(self.mockBackend.offerings as? MockOfferingsAPI)
        let mockOperationDispatcher = MockOperationDispatcher()
        let userProvider = MockCurrentUserProvider(mockAppUserID: "app_user")

        if #available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *) {
            self.diagnosticsTracker = MockDiagnosticsTracker()
        } else {
            self.diagnosticsTracker = nil
        }

        self.trialOrIntroPriceEligibilityChecker = TrialOrIntroPriceEligibilityChecker(
            systemInfo: self.mockSystemInfo,
            receiptFetcher: self.receiptFetcher,
            introEligibilityCalculator: self.mockIntroEligibilityCalculator,
            backend: self.mockBackend,
            currentUserProvider: userProvider,
            operationDispatcher: mockOperationDispatcher,
            productsManager: self.mockProductsManager,
            diagnosticsTracker: self.diagnosticsTracker,
            dateProvider: self.mockDateProvider
        )
    }

    func testSK1CheckTrialOrIntroPriceEligibilityDoesntCrash() throws {
        self.mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult = .success([:])

        waitUntil { completion in
            self.trialOrIntroPriceEligibilityChecker.sk1CheckEligibility([]) { _, _  in
                completion()
            }
        }
    }

    func testSK1CheckTrialOrIntroPriceEligibilityDoesntFetchAReceipt() throws {
        self.receiptFetcher.shouldReturnReceipt = false

        expect(self.receiptFetcher.receiptDataCalled) == false

        self.trialOrIntroPriceEligibilityChecker.sk1CheckEligibility([]) { _, _ in }

        expect(self.receiptFetcher.receiptDataCalled) == true
        expect(self.receiptFetcher.receiptDataReceivedRefreshPolicy) == .never
    }

    func testSK1EligibilityIsCalculatedFromReceiptData() throws {
        let stubbedEligibility = ["product_id": IntroEligibilityStatus.eligible]
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult = .success(stubbedEligibility)

        let eligibilities = waitUntilValue { completed in
            self.trialOrIntroPriceEligibilityChecker.sk1CheckEligibility([]) { eligibilities, _ in
                completed(eligibilities)
            }
        }

        expect(eligibilities).to(haveCount(1))
    }

    func testSK1EligibilityProductsWithKnownIntroEligibilityStatus() throws {
        let productIdentifiersAndDiscounts = [("product_id", nil),
                                              ("com.revenuecat.monthly_4.99.1_week_intro", MockSKProductDiscount()),
                                              ("com.revenuecat.annual_39.99.2_week_intro", MockSKProductDiscount()),
                                              ("lifetime", MockSKProductDiscount())
        ]
        let productIdentifiers = Set(productIdentifiersAndDiscounts.map(\.0))
        let storeProducts = productIdentifiersAndDiscounts.map { (productIdentifier, discount) -> StoreProduct in
            let sk1Product = MockSK1Product(mockProductIdentifier: productIdentifier)
            sk1Product.mockDiscount = discount
            return StoreProduct(sk1Product: sk1Product)
        }

        self.mockProductsManager.stubbedProductsCompletionResult = .success(Set(storeProducts))

        let finalResults: [String: IntroEligibility]? = waitUntilValue { completion in
            self.trialOrIntroPriceEligibilityChecker.productsWithKnownIntroEligibilityStatus(
                productIdentifiers: productIdentifiers,
                completion: completion
            )
        }

        expect(finalResults).to(haveCount(1))
        expect(finalResults?["product_id"]?.status) == .noIntroOfferExists
        expect(finalResults?["com.revenuecat.monthly_4.99.1_week_intro"]?.status) == nil
        expect(finalResults?["com.revenuecat.annual_39.99.2_week_intro"]?.status) == nil
        expect(finalResults?["lifetime"]?.status) == nil
    }

    func testSK1EligibilityIsFetchedFromBackendIfErrorCalculatingEligibilityAndStoreKitDoesNotHaveIt() throws {
        self.mockProductsManager.stubbedProductsCompletionResult = .success([])
        let stubbedError = NSError(domain: RCPurchasesErrorCodeDomain,
                                   code: ErrorCode.invalidAppUserIdError.rawValue,
                                   userInfo: [:])
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult = .failure(stubbedError)

        let productId = "product_id"
        let stubbedEligibility = [productId: IntroEligibility(eligibilityStatus: IntroEligibilityStatus.eligible)]
        mockOfferingsAPI.stubbedGetIntroEligibilityCompletionResult = (stubbedEligibility, nil)

        let eligibilities = waitUntilValue { completed in
            self.trialOrIntroPriceEligibilityChecker.sk1CheckEligibility([productId]) { eligibilities, _ in
                completed(eligibilities)
            }
        }

        let receivedEligibilities = try XCTUnwrap(eligibilities)
        expect(receivedEligibilities).to(haveCount(1))
        expect(receivedEligibilities[productId]?.status) == IntroEligibilityStatus.eligible

        expect(self.mockOfferingsAPI.invokedGetIntroEligibilityCount) == 1
    }

    func testSK1EligibilityIsNotFetchedFromBackendIfEligibilityAlreadyExists() throws {
        let stubbedError = NSError(domain: RCPurchasesErrorCodeDomain,
                                   code: ErrorCode.invalidAppUserIdError.rawValue,
                                   userInfo: [:])
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult = .failure(stubbedError)

        let sk1Product = MockSK1Product(mockProductIdentifier: "product_id")
        sk1Product.mockDiscount = nil
        let storeProduct =  StoreProduct(sk1Product: sk1Product)

        self.mockProductsManager.stubbedProductsCompletionResult = .success([
            storeProduct
        ])

        let productId = "product_id"
        let stubbedEligibility = [productId: IntroEligibility(eligibilityStatus: IntroEligibilityStatus.eligible)]
        mockOfferingsAPI.stubbedGetIntroEligibilityCompletionResult = (stubbedEligibility, nil)

        let eligibilities = waitUntilValue { completed in
            self.trialOrIntroPriceEligibilityChecker.sk1CheckEligibility([]) { eligibilities, _ in
                completed(eligibilities)
            }
        }

        let receivedEligibilities = try XCTUnwrap(eligibilities)
        expect(receivedEligibilities).to(haveCount(1))
        expect(receivedEligibilities[productId]?.status) == IntroEligibilityStatus.noIntroOfferExists

        expect(self.mockOfferingsAPI.invokedGetIntroEligibilityCount) == 0
    }

    func testSK1ErrorFetchingFromBackendAfterErrorCalculatingEligibility() throws {
        self.mockProductsManager.stubbedProductsCompletionResult = .success([])
        let productId = "product_id"

        let stubbedError: BackendError = .networkError(
            .errorResponse(.init(code: .invalidAPIKey,
                                 originalCode: BackendErrorCode.invalidAPIKey.rawValue,
                                 message: nil),
                           400)
        )
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult = .failure(stubbedError)

        mockOfferingsAPI.stubbedGetIntroEligibilityCompletionResult = ([:], stubbedError)

        let eligibilities = waitUntilValue { completed in
            self.trialOrIntroPriceEligibilityChecker.sk1CheckEligibility([productId]) { eligibilities, _ in
                completed(eligibilities)
            }
        }

        expect(eligibilities).toEventuallyNot(beNil())
        let receivedEligibilities = try XCTUnwrap(eligibilities)
        expect(receivedEligibilities).to(haveCount(1))
        expect(receivedEligibilities[productId]?.status) == IntroEligibilityStatus.unknown
    }

}

// MARK: - Diagnostics

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
extension TrialOrIntroPriceEligibilityCheckerSK1Tests {

    func testSK1DoesNotTrackDiagnosticsWhenReceiptNotFetchedAndEmptyProductIds() throws {
        self.receiptFetcher.shouldReturnReceipt = false

        waitUntil { completion in
            self.trialOrIntroPriceEligibilityChecker.checkEligibility(productIdentifiers: []) { _ in
                completion()
            }
        }

        expect(try self.mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value).to(beEmpty())
    }

    func testSK1DoesNotTrackDiagnosticsWhenReceiptFetchedAndEmptyProductIds() throws {
        self.receiptFetcher.shouldReturnReceipt = true

        waitUntil { completion in
            self.trialOrIntroPriceEligibilityChecker.checkEligibility(productIdentifiers: []) { _ in
                completion()
            }
        }

        expect(try self.mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value).to(beEmpty())
    }

    func testSK1TracksDiagnosticsWhenReceiptFetchedAndEligibilityCalculatorSuccess() throws {
        self.receiptFetcher.shouldReturnReceipt = true

        let productIds = Set(["product_id",
                              "com.revenuecat.monthly_4.99.1_week_intro",
                              "com.revenuecat.annual_39.99.2_week_intro",
                              "lifetime"])

        let stubbedEligibility = ["product_id": IntroEligibilityStatus.unknown,
                                  "com.revenuecat.monthly_4.99.1_week_intro": IntroEligibilityStatus.eligible,
                                  "com.revenuecat.annual_39.99.2_week_intro": IntroEligibilityStatus.ineligible,
                                  "lifetime": IntroEligibilityStatus.noIntroOfferExists]
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult = .success(stubbedEligibility)
        mockSystemInfo.stubbedStorefront = MockStorefront(countryCode: "USA")

        waitUntil { completion in
            self.trialOrIntroPriceEligibilityChecker.checkEligibility(productIdentifiers: productIds) { _ in
                completion()
            }
        }

        let mockDiagnosticsTracker = try self.mockDiagnosticsTracker

        expect(mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value).to(haveCount(1))
        let params = mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value[0]

        expect(params.storeKitVersion) == .storeKit1
        expect(params.requestedProductIds) == productIds
        expect(params.eligibilityUnknownCount) == 1
        expect(params.eligibilityIneligibleCount) == 1
        expect(params.eligibilityEligibleCount) == 1
        expect(params.eligibilityNoIntroOfferCount) == 1
        expect(params.errorMessage).to(beNil())
        expect(params.errorCode).to(beNil())
        expect(params.storefront) == "USA"
        expect(params.responseTime) == Self.eventTimestamp2.timeIntervalSince(Self.eventTimestamp1)
    }

    func testSK1TracksDiagnosticsWhenReceiptFetchedAndEligibilityCalculatorFailure() throws {
        self.receiptFetcher.shouldReturnReceipt = true

        let productIds = Set(["product_id",
                              "com.revenuecat.monthly_4.99.1_week_intro",
                              "com.revenuecat.annual_39.99.2_week_intro",
                              "lifetime"])

        let receiptError = PurchasesReceiptParser.Error.receiptParsingError
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult =
            .failure(receiptError)

        self.mockProductsManager.stubbedProductsCompletionResult = .failure(
            ErrorUtils.productNotAvailableForPurchaseError()
        )
        waitUntil { completion in
            self.trialOrIntroPriceEligibilityChecker.checkEligibility(productIdentifiers: productIds) { _ in
                completion()
            }
        }

        let mockDiagnosticsTracker = try self.mockDiagnosticsTracker

        expect(mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value).to(haveCount(1))
        let params = mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value[0]

        expect(params.storeKitVersion) == .storeKit1
        expect(params.requestedProductIds) == productIds
        expect(params.eligibilityUnknownCount).to(beNil())
        expect(params.eligibilityIneligibleCount).to(beNil())
        expect(params.eligibilityEligibleCount).to(beNil())
        expect(params.eligibilityNoIntroOfferCount).to(beNil())
        expect(params.errorMessage) == receiptError.errorDescription
        expect(params.errorCode) == ErrorCode.invalidReceiptError.errorCode
        expect(params.storefront).to(beNil())
        expect(params.responseTime) == Self.eventTimestamp2.timeIntervalSince(Self.eventTimestamp1)
    }

    func testSK1TracksDiagnosticsWhenEligibilityCalculatorFailurePartialGetProductsAndBackendError() throws {
        self.receiptFetcher.shouldReturnReceipt = true

        let productIds = Set(["product_id",
                              "com.revenuecat.monthly_4.99.1_week_intro",
                              "com.revenuecat.annual_39.99.2_week_intro",
                              "lifetime"])

        let receiptError = PurchasesReceiptParser.Error.receiptParsingError
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult =
            .failure(receiptError)

        let sk1Product = MockSK1Product(mockProductIdentifier: "product_id")
        sk1Product.mockDiscount = nil
        let storeProduct =  StoreProduct(sk1Product: sk1Product)
        self.mockProductsManager.stubbedProductsCompletionResult = .success([storeProduct])

        let backendError = BackendError.networkError(.unexpectedResponse(nil))
        self.mockOfferingsAPI.stubbedGetIntroEligibilityCompletionResult = ([:], backendError)

        waitUntil { completion in
            self.trialOrIntroPriceEligibilityChecker.checkEligibility(productIdentifiers: productIds) { _ in
                completion()
            }
        }

        let mockDiagnosticsTracker = try self.mockDiagnosticsTracker

        expect(mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value).to(haveCount(1))
        let params = mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value[0]

        let expectedError = backendError.asPurchasesError
        expect(params.storeKitVersion) == .storeKit1
        expect(params.requestedProductIds) == productIds
        expect(params.eligibilityUnknownCount) == 3
        expect(params.eligibilityIneligibleCount) == 0
        expect(params.eligibilityEligibleCount) == 0
        expect(params.eligibilityNoIntroOfferCount) == 1
        expect(params.errorMessage) == expectedError.localizedDescription
        expect(params.errorCode) == expectedError.errorCode
        expect(params.storefront).to(beNil())
        expect(params.responseTime) == Self.eventTimestamp2.timeIntervalSince(Self.eventTimestamp1)
    }

    func testSK1TracksDiagnosticsWhenEligibilityCalculatorFailurePartialGetProductsAndBackendSuccess() throws {
        self.receiptFetcher.shouldReturnReceipt = true

        let productIds = Set(["product_id",
                              "com.revenuecat.monthly_4.99.1_week_intro",
                              "com.revenuecat.annual_39.99.2_week_intro",
                              "lifetime"])

        let receiptError = PurchasesReceiptParser.Error.receiptParsingError
        mockIntroEligibilityCalculator.stubbedCheckTrialOrIntroDiscountEligibilityResult =
            .failure(receiptError)

        let sk1Product = MockSK1Product(mockProductIdentifier: "product_id")
        sk1Product.mockDiscount = nil
        let storeProduct =  StoreProduct(sk1Product: sk1Product)
        self.mockProductsManager.stubbedProductsCompletionResult = .success([storeProduct])

        let stubbedBackendEligibility = ["lifetime": IntroEligibility(eligibilityStatus: .eligible)]
        self.mockOfferingsAPI.stubbedGetIntroEligibilityCompletionResult = (stubbedBackendEligibility, nil)

        waitUntil { completion in
            self.trialOrIntroPriceEligibilityChecker.checkEligibility(productIdentifiers: productIds) { _ in
                completion()
            }
        }

        let mockDiagnosticsTracker = try self.mockDiagnosticsTracker

        expect(mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value).to(haveCount(1))
        let params = mockDiagnosticsTracker.trackedAppleTrialOrIntroEligibilityRequestParams.value[0]

        expect(params.storeKitVersion) == .storeKit1
        expect(params.requestedProductIds) == productIds
        expect(params.eligibilityUnknownCount) == 0
        expect(params.eligibilityIneligibleCount) == 0
        expect(params.eligibilityEligibleCount) == 1
        expect(params.eligibilityNoIntroOfferCount) == 1
        expect(params.errorMessage) == receiptError.errorDescription
        expect(params.errorCode) == ErrorCode.invalidReceiptError.errorCode
        expect(params.storefront).to(beNil())
        expect(params.responseTime) == Self.eventTimestamp2.timeIntervalSince(Self.eventTimestamp1)
    }

}
