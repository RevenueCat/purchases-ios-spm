//
//  JWTStrings.swift
//  Goodnotes
//
//  Created by Arturo Gutiérrez on 6/8/25.
//

import Foundation

// swiftlint:disable identifier_name

enum JWTStrings {
    case clearing_cache
    case storing_jwt(String)
    case using_jwt(String)
    case refreshing_jwt
    case unable_to_refresh_jwt
    case jwt_refreshed
}

extension JWTStrings: LogMessage {
    var description: String {
        switch self {
        case .clearing_cache: return "Clearing JWT cache"
        case let .storing_jwt(jwt): return "Storing JWT in cache: '\(jwt)'..."
        case let .using_jwt(jwt): return "Using JWT: '\(jwt)'"
        case .refreshing_jwt: return "Refreshing JWT calling to CustomerInfo..."
        case .unable_to_refresh_jwt: return "Unable to refresh JWT"
        case .jwt_refreshed: return "JWT refreshed"
        }
    }

    var category: String { return "jwt" }
}
