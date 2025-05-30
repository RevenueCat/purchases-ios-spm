//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  StoreKit2TransactionListenerTests.swift
//
//  Created by Nacho Soto on 1/14/22.

import Nimble
@testable import RevenueCat
import StoreKit
import StoreKitTest
import XCTest

// swiftlint:disable type_name

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
class StoreKit2TransactionListenerBaseTests: StoreKitConfigTestCase {

    typealias TransactionResult = StoreKit2TransactionListener.TransactionResult

    fileprivate var listener: StoreKit2TransactionListener! = nil
    fileprivate var delegate: MockStoreKit2TransactionListenerDelegate! = nil
    fileprivate let mockDiagnosticsTracker = MockDiagnosticsTracker()

    var updates: AsyncStream<TransactionResult> {
        get async throws {
            return Transaction.updates.toAsyncStream()
        }
    }

    override func setUp() async throws {
        try await super.setUp()

        try AvailabilityChecks.iOS16APIAvailableOrSkipTest()

        // Unfinished transactions before beginning the test might lead to false positives / negatives
        await self.verifyNoUnfinishedTransactions()

        self.delegate = .init()
        self.listener = .init(delegate: self.delegate,
                              diagnosticsTracker: self.mockDiagnosticsTracker,
                              updates: try await self.updates)
    }

}

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
class StoreKit2TransactionListenerTests: StoreKit2TransactionListenerBaseTests {

    func testStopsListeningToTransactions() async throws {
        try AvailabilityChecks.iOS16APIAvailableOrSkipTest()

        var handle: Task<Void, Never>?

        handle = await self.listener.taskHandle
        expect(handle).to(beNil())

        await self.listener.listenForTransactions()
        handle = await self.listener.taskHandle

        expect(handle).toNot(beNil())
        expect(handle?.isCancelled) == false

        self.listener = nil
        expect(handle?.isCancelled) == true
    }

    // MARK: -

    func testVerifiedTransactionReturnsOriginalTransaction() async throws {
        try AvailabilityChecks.iOS16APIAvailableOrSkipTest()

        let fakeTransaction = try await self.simulateAnyPurchase()

        let (isCancelled, transaction) = try await self.listener.handle(
            purchaseResult: .success(fakeTransaction)
        )
        expect(isCancelled) == false
        expect(transaction?.sk2Transaction) == fakeTransaction.underlyingTransaction
    }

    func testIsCancelledIsTrueWhenPurchaseIsCancelled() async throws {
        try AvailabilityChecks.iOS16APIAvailableOrSkipTest()

        let (isCancelled, transaction) = try await self.listener.handle(purchaseResult: .userCancelled)
        expect(isCancelled) == true
        expect(transaction).to(beNil())
    }

    func testPendingTransactionsReturnPaymentPendingError() async throws {
        try AvailabilityChecks.iOS16APIAvailableOrSkipTest()

        // Note: can't use `expect().to(throwError)` or `XCTAssertThrowsError`
        // because neither of them accept `async`
        do {
            _ = try await self.listener.handle(purchaseResult: .pending)
            XCTFail("Error expected")
        } catch {
            expect(error).to(matchError(ErrorCode.paymentPendingError))
        }
    }

    func testUnverifiedTransactionsReturnStoreProblemError() async throws {
        try AvailabilityChecks.iOS16APIAvailableOrSkipTest()

        let transaction = try await self.simulateAnyPurchase()
        let error: StoreKit.VerificationResult<Transaction>.VerificationError = .invalidSignature
        let result: StoreKit.VerificationResult<Transaction> = .unverified(transaction.underlyingTransaction, error)

        // Note: can't use `expect().to(throwError)` or `XCTAssertThrowsError`
        // because neither of them accept `async`
        do {
            _ = try await self.listener.handle(purchaseResult: .success(result))
            XCTFail("Error expected")
        } catch {
            expect(error).to(matchError(ErrorCode.storeProblemError))
        }
    }

    func testPurchasingDoesNotFinishTransaction() async throws {
        await self.listener.listenForTransactions()

        await self.verifyNoUnfinishedTransactions()

        let (_, _, purchasedTransaction) = try await self.purchase()
        expect(purchasedTransaction.ownershipType) == .purchased

        try await self.verifyUnfinishedTransaction(withId: purchasedTransaction.id)
    }

    func testHandlePurchaseResultDoesNotFinishTransaction() async throws {
        let (purchaseResult, _, purchasedTransaction) = try await self.purchase()

        let resultData = try await self.listener.handle(purchaseResult: purchaseResult)
        expect(resultData.transaction?.sk2Transaction) == purchasedTransaction
        expect(resultData.userCancelled) == false

        try await self.verifyUnfinishedTransaction(withId: purchasedTransaction.id)
    }

    func testHandlePurchaseResultDoesNotNotifyDelegate() async throws {
        let result = try await self.purchase().result
        _ = try await self.listener.handle(purchaseResult: result)

        expect(self.delegate.invokedTransactionUpdated) == false
    }

    func testHandleUnverifiedPurchase() async throws {
        let (_, _, transaction) = try await self.purchase()

        let verificationError: StoreKit.VerificationResult<Transaction>.VerificationError = .invalidSignature

        do {
            _ = try await self.listener.handle(
                purchaseResult: .success(.unverified(transaction, verificationError))
            )
            fail("Expected error")
        } catch {
            expect(error).to(matchError(ErrorCode.storeProblemError))

            let underlyingError = try XCTUnwrap((error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError)
            expect(underlyingError).to(matchError(verificationError))
        }
    }

    func testHandlePurchaseResultWithCancelledPurchase() async throws {
        let result = try await self.listener.handle(purchaseResult: .userCancelled)
        expect(result.userCancelled) == true
        expect(result.transaction).to(beNil())
    }

    func testHandlePurchaseResultWithDeferredPurchase() async throws {
        do {
            _ = try await self.listener.handle(purchaseResult: .pending)
            fail("Expected error")
        } catch {
            expect(error).to(matchError(ErrorCode.paymentPendingError))
        }
    }

}

// MARK: - Transaction.updates tests

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
class StoreKit2TransactionListenerTransactionUpdatesTests: StoreKit2TransactionListenerBaseTests {

    func testPurchasingInTheAppDoesNotNotifyDelegate() async throws {
        await self.listener.listenForTransactions()

        try await self.simulateAnyPurchase(finishTransaction: true)
        try await self.verifyTransactionsWereNotUpdated()
    }

    func testPurchasingOutsideTheAppNotifiesDelegate() async throws {
        await self.listener.listenForTransactions()

        try self.testSession.buyProduct(productIdentifier: Self.productID)

        try await asyncWait { [delegate = self.delegate!] in
            delegate.invokedTransactionUpdated == true
        }
    }

    func testNotifiesDelegateForExistingTransactions() async throws {
        try self.testSession.buyProduct(productIdentifier: Self.productID)

        await self.listener.listenForTransactions()

        try await asyncWait { [delegate = self.delegate!] in
            delegate.invokedTransactionUpdated == true
        }
    }

    @available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
    func testNotifiesDelegateForRenewals() async throws {
        try AvailabilityChecks.iOS16APIAvailableOrSkipTest()

        setShortestTestSessionTimeRate(self.testSession)

        try await self.simulateAnyPurchase(finishTransaction: true)

        await self.listener.listenForTransactions()

        // swiftlint:disable:next force_try
        try! await Task.sleep(nanoseconds: 3 * 1_000_000_000)

        try await self.waitForTransactionUpdated()

        expect(self.delegate.updatedTransactions)
            .to(containElementSatisfying { transaction in
                transaction.productIdentifier == Self.productID
            })

        self.logger.verifyMessageWasLogged(Strings.purchase.sk2_transactions_update_received_transaction(
            productID: Self.productID
        ))
    }

}

// MARK: - Tests with custom stream

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
class StoreKit2TransactionListenerCustomStreamTests: StoreKit2TransactionListenerBaseTests {

    override var updates: AsyncStream<TransactionResult> {
        get async throws {
            return MockAsyncSequence<TransactionResult>(with: [
                .verified(try await self.createTransactionWithPurchase()),
                .verified(try await self.createTransactionWithPurchase()),
                .unverified(
                    try await self.createTransactionWithPurchase(),
                    .revokedCertificate
                )
            ])
            .toAsyncStream()
        }
    }

    func testHandlesAllVerifiedTransactions() async throws {
        await self.listener.listenForTransactions()

        try await asyncWait { [delegate = self.delegate!] in
            return delegate.updatedTransactions.count == 2
        }
    }

    func testHandlesTransactionsAsynchronously() async throws {
        self.delegate.fakeHandlingDelay = .milliseconds(50)

        await self.listener.listenForTransactions()

        try await asyncWait { [delegate = self.delegate!] in
            return delegate.updatedTransactions.count == 2
        }

        expect(self.delegate.receivedConcurrentRequest) == true
    }

}

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
private extension StoreKit2TransactionListenerBaseTests {

    private enum Error: Swift.Error {
        case invalidResult(Product.PurchaseResult)
    }

    func purchase() async throws -> (
        result: Product.PurchaseResult,
        verificationResult: StoreKit.VerificationResult<Transaction>,
        transaction: Transaction
    ) {
        let result = try await self.fetchSk2Product().purchase()

        guard case let .success(verificationResult) = result,
              case let .verified(transaction) = verificationResult
        else {
            throw Error.invalidResult(result)
        }

        return (result, verificationResult, transaction)
    }

    func verifyTransactionsWereNotUpdated() async throws {
        // In order for this test to not be a false positive we need to
        // give it a chance to handle the potential transaction.
        try await Task.sleep(nanoseconds: UInt64(DispatchTimeInterval.milliseconds(300).nanoseconds))

        expect(self.delegate.invokedTransactionUpdated) == false
    }

    @available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
    func waitForTransactionUpdated(
        file: FileString = #fileID,
        line: UInt = #line
    ) async throws {
        try await asyncWait(
            description: "Transaction update",
            timeout: .seconds(4),
            pollInterval: .milliseconds(100),
            file: file,
            line: line
        ) { [delegate = self.delegate!] in
            delegate.invokedTransactionUpdated == true
        }
    }

}

// MARK: - Diagnostics tests

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
class StoreKit2TransactionListenerDiagnosticsTests: StoreKit2TransactionListenerBaseTests {

    func testTracksDiagnosticsWhenPurchasingOutside() async throws {
        await self.listener.listenForTransactions()

        try self.testSession.buyProduct(productIdentifier: "com.revenuecat.annual_39.99_no_trial")

        try await asyncWait { [delegate = self.delegate!] in
            delegate.invokedTransactionUpdated == true
        }

        expect(self.mockDiagnosticsTracker.trackedAppleTransactionUpdateReceivedParams.value.count) == 1
        let params = self.mockDiagnosticsTracker.trackedAppleTransactionUpdateReceivedParams.value[0]
        expect(params.productId) == "com.revenuecat.annual_39.99_no_trial"
        expect(params.environment) == "xcode"

        #if compiler(>=6.0)
        expect(params.price) == 39.99
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
            expect(params.storefront) == "USA"
            expect(params.reason) == "PURCHASE"
        }
        #endif
    }

    func testTracksDiagnosticsWhenNotifiedForExistingTransactions() async throws {
        try self.testSession.buyProduct(productIdentifier: "com.revenuecat.annual_39.99_no_trial")

        await self.listener.listenForTransactions()

        try await asyncWait { [delegate = self.delegate!] in
            delegate.invokedTransactionUpdated == true
        }

        expect(self.mockDiagnosticsTracker.trackedAppleTransactionUpdateReceivedParams.value.count) == 1
        let params = self.mockDiagnosticsTracker.trackedAppleTransactionUpdateReceivedParams.value[0]
        expect(params.productId) == "com.revenuecat.annual_39.99_no_trial"
        expect(params.environment) == "xcode"

        #if compiler(>=6.0)
        expect(params.price) == 39.99

        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
            expect(params.storefront) == "USA"
            expect(params.reason) == "PURCHASE"
        }
        #endif
    }

    @available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
    func testTracksDiagnosticsForRenewals() async throws {

        setShortestTestSessionTimeRate(self.testSession)

        try await self.simulateAnyPurchase(finishTransaction: true)

        await self.listener.listenForTransactions()

        try await Task.sleep(nanoseconds: 3 * 1_000_000_000)

        try await self.waitForTransactionUpdated()

        expect(self.mockDiagnosticsTracker.trackedAppleTransactionUpdateReceivedParams.value).toNot(beEmpty())
        let params = self.mockDiagnosticsTracker.trackedAppleTransactionUpdateReceivedParams.value[0]
        expect(params.productId) == Self.productID
        expect(params.environment) == "xcode"

        let expirationDate = try XCTUnwrap(params.expirationDate)
        expect(expirationDate.timeIntervalSince(params.purchaseDate)) == 2 // see setShortestTestSessionTimeRate()

        #if compiler(>=6.0)
        expect(params.price) == 4.99

        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
            expect(params.storefront) == "USA"
            expect(params.reason) == "RENEWAL"
        }
        #endif
    }

}
