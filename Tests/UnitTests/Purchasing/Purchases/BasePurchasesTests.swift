//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  BasePurchasesTests.swift
//
//  Created by Nacho Soto on 5/25/22.

import Nimble
import StoreKit
import XCTest

@testable import RevenueCat

class BasePurchasesTests: TestCase {

    private static let userDefaultsSuiteName = "TestDefaults"

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Some tests rely on the level being at least `.debug`
        // Because unit tests can run in parallel, if a test needs to modify
        // this level it should be moved to `StoreKitUnitTests`, which runs serially.
        Purchases.logLevel = .verbose

        self.notificationCenter = MockNotificationCenter()
        self.purchasesDelegate = MockPurchasesDelegate()

        self.mockPaymentQueueWrapper = MockPaymentQueueWrapper()

        self.userDefaults = UserDefaults(suiteName: Self.userDefaultsSuiteName)
        self.clock = TestClock()
        self.systemInfo = MockSystemInfo(finishTransactions: true,
                                         storeKitVersion: self.storeKitVersion,
                                         clock: self.clock)
        self.storeKit1Wrapper = MockStoreKit1Wrapper(observerMode: self.systemInfo.observerMode)
        self.deviceCache = MockDeviceCache(systemInfo: self.systemInfo,
                                           userDefaults: self.userDefaults)
        self.paywallCache = .init()
        if #available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *) {
            self.paywallEventsManager = MockPaywallEventsManager()
        } else {
            self.paywallEventsManager = nil
        }
        self.requestFetcher = MockRequestFetcher()
        self.purchasedProductsFetcher = .init()
        if #available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *) {
            self.diagnosticsTracker = MockDiagnosticsTracker()
        } else {
            self.diagnosticsTracker = nil
        }

        self.mockProductsManager = MockProductsManager(diagnosticsTracker: self.diagnosticsTracker,
                                                       systemInfo: self.systemInfo,
                                                       requestTimeout: Configuration.storeKitRequestTimeoutDefault)
        self.mockOperationDispatcher = MockOperationDispatcher()
        self.mockReceiptParser = MockReceiptParser()
        self.identityManager = MockIdentityManager(mockAppUserID: Self.appUserID, mockDeviceCache: self.deviceCache)
        self.mockIntroEligibilityCalculator = MockIntroEligibilityCalculator(productsManager: self.mockProductsManager,
                                                                             receiptParser: self.mockReceiptParser)
        let platformInfo = Purchases.PlatformInfo(flavor: "iOS", version: "4.4.0")
        let systemInfoAttribution = MockSystemInfo(platformInfo: platformInfo, finishTransactions: true)
        self.receiptFetcher = MockReceiptFetcher(requestFetcher: self.requestFetcher, systemInfo: systemInfoAttribution)
        self.attributionFetcher = MockAttributionFetcher(attributionFactory: MockAttributionTypeFactory(),
                                                         systemInfo: systemInfoAttribution)
        self.mockProductEntitlementMappingFetcher = MockProductEntitlementMappingFetcher()
        self.mockPurchasedProductsFetcher = MockPurchasedProductsFetcher()
        self.mockTransactionFetcher = MockStoreKit2TransactionFetcher()

        let apiKey = "mockAPIKey"
        let httpClient = MockHTTPClient(apiKey: apiKey,
                                        systemInfo: self.systemInfo,
                                        eTagManager: MockETagManager(),
                                        diagnosticsTracker: self.diagnosticsTracker)
        let config = BackendConfiguration(httpClient: httpClient,
                                          operationDispatcher: self.mockOperationDispatcher,
                                          operationQueue: MockBackend.QueueProvider.createBackendQueue(),
                                          diagnosticsQueue: MockBackend.QueueProvider.createDiagnosticsQueue(),
                                          systemInfo: self.systemInfo,
                                          offlineCustomerInfoCreator: MockOfflineCustomerInfoCreator(),
                                          dateProvider: MockDateProvider(stubbedNow: MockBackend.referenceDate))
        self.backend = MockBackend(backendConfig: config, attributionFetcher: self.attributionFetcher)
        self.subscriberAttributesManager = MockSubscriberAttributesManager(
            backend: self.backend,
            deviceCache: self.deviceCache,
            operationDispatcher: self.mockOperationDispatcher,
            attributionFetcher: self.attributionFetcher,
            attributionDataMigrator: AttributionDataMigrator()
        )
        self.attributionPoster = AttributionPoster(deviceCache: self.deviceCache,
                                                   currentUserProvider: self.identityManager,
                                                   backend: self.backend,
                                                   attributionFetcher: self.attributionFetcher,
                                                   subscriberAttributesManager: self.subscriberAttributesManager,
                                                   systemInfo: self.systemInfo)
        self.attribution = Attribution(subscriberAttributesManager: self.subscriberAttributesManager,
                                       currentUserProvider: self.identityManager,
                                       attributionPoster: self.attributionPoster,
                                       systemInfo: self.systemInfo)
        self.mockOfflineEntitlementsManager = MockOfflineEntitlementsManager()
        self.customerInfoManager = CustomerInfoManager(offlineEntitlementsManager: self.mockOfflineEntitlementsManager,
                                                       operationDispatcher: self.mockOperationDispatcher,
                                                       deviceCache: self.deviceCache,
                                                       backend: self.backend,
                                                       transactionFetcher: self.mockTransactionFetcher,
                                                       transactionPoster: self.transactionPoster,
                                                       systemInfo: self.systemInfo)
        self.mockOfferingsManager = MockOfferingsManager(deviceCache: self.deviceCache,
                                                         operationDispatcher: self.mockOperationDispatcher,
                                                         systemInfo: self.systemInfo,
                                                         backend: self.backend,
                                                         offeringsFactory: self.offeringsFactory,
                                                         productsManager: self.mockProductsManager,
                                                         diagnosticsTracker: self.diagnosticsTracker)
        self.mockManageSubsHelper = MockManageSubscriptionsHelper(systemInfo: self.systemInfo,
                                                                  customerInfoManager: self.customerInfoManager,
                                                                  currentUserProvider: self.identityManager)
        self.mockBeginRefundRequestHelper = MockBeginRefundRequestHelper(systemInfo: self.systemInfo,
                                                                         customerInfoManager: self.customerInfoManager,
                                                                         currentUserProvider: self.identityManager)
        self.mockTransactionsManager = MockTransactionsManager(receiptParser: self.mockReceiptParser)
        self.mockStoreMessagesHelper = .init()
        self.mockWinBackOfferEligibilityCalculator = MockWinBackOfferEligibilityCalculator()
        self.mockVirtualCurrencyManager = MockVirtualCurrencyManager()
        self.webPurchaseRedemptionHelper = .init(backend: self.backend,
                                                 identityManager: self.identityManager,
                                                 customerInfoManager: self.customerInfoManager)

        self.addTeardownBlock {
            weak var purchases = self.purchases
            weak var orchestrator = self.purchasesOrchestrator
            weak var deviceCache = self.deviceCache

            Purchases.clearSingleton()
            self.clearReferences()

            // Note: this captures the boolean to avoid race conditions when Nimble tries
            // to print the instances while they're being deallocated.
            expect { purchases == nil }
                .toEventually(beTrue(), description: "Purchases has leaked")
            expect { orchestrator == nil }
                .toEventually(beTrue(), description: "PurchasesOrchestrator has leaked")
            expect { deviceCache == nil }
                .toEventually(beTrue(), description: "DeviceCache has leaked")
        }
    }

    override func tearDown() {
        self.userDefaults.removePersistentDomain(forName: Self.userDefaultsSuiteName)

        super.tearDown()
    }

    var receiptFetcher: MockReceiptFetcher!
    var requestFetcher: MockRequestFetcher!
    var mockProductsManager: MockProductsManager!
    var purchasedProductsFetcher: MockPurchasedProductsFetcher!
    var backend: MockBackend!
    var storeKit1Wrapper: MockStoreKit1Wrapper!
    var mockPaymentQueueWrapper: MockPaymentQueueWrapper!
    var notificationCenter: MockNotificationCenter!
    var userDefaults: UserDefaults! = nil
    let offeringsFactory = MockOfferingsFactory()
    var deviceCache: MockDeviceCache!
    var paywallCache: MockPaywallCacheWarming!
    private var paywallEventsManager: PaywallEventsManagerType?
    var subscriberAttributesManager: MockSubscriberAttributesManager!
    var attribution: Attribution!
    var identityManager: MockIdentityManager!
    var clock: TestClock!
    var systemInfo: MockSystemInfo!
    var mockOperationDispatcher: MockOperationDispatcher!
    var mockIntroEligibilityCalculator: MockIntroEligibilityCalculator!
    var mockReceiptParser: MockReceiptParser!
    var mockTransactionsManager: MockTransactionsManager!
    var attributionFetcher: MockAttributionFetcher!
    var attributionPoster: AttributionPoster!
    var customerInfoManager: CustomerInfoManager!
    var mockOfferingsManager: MockOfferingsManager!
    var mockOfflineEntitlementsManager: MockOfflineEntitlementsManager!
    var mockProductEntitlementMappingFetcher: MockProductEntitlementMappingFetcher!
    var mockPurchasedProductsFetcher: MockPurchasedProductsFetcher!
    var mockTransactionFetcher: MockStoreKit2TransactionFetcher!
    var purchasesOrchestrator: PurchasesOrchestrator!
    var trialOrIntroPriceEligibilityChecker: MockTrialOrIntroPriceEligibilityChecker!
    var cachingTrialOrIntroPriceEligibilityChecker: MockCachingTrialOrIntroPriceEligibilityChecker!
    var mockManageSubsHelper: MockManageSubscriptionsHelper!
    var mockBeginRefundRequestHelper: MockBeginRefundRequestHelper!
    var mockStoreMessagesHelper: MockStoreMessagesHelper!
    var mockWinBackOfferEligibilityCalculator: MockWinBackOfferEligibilityCalculator!
    var webPurchaseRedemptionHelper: WebPurchaseRedemptionHelper!
    var diagnosticsTracker: DiagnosticsTrackerType?
    var mockVirtualCurrencyManager: MockVirtualCurrencyManager!

    @available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
    var mockDiagnosticsTracker: MockDiagnosticsTracker {
        get throws {
            return try XCTUnwrap(self.diagnosticsTracker as? MockDiagnosticsTracker)
        }
    }

    // swiftlint:disable:next weak_delegate
    var purchasesDelegate: MockPurchasesDelegate!

    var purchases: Purchases!

    private var paymentQueueWrapper: EitherPaymentQueueWrapper {
        // Note: this logic must match `Purchases`.
        return self.systemInfo.storeKitVersion.isStoreKit2EnabledAndAvailable
            ? .right(self.mockPaymentQueueWrapper)
            : .left(self.storeKit1Wrapper)
    }

    private var transactionPoster: TransactionPoster {
        return .init(
            productsManager: self.mockProductsManager,
            receiptFetcher: self.receiptFetcher,
            transactionFetcher: self.mockTransactionFetcher,
            backend: self.backend,
            paymentQueueWrapper: self.paymentQueueWrapper,
            systemInfo: self.systemInfo,
            operationDispatcher: self.mockOperationDispatcher
        )
    }

    @available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
    var mockPaywallEventsManager: MockPaywallEventsManager {
        get throws {
            return try XCTUnwrap(self.paywallEventsManager as? MockPaywallEventsManager)
        }
    }

    func setupPurchases(
        automaticCollection: Bool = false,
        withDelegate: Bool = true
    ) {
        self.identityManager.mockIsAnonymous = false

        self.initializePurchasesInstance(
            appUserId: self.identityManager.currentAppUserID,
            withDelegate: withDelegate
        )
    }

    func setupAnonPurchases() {
        self.identityManager.mockIsAnonymous = true
        self.initializePurchasesInstance(appUserId: nil)
    }

    func setUpPurchasesObserverModeOn() {
        self.systemInfo = MockSystemInfo(platformInfo: nil,
                                         finishTransactions: false,
                                         storeKitVersion: self.storeKitVersion,
                                         clock: self.clock)
        self.storeKit1Wrapper = MockStoreKit1Wrapper(observerMode: true)
        self.initializePurchasesInstance(appUserId: nil)
    }

    func initializePurchasesInstance(
        appUserId: String?,
        withDelegate: Bool = true
    ) {
        self.purchasesOrchestrator = PurchasesOrchestrator(
            productsManager: self.mockProductsManager,
            paymentQueueWrapper: self.paymentQueueWrapper,
            systemInfo: self.systemInfo,
            subscriberAttributes: self.attribution,
            operationDispatcher: self.mockOperationDispatcher,
            receiptFetcher: self.receiptFetcher,
            receiptParser: self.mockReceiptParser,
            transactionFetcher: self.mockTransactionFetcher,
            customerInfoManager: self.customerInfoManager,
            backend: self.backend,
            transactionPoster: self.transactionPoster,
            currentUserProvider: self.identityManager,
            transactionsManager: self.mockTransactionsManager,
            deviceCache: self.deviceCache,
            offeringsManager: self.mockOfferingsManager,
            manageSubscriptionsHelper: self.mockManageSubsHelper,
            beginRefundRequestHelper: self.mockBeginRefundRequestHelper,
            storeMessagesHelper: self.mockStoreMessagesHelper,
            diagnosticsTracker: self.diagnosticsTracker,
            winBackOfferEligibilityCalculator: self.mockWinBackOfferEligibilityCalculator,
            paywallEventsManager: self.paywallEventsManager,
            webPurchaseRedemptionHelper: self.webPurchaseRedemptionHelper
        )
        self.trialOrIntroPriceEligibilityChecker = MockTrialOrIntroPriceEligibilityChecker(
            systemInfo: self.systemInfo,
            receiptFetcher: self.receiptFetcher,
            introEligibilityCalculator: self.mockIntroEligibilityCalculator,
            backend: self.backend,
            currentUserProvider: self.identityManager,
            operationDispatcher: self.mockOperationDispatcher,
            productsManager: self.mockProductsManager,
            diagnosticsTracker: self.diagnosticsTracker
        )
        self.cachingTrialOrIntroPriceEligibilityChecker = .init(checker: self.trialOrIntroPriceEligibilityChecker)
        let healthManager = SDKHealthManager(
            backend: self.backend,
            identityManager: self.identityManager
        )

        self.purchases = Purchases(appUserID: appUserId,
                                   requestFetcher: self.requestFetcher,
                                   receiptFetcher: self.receiptFetcher,
                                   attributionFetcher: self.attributionFetcher,
                                   attributionPoster: self.attributionPoster,
                                   backend: self.backend,
                                   paymentQueueWrapper: paymentQueueWrapper,
                                   userDefaults: self.userDefaults,
                                   notificationCenter: self.notificationCenter,
                                   systemInfo: self.systemInfo,
                                   offeringsFactory: self.offeringsFactory,
                                   deviceCache: self.deviceCache,
                                   paywallCache: self.paywallCache,
                                   identityManager: self.identityManager,
                                   subscriberAttributes: self.attribution,
                                   operationDispatcher: self.mockOperationDispatcher,
                                   customerInfoManager: self.customerInfoManager,
                                   paywallEventsManager: self.paywallEventsManager,
                                   productsManager: self.mockProductsManager,
                                   offeringsManager: self.mockOfferingsManager,
                                   offlineEntitlementsManager: self.mockOfflineEntitlementsManager,
                                   purchasesOrchestrator: self.purchasesOrchestrator,
                                   purchasedProductsFetcher: self.mockPurchasedProductsFetcher,
                                   trialOrIntroPriceEligibilityChecker: self.cachingTrialOrIntroPriceEligibilityChecker,
                                   storeMessagesHelper: self.mockStoreMessagesHelper,
                                   diagnosticsTracker: self.diagnosticsTracker,
                                   virtualCurrencyManager: self.mockVirtualCurrencyManager,
                                   healthManager: healthManager)

        self.purchasesOrchestrator.delegate = self.purchases

        if withDelegate {
            self.purchases.delegate = self.purchasesDelegate
        }

        Purchases.setDefaultInstance(self.purchases)
    }

    func makeAPurchase() {
        let product = StoreProduct(sk1Product: MockSK1Product(mockProductIdentifier: "com.product.id1"))

        guard let purchases = self.purchases else { fatalError("purchases is not initialized") }
        purchases.purchase(product: product) { _, _, _, _ in }

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKit1Wrapper.payment!
        transaction.mockState = SKPaymentTransactionState.purchased

        self.storeKit1Wrapper.delegate?.storeKit1Wrapper(self.storeKit1Wrapper, updatedTransaction: transaction)
    }

    var storeKitVersion: StoreKitVersion {
        // Even though the new default is StoreKit 2, most of the tests from this parent class
        // were written for SK1. Therefore we want to default to it being disabled.
        return .storeKit1
    }

}

extension BasePurchasesTests {

    static let appUserID = "app_user_id"

    static let emptyCustomerInfoData: [String: Any] = [
        "request_date": "2019-08-16T10:30:42Z",
        "subscriber": [
            "first_seen": "2019-07-17T00:05:54Z",
            "original_app_user_id": BasePurchasesTests.appUserID,
            "subscriptions": [:] as [String: Any],
            "other_purchases": [:] as [String: Any],
            "original_application_version": NSNull()
        ] as [String: Any]
    ]

}

extension BasePurchasesTests {

    final class MockOfferingsAPI: OfferingsAPI {

        var postedProductIdentifiers: Set<String>?

        override func getIntroEligibility(appUserID: String,
                                          receiptData: Data,
                                          productIdentifiers: Set<String>,
                                          completion: @escaping OfferingsAPI.IntroEligibilityResponseHandler) {
            self.postedProductIdentifiers = productIdentifiers

            var eligibilities = [String: IntroEligibility]()
            for productID in productIdentifiers {
                eligibilities[productID] = IntroEligibility(eligibilityStatus: .eligible)
            }

            completion(eligibilities, nil)
        }

        var failOfferings = false
        var badOfferingsResponse = false
        var gotOfferings = 0

        override func getOfferings(appUserID: String,
                                   isAppBackgrounded: Bool,
                                   completion: @escaping OfferingsAPI.OfferingsResponseHandler) {
            self.gotOfferings += 1
            if self.failOfferings {
                completion(.failure(.unexpectedBackendResponse(.getOfferUnexpectedResponse)))
                return
            }
            if self.badOfferingsResponse {
                completion(.failure(.networkError(.decoding(CodableError.invalidJSONObject(value: [:]), Data()))))
                return
            }

            completion(.success(.mockResponse))
        }

        var postOfferForSigningCalled = false
        var postOfferForSigningPaymentDiscountResponse: Result<[String: Any], BackendError> = .success([:])

        override func post(offerIdForSigning offerIdentifier: String,
                           productIdentifier: String,
                           subscriptionGroup: String?,
                           receipt: EncodedAppleReceipt,
                           appUserID: String,
                           completion: @escaping OfferingsAPI.OfferSigningResponseHandler) {
            self.postOfferForSigningCalled = true

            completion(
                self.postOfferForSigningPaymentDiscountResponse.map {
                    (
                        // swiftlint:disable:next force_cast line_length
                        $0["signature"] as! String, $0["keyIdentifier"] as! String, $0["nonce"] as! UUID, $0["timestamp"] as! Int
                    )
                }
            )
        }

    }

    final class MockBackend: Backend {

        static let referenceDate = Date(timeIntervalSinceReferenceDate: 700000000) // 2023-03-08 20:26:40

        var userID: String?
        var originalApplicationVersion: String?
        var originalPurchaseDate: Date?
        var getCustomerInfoCallCount = 0
        var overrideCustomerInfoResult: Result<CustomerInfo, BackendError> = .success(
            // swiftlint:disable:next force_try
            try! CustomerInfo(data: BasePurchasesTests.emptyCustomerInfoData)
        )

        override func getCustomerInfo(appUserID: String,
                                      isAppBackgrounded: Bool,
                                      allowComputingOffline: Bool,
                                      completion: @escaping CustomerAPI.CustomerInfoResponseHandler) {
            self.getCustomerInfoCallCount += 1
            self.userID = appUserID

            let result = self.overrideCustomerInfoResult
            DispatchQueue.main.async {
                completion(result)
            }
        }

        var healthReportRequests = [String]()
        override func healthReportRequest(appUserID: String) async throws -> HealthReport {
            healthReportRequests += [appUserID]

            return .init(
                status: .passed,
                projectId: nil,
                appId: nil,
                checks: []
            )
        }

        var overrideHealthReportAvailabilityResponse = HealthReportAvailability(reportLogs: true)
        var healthReportAvailabilityRequests = [String]()
        override func healthReportAvailabilityRequest(appUserID: String) async throws -> HealthReportAvailability {
            healthReportAvailabilityRequests.append(appUserID)

            return overrideHealthReportAvailabilityResponse
        }

        var postReceiptDataCalled = false
        var postedReceiptData: EncodedAppleReceipt?
        var postedIsRestore: Bool?
        var postedProductID: String?
        var postedPrice: Decimal?
        var postedPaymentMode: StoreProductDiscount.PaymentMode?
        var postedIntroPrice: Decimal?
        var postedCurrencyCode: String?
        var postedSubscriptionGroup: String?
        var postedDiscounts: [StoreProductDiscount]?
        var postedOfferingIdentifier: String?
        var postedObserverMode: Bool?
        var postedInitiationSource: ProductRequestData.InitiationSource?
        var postReceiptResult: Result<CustomerInfo, BackendError>?

        override func post(receipt: EncodedAppleReceipt,
                           productData: ProductRequestData?,
                           transactionData: PurchasedTransactionData,
                           observerMode: Bool,
                           appTransaction: String? = nil,
                           completion: @escaping CustomerAPI.CustomerInfoResponseHandler) {
            self.postReceiptDataCalled = true
            self.postedReceiptData = receipt
            self.postedIsRestore = transactionData.source.isRestore

            if let productData = productData {
                self.postedProductID = productData.productIdentifier
                self.postedPrice = productData.price

                self.postedPaymentMode = productData.paymentMode
                self.postedIntroPrice = productData.introPrice
                self.postedSubscriptionGroup = productData.subscriptionGroup

                self.postedCurrencyCode = productData.currencyCode
                self.postedDiscounts = productData.discounts
            }

            self.postedOfferingIdentifier = transactionData.presentedOfferingContext?.offeringIdentifier
            self.postedObserverMode = observerMode
            self.postedInitiationSource = transactionData.source.initiationSource

            completion(self.postReceiptResult ?? .failure(.missingAppUserID()))
        }

        var invokedPostAttributionData = false
        var invokedPostAttributionDataCount = 0
        var invokedPostAttributionDataParameters: (
            data: [String: Any]?,
            network: AttributionNetwork,
            appUserID: String?
        )?
        var invokedPostAttributionDataParametersList = [(data: [String: Any]?,
                                                         network: AttributionNetwork,
                                                         appUserID: String?)]()
        var stubbedPostAttributionDataCompletionResult: (BackendError?, Void)?

        override func post(attributionData: [String: Any],
                           network: AttributionNetwork,
                           appUserID: String,
                           completion: ((BackendError?) -> Void)? = nil) {
            self.invokedPostAttributionData = true
            self.invokedPostAttributionDataCount += 1
            self.invokedPostAttributionDataParameters = (attributionData, network, appUserID)
            self.invokedPostAttributionDataParametersList.append((attributionData, network, appUserID))
            if let result = stubbedPostAttributionDataCompletionResult {
                completion?(result.0)
            }
        }
    }
}

extension BasePurchasesTests.MockBackend: @unchecked Sendable {}
extension BasePurchasesTests.MockOfferingsAPI: @unchecked Sendable {}

private extension BasePurchasesTests {

    func clearReferences() {
        self.mockOperationDispatcher = nil
        self.mockPaymentQueueWrapper = nil
        self.requestFetcher = nil
        self.receiptFetcher = nil
        self.mockProductsManager = nil
        self.mockIntroEligibilityCalculator = nil
        self.mockTransactionsManager = nil
        self.backend = nil
        self.attributionFetcher = nil
        self.purchasesDelegate.makeDeferredPurchase = nil
        self.purchasesDelegate = nil
        self.storeKit1Wrapper.delegate = nil
        self.storeKit1Wrapper = nil
        self.systemInfo = nil
        self.notificationCenter = nil
        self.subscriberAttributesManager = nil
        self.trialOrIntroPriceEligibilityChecker = nil
        self.cachingTrialOrIntroPriceEligibilityChecker = nil
        self.attributionPoster = nil
        self.attribution = nil
        self.customerInfoManager = nil
        self.identityManager = nil
        self.mockOfferingsManager = nil
        self.mockOfflineEntitlementsManager = nil
        self.mockPurchasedProductsFetcher = nil
        self.mockTransactionFetcher = nil
        self.mockManageSubsHelper = nil
        self.mockBeginRefundRequestHelper = nil
        self.purchasesOrchestrator = nil
        self.deviceCache = nil
        self.paywallCache = nil
        self.paywallEventsManager = nil
        self.webPurchaseRedemptionHelper = nil
        self.purchases = nil
    }

}
