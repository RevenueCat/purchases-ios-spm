//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  StoreKitTestHelpers.swift
//
//  Created by Nacho Soto on 1/24/22.

import Nimble
@testable import RevenueCat
import StoreKit
import StoreKitTest
import XCTest

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
extension XCTestCase {

    private enum Error: Swift.Error {
        case invalidTransactions([StoreKit.VerificationResult<Transaction>])
    }

    func setShortestTestSessionTimeRate(_ testSession: SKTestSession) {
        if #available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *) {
            #if swift(>=5.8)
            testSession.timeRate = .oneRenewalEveryTwoSeconds
            #else
            testSession.timeRate = SKTestSession.TimeRate.monthlyRenewalEveryThirtySeconds
            #endif
        } else if #available(iOS 15.2, tvOS 15.2, macOS 12.1, watchOS 8.3, *) {
            testSession.timeRate = SKTestSession.TimeRate.monthlyRenewalEveryThirtySeconds
        }
    }

    func setLongestTestSessionTimeRate(_ testSession: SKTestSession) {
        if #available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *) {
            #if swift(>=5.8)
            testSession.timeRate = .oneRenewalEveryFifteenMinutes
            #else
            testSession.timeRate = SKTestSession.TimeRate.monthlyRenewalEveryHour
            #endif
        } else if #available(iOS 15.2, tvOS 15.2, macOS 12.1, watchOS 8.3, *) {
            testSession.timeRate = SKTestSession.TimeRate.monthlyRenewalEveryHour
        }
    }

    // Some tests were randomly failing on CI when using `.oneRenewalEveryTwoSeconds` due to a race condition where the
    // purchase would expire before the receipt was posted.
    // This time rate is used to work around that issue by having a longer time rate.
    func setOneSecondIsOneDayTimeRate(_ testSession: SKTestSession) {
        // Using rawValue: 6 because the compiler shows this warning for `.oneSecondIsOneDay`:
        // 'oneSecondIsOneDay' was deprecated in iOS 15.2: renamed to
        // 'SKTestSession.TimeRate.monthlyRenewalEveryThirtySeconds'
        // However, we've found that their behavior is not equivalent since using `monthlyRenewalEveryThirtySeconds`
        // results in a crash in our tests.
        testSession.timeRate = .init(rawValue: 6)! // == .oneSecondIsOneDay
    }

    func verifyNoUnfinishedTransactions(file: FileString = #filePath, line: UInt = #line) async {
        let unfinished = await StoreKit.Transaction.unfinished.extractValues()
        expect(file: file, line: line, unfinished).to(beEmpty())
    }

    func verifyUnfinishedTransaction(
        withId identifier: Transaction.ID,
        file: FileString = #filePath,
        line: UInt = #line
    ) async throws {
        let unfinishedTransactions = await self.unfinishedTransactions

        expect(file: file, line: line, unfinishedTransactions).to(haveCount(1))

        guard let transaction = unfinishedTransactions.onlyElement,
              case let .verified(verified) = transaction else {
            throw Error.invalidTransactions(unfinishedTransactions)
        }

        expect(file: file, line: line, verified.id) == identifier
    }

    func waitUntilUnfinishedTransactions(
        condition: @Sendable @escaping (Int) -> Bool,
        file: FileString = #fileID,
        line: UInt = #line
    ) async throws {
        try await asyncWait(
            file: file,
            line: line,
            description: { "Transaction expectation never met: \($0 ?? [])" },
            until: { await Transaction.unfinished.extractValues() },
            condition: { condition($0.count) }
        )
    }

    func waitUntilNoUnfinishedTransactions(file: FileString = #fileID, line: UInt = #line) async throws {
        try await self.waitUntilUnfinishedTransactions { $0 == 0 }
    }

    func deleteAllTransactions(session: SKTestSession) async {
        let sk1Transactions = session.allTransactions()
        if !sk1Transactions.isEmpty {
            Logger.debug(StoreKitTestMessage.deletingTransactions(count: sk1Transactions.count))

            for transaction in sk1Transactions {
                try? session.deleteTransaction(identifier: transaction.identifier)
            }
        }

        let sk2Transactions = await self.unfinishedTransactions
        if !sk2Transactions.isEmpty {
            Logger.debug(StoreKitTestMessage.finishingTransactions(count: sk2Transactions.count))

            for transaction in sk2Transactions.map(\.underlyingTransaction) {
                await transaction.finish()
                try? session.deleteTransaction(identifier: UInt(transaction.id))
            }
        }
    }

    private var unfinishedTransactions: [StoreKit.VerificationResult<Transaction>] {
        get async { return await StoreKit.Transaction.unfinished.extractValues() }
    }

}

@available(iOS 15.0, tvOS 15.0, macOS 12.0, watchOS 8.0, *)
extension Product.PurchaseResult {

    var verificationResult: StoreKit.VerificationResult<Transaction>? {
        switch self {
        case let .success(verificationResult): return verificationResult
        case .userCancelled: return nil
        case .pending: return nil
        @unknown default: return nil
        }
    }

}

enum StoreKitTestMessage: LogMessage {

    case delayingTest(TimeInterval)
    case errorRemovingReceipt(URL, Error)
    case deletingTransactions(count: Int)
    case finishingTransactions(count: Int)

    var description: String {
        switch self {
        case let .delayingTest(waitTime):
            return "Delaying tests for \(waitTime) seconds for StoreKit initialization..."
        case let .errorRemovingReceipt(url, error):
            return "Error attempting to remove receipt URL '\(url)': \(error)"
        case let .deletingTransactions(count):
            return "Deleting \(count) transactions"
        case let .finishingTransactions(count):
            return "Finishing \(count) transactions"
        }
    }

    var category: String { return "StoreKitConfigTestCase" }

}
