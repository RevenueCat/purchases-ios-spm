//
//  MockIntroEligibilityCalculator.swift
//  PurchasesTests
//
//  Created by Andrés Boedo on 8/4/20.
//  Copyright © 2020 Purchases. All rights reserved.
//

import Foundation

@testable import RevenueCat

class MockIntroEligibilityCalculator: IntroEligibilityCalculator {

    var invokedCheckTrialOrIntroDiscountEligibility = false
    var invokedCheckTrialOrIntroDiscountEligibilityCount = 0
    var invokedCheckTrialOrIntroDiscountEligibilityParameters: (receiptData: Data,
                                                                candidateProductIdentifiers: Set<String>)?
    var invokedCheckTrialOrIntroDiscountEligibilityParametersList = [(receiptData: Data,
                                                                          candidateProductIdentifiers: Set<String>)]()
    var stubbedCheckTrialOrIntroDiscountEligibilityResult: (Result<[String: IntroEligibilityStatus], Error>)?

    override func checkEligibility(with receiptData: Data,
                                   productIdentifiers candidateProductIdentifiers: Set<String>,
                                   completion: @escaping (Result<[String: IntroEligibilityStatus], Error>) -> Void) {
        invokedCheckTrialOrIntroDiscountEligibility = true
        invokedCheckTrialOrIntroDiscountEligibilityCount += 1
        invokedCheckTrialOrIntroDiscountEligibilityParameters = (receiptData, candidateProductIdentifiers)
        invokedCheckTrialOrIntroDiscountEligibilityParametersList.append((receiptData, candidateProductIdentifiers))
        completion(stubbedCheckTrialOrIntroDiscountEligibilityResult ?? .success([:]))
    }

}

extension MockIntroEligibilityCalculator: @unchecked Sendable {}
