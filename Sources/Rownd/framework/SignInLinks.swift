//
//  SignInLinks.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/16/22.
//

import Foundation
import Get

struct SignInLinkResp: Hashable, Codable {
    public var accessToken: String?
    public var refreshToken: String?
    public var appId: String?
    public var appUserId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case appId = "app_id"
        case appUserId = "app_user_id"
    }
}

class SignInLinks {
    static func signInWithLink(_ url: URL) async throws {
        do {
            var signInUrl = url
            if let fragment = signInUrl.fragment {
                signInUrl = URL(string: signInUrl.absoluteString.replacingOccurrences(of: "#\(fragment)", with: "")) ?? signInUrl
            }

            Task { @MainActor in
                if Rownd.isDisplayingHub() {
                    Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                        loginStep: .completing
                    ))
                }
            }
            let authResp: SignInLinkResp = try await Rownd.apiClient.send(Request(url: signInUrl)).value

            Task { @MainActor in
                Context.currentContext.store.dispatch(SetAuthState(payload: AuthState(
                    accessToken: authResp.accessToken,
                    refreshToken: authResp.refreshToken
                )))

                Context.currentContext.store.dispatch(UserData.fetch())

                Context.currentContext.store.dispatch(PasskeyData.fetchPasskeyRegistration())

                if Rownd.isDisplayingHub() {
                    Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                        loginStep: .success
                    ))
                }
            }
        } catch {
            Task { @MainActor in
                if Rownd.isDisplayingHub() {
                    Rownd.requestSignIn(jsFnOptions: RowndSignInJsOptions(
                        loginStep: .error
                    ))
                }
            }
            logger.error("Auto sign-in failed: \(String(describing: error))")
            throw SignInError("Auto sign-in failed: \(error.localizedDescription)")
        }
    }
}

struct SignInError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
