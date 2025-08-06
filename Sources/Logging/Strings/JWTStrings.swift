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
}

extension JWTStrings: LogMessage {
    var description: String {
        switch self {
        case .clearing_cache: return "Clearing JWT cache"
        case let .storing_jwt(jwt): return "Storing JWT in cache: '\(jwt)'..."
        case let .using_jwt(jwt): return "Using JWT: '\(jwt)'"
        }
    }

    var category: String { return "jwt" }
}
