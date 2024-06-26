//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  MockStoreKit2TransactionListener.swift
//
//  Created by Andrés Boedo on 23/9/21.

import Foundation
@testable import RevenueCat
import StoreKit

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
final class MockStoreKit2TransactionListener: StoreKit2TransactionListenerType {

    init() {}

    var invokedDelegateSetter = false
    var invokedDelegateSetterCount = 0
    weak var invokedDelegate: StoreKit2TransactionListenerDelegate?
    var invokedDelegateList: [StoreKit2TransactionListenerDelegate] = []

    var mockCancelled = false
    // `StoreKit.Transaction` can't be stored directly as a property.
    // See https://openradar.appspot.com/radar?id=4970535809187840 / https://bugs.swift.org/browse/SR-15825
    var mockTransaction: Box<StoreKit.Transaction?> = .init(nil)
    var mockResult: Box<StoreKit.Product.PurchaseResult?> = .init(nil)
    var mockJWSToken: String = ""
    var mockEnvironment: StoreEnvironment = .sandbox

    func set(delegate: StoreKit2TransactionListenerDelegate) {
        self.invokedDelegateSetter = true
        self.invokedDelegateSetterCount += 1
        self.invokedDelegate = delegate
        self.invokedDelegateList.append(delegate)
    }

    var invokedListenForTransactions = false
    var invokedListenForTransactionsCount = 0

    func listenForTransactions() {
        self.invokedListenForTransactions = true
        self.invokedListenForTransactionsCount += 1
    }

    var invokedHandle = false
    var invokedHandleCount = 0
    // `purchaseResult` can't be stored directly as a property.
    // See https://openradar.appspot.com/radar?id=4970535809187840
    var invokedHandleParameters: (purchaseResult: Box<StoreKit.Product.PurchaseResult>, Void)?
    var invokedHandleParametersList = [(purchaseResult: Box<StoreKit.Product.PurchaseResult>, Void)]()

    func handle(
        purchaseResult: StoreKit.Product.PurchaseResult,
        fromTransactionUpdate: Bool = false
    ) async throws -> StoreKit2TransactionListener.ResultData {
        self.invokedHandle = true
        self.invokedHandleCount += 1
        self.invokedHandleParameters = (.init(purchaseResult), ())
        self.invokedHandleParametersList.append((.init(purchaseResult), ()))

        var transaction: StoreTransaction?

        if let mockTransaction = self.mockTransaction.value {
            transaction = StoreTransaction(sk2Transaction: mockTransaction,
                                           jwsRepresentation: self.mockJWSToken,
                                           environmentOverride: self.mockEnvironment)
        } else if let mockResult  = self.mockResult.value {
            if let verificationResult = mockResult.verificationResult {
                transaction = StoreTransaction(sk2Transaction: verificationResult.underlyingTransaction,
                                               jwsRepresentation: self.mockJWSToken,
                                               environmentOverride: self.mockEnvironment)
            }
        } else if let parameterResult = purchaseResult.verificationResult {
            transaction = StoreTransaction(sk2Transaction: parameterResult.underlyingTransaction,
                                           jwsRepresentation: parameterResult.jwsRepresentation,
                                           environmentOverride: self.mockEnvironment)
        }

        return (self.mockCancelled, transaction)
    }

    var invokedHandleSK2ObserverModeTransaction = false
    var invokedHandleSK2ObserverModeTransactionCount = 0
    func handleSK2ObserverModeTransaction(verifiedTransaction: Transaction, jwsRepresentation: String) async throws {
        self.invokedHandleSK2ObserverModeTransaction = true
        invokedHandleSK2ObserverModeTransactionCount += 1
    }
}

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
extension MockStoreKit2TransactionListener: @unchecked Sendable {}
