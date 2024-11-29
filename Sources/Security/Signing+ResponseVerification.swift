//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  Signing+ResponseVerification.swift
//
//  Created by Nacho Soto on 2/8/23.

import Foundation

extension HTTPResponse where Body == Data? {

    func verify(
        signing: SigningType,
        request: HTTPRequest,
        requestHeaders: HTTPRequest.Headers,
        publicKey: Signing.PublicKey?,
        customPublicKey: Signing.PublicKey?
    ) -> VerifiedHTTPResponse<Body> {
        let verificationResult = Self.verificationResult(
            body: self.body,
            statusCode: self.httpStatusCode,
            requestHeaders: requestHeaders,
            responseHeaders: self.responseHeaders,
            requestDate: self.requestDate,
            request: request,
            publicKey: publicKey,
            customPublicKey: customPublicKey,
            signing: signing
        )

        #if DEBUG
        if verificationResult == .failed, ProcessInfo.isRunningRevenueCatTests {
            Logger.warn(Strings.signing.invalid_signature_data(
                request,
                self.body,
                self.responseHeaders,
                self.httpStatusCode
            ))
        }
        #endif

        return self.verified(with: verificationResult)
    }

    // swiftlint:disable:next function_parameter_count
    private static func verificationResult(
        body: Data?,
        statusCode: HTTPStatusCode,
        requestHeaders: HTTPClient.RequestHeaders,
        responseHeaders: HTTPClient.ResponseHeaders,
        requestDate: Date?,
        request: HTTPRequest,
        publicKey: Signing.PublicKey?,
        customPublicKey: Signing.PublicKey?,
        signing: SigningType
    ) -> VerificationResult {
        var signatureHeaderName: String = HTTPClient.ResponseHeader.signature.rawValue
        if let preferredSignatureHeaderName = HTTPResponse.value(forCaseInsensitiveHeaderField: .signatureHeaderName, in: responseHeaders) {
            signatureHeaderName = preferredSignatureHeaderName
        }
        
        let publicKeyToUse: Signing.PublicKey?
        if signatureHeaderName == HTTPClient.ResponseHeader.signature.rawValue {
            publicKeyToUse = publicKey
        } else {
            publicKeyToUse = customPublicKey
        }
        
        guard let publicKey = publicKeyToUse, statusCode.isSuccessfulResponse else {
            return .notRequested
        }

        guard let signature = HTTPResponse.value(
            forCaseInsensitiveHeaderField: signatureHeaderName,
            in: responseHeaders
        ) else {
            if request.path.supportsSignatureVerification {
                Logger.warn(Strings.signing.signature_was_requested_but_not_provided(request))
                return .failed
            } else {
                return .notRequested
            }
        }

        guard let requestDate = requestDate else {
            Logger.warn(Strings.signing.request_date_missing_from_headers(request))

            return .failed
        }

        if signing.verify(signature: signature,
                          with: .init(
                            path: request.path,
                            message: body,
                            requestHeaders: requestHeaders,
                            requestBody: request.requestBody,
                            nonce: request.nonce,
                            etag: HTTPResponse.value(forCaseInsensitiveHeaderField: .eTag, in: responseHeaders),
                            requestDate: requestDate.millisecondsSince1970
                          ),
                          publicKey: publicKey) {
            return .verified
        } else {
            return .failed
        }
    }

}
