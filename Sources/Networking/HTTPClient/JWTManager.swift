//
//  JWTManager.swift
//  Goodnotes
//
//  Created by Arturo Gutiérrez on 6/8/25.
//

import Foundation

class JWTManager {
    private let userDefaults: SynchronizedUserDefaults

    convenience init() {
        self.init(
            userDefaults: UserDefaults(suiteName: Self.suiteName) ?? UserDefaults.standard
        )
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = .init(userDefaults: userDefaults)
    }

    func store(from urlResponse: URLResponse) {
        guard let httpUrlResponse = urlResponse as? HTTPURLResponse else { return }
        guard let url = httpUrlResponse.url else { return }

        let allHeaders = httpUrlResponse.allHeaderFields
            .compactMapKeys { $0 as? String }
            .compactMapValues { $0 as? String }

        let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaders, for: url)

        guard let cookie = cookies.first(where: { $0.name == Self.jwtCookieHeaderName }) else { return }
        let jwt = cookie.value

        Logger.debug(JWTStrings.storing_jwt(jwt))

        userDefaults.write {
            $0.set(jwt, forKey: .jwtKey)
        }
    }

    func jwtToken() -> String? {
        guard let base64 = userDefaults.read({ return $0.object(forKey: .jwtKey) as? String }) else {
            return nil
        }

        guard let jwt = JWTToken(tokenValue: base64) else { return nil }
        guard isJWTValid(jwt) else {
            userDefaults.write { $0.removeObject(forKey: .jwtKey) }
            return nil
        }

        Logger.debug(JWTStrings.using_jwt(base64))
        return base64
    }

    func jwtHeader() -> [String: String] {
        guard let jwt = jwtToken() else { return [:] }
        return ["Cookie": "\(Self.jwtCookieHeaderName)=\(jwt)"]
    }

    func clearCaches() {
        Logger.debug(Strings.jwt.clearing_cache)

        userDefaults.write {
            $0.removePersistentDomain(forName: Self.suiteName)
        }
    }

    private func isJWTValid(_ jwt: JWTToken) -> Bool {
        // We consider a token as as expired for less than 2 minute of validity
        // (using two minutes to play safe with the default timeouts of any network call).
        return Double(jwt.expiresAt - 120) > Date().timeIntervalSince1970
    }
}

struct JWTToken: Codable {
    enum CodingKeys: String, CodingKey {
        case expiresAt = "exp"
    }

    let expiresAt: Int64
}

extension JWTToken {
    public init?(tokenValue: String?) {
        guard let tokenValue else { return nil }
        let jwtComponents = tokenValue.components(separatedBy: ".")
        guard jwtComponents.count == 3 else { return nil }

        var jwtPayload = jwtComponents[1]
        // JWT uses base64url. Converting to standard base 64
        jwtPayload = jwtPayload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            // Padding payload to 4 multiple, otherwise base64 decode will fail
            .padding(toLength: ((jwtPayload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

        guard let decodedData = Data(base64Encoded: jwtPayload, options: []) else {
            return nil
        }
        guard let jwtToken = try? JSONDecoder().decode(JWTToken.self, from: decodedData) else {
            return nil
        }
        self.init(expiresAt: jwtToken.expiresAt)
    }
}

extension String {
    fileprivate static let jwtKey = "isi_jwt"
}

extension JWTManager {
    fileprivate static let suiteNameBase: String = "revenuecat.jwt"
    fileprivate static var suiteName: String {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return suiteNameBase
        }
        return bundleID + ".\(suiteNameBase)"
    }

    fileprivate static let jwtCookieHeaderName: String = "isi_token"
}
