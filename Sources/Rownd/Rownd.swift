//
//  Rownd.swift
//  framework
//
//  Created by Matt Hamann on 6/23/22.
//

import Foundation
import SwiftUI
import UIKit
import ReSwift
import WebKit
import AnyCodable
import AuthenticationServices
import LBBottomSheet

public class Rownd: NSObject {
    private static let inst: Rownd = Rownd()
    public static var config: RowndConfig = RowndConfig()

    public static let user = UserPropAccess()
    private static var appleSignUpCoordinator: AppleSignUpCoordinator? = AppleSignUpCoordinator(inst)
    internal static var apiClient = RowndApi().client
    
    private override init() {}
    
    public static func configure(launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil, appKey: String?) async {
        if let _appKey = appKey {
            config.appKey = _appKey
        }
        
        inst.inflateStoreCache()
        await inst.loadAppConfig()
        inst.loadAppleSignIn()
        
        if await Rownd.getAccessToken() != nil {
            DispatchQueue.main.async {
                store.dispatch(SetUserLoading(isLoading: false)) // Make sure user is not in loading state during initial bootstrap
                store.dispatch(UserData.fetch())
            }
        }

        if !store.state.auth.isAuthenticated {
            var launchUrl: URL?
            if let _launchUrl = launchOptions?[.url] as? URL {
                launchUrl = _launchUrl
            } else if UIPasteboard.general.hasStrings, var _launchUrl = UIPasteboard.general.string {
                if !_launchUrl.starts(with: "http") {
                    _launchUrl = "https://\(_launchUrl)"
                }
                launchUrl = URL(string: _launchUrl)
            }

            handleSignInLink(url: launchUrl)
        }
    }

    @discardableResult public static func handleSignInLink(url: URL?) -> Bool {
        if store.state.auth.isAuthenticated {
            return true
        }

        if (url?.host?.hasSuffix("rownd.link")) != nil, let url = url {
            logger.trace("handling url: \(String(describing: url.absoluteString))")

            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            urlComponents?.scheme = "https"

            guard let url = urlComponents?.url else {
                return false
            }

            Task {
                do {
                    try await SignInLinks.signInWithLink(url)
                } catch {
                    logger.error("Sign-in attempt failed during launch: \(String(describing: error))")
                }
            }

            return true
        }

        return false
    }
    
    public static func getInstance() -> Rownd {
        return inst
    }
    
    public static func requestSignIn() {
        requestSignIn(nil)
    }
    
    public static func requestSignIn(with: RowndSignInHint) {
        switch with {
        case .appleId:
            appleSignUpCoordinator?.didTapButton()
        default:
            requestSignIn()
        }
    }
    
    public static func requestSignIn(_ signInOptions: RowndSignInOptions?) {
        let _ = inst.displayHub(.signIn, jsFnOptions: signInOptions ?? RowndSignInOptions() )
    }
    
    public static func signOut() {
        let _ = inst.displayHub(.signOut)

        DispatchQueue.main.async {
            store.dispatch(SetAuthState(payload: AuthState()))
            store.dispatch(SetUserState(payload: UserState()))
        }
    }

    public static func transferEncryptionKey() {
        var behavior: LBBottomSheet.BottomSheetController.Behavior = .init(swipeMode: .full)
        behavior.heightMode = .specific(values: [.screenRatio(value: 1), .screenRatio(value: 0.65)], heightLimit: .statusBar)

        var theme: LBBottomSheet.BottomSheetController.Theme = .init()
        theme.grabber?.topMargin = CGFloat(10.0)

        DispatchQueue.main.async {
            inst.getRootViewController()?.presentAsBottomSheet(KeyTransferViewController(), theme: theme, behavior: behavior)
        }
    }
    
    public static func manageAccount() {
        let _ = inst.displayHub(.manageAccount)
    }
    
    @discardableResult public static func getAccessToken() async -> String? {
        return await store.state.auth.getAccessToken()
    }
    
    public func state() -> Store<RowndState> {
        return store
    }
    
    public static func _refreshToken() {
        Auth.fetchToken(refreshToken: store.state.auth.refreshToken ?? "no token") { authState in
            print(authState)
        }
    }
    
    // MARK: Internal methods
    private func loadAppleSignIn() {
        //If we want to check if the AppleId userIdentifier is still valid
    }
 
    
    private func loadAppConfig() async {
        if store.state.appConfig.id == nil {
            // Await the config if it wasn't already cached
            let appConfig = await AppConfig.fetch()
            DispatchQueue.main.async {
                store.dispatch(SetAppConfig(payload: appConfig?.app ?? store.state.appConfig))
            }
        } else {
            DispatchQueue.main.async {
                // Refresh in background if already present
                store.dispatch(AppConfig.requestAppState())
            }
        }

    }
    
    private func inflateStoreCache() {
        RowndState.load()
    }
    
    private func displayHub(_ page: HubPageSelector) -> HubViewController {
        return displayHub(page, jsFnOptions: nil)
    }
    
    private func displayHub(_ page: HubPageSelector, jsFnOptions: Encodable?) -> HubViewController {
        let hubController = HubViewController()
        hubController.targetPage = page
        
        displayViewControllerOnTop(hubController)
        
        if let jsFnOptions = jsFnOptions {
            do {
                hubController.hubWebController.jsFunctionArgsAsJson = try jsFnOptions.asJsonString()
            } catch {
                logger.error("Failed to encode JS options to pass to function: \(String(describing: error))")
            }
        }
        
        return hubController
    }

    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first?.rootViewController
    }
    
    private func displayViewControllerOnTop(_ viewController: UIViewController) {
        let rootViewController = getRootViewController()
        
        // TODO: Eventually, replace this with native iOS 15+ sheetPresentationController
        // But, we can't replace it yet (2022) since there are too many devices running iOS 14.
        let bottomSheetController = BottomSheetController()
        bottomSheetController.controller = viewController
        bottomSheetController.modalPresentationStyle = .overFullScreen

        DispatchQueue.main.async {
            rootViewController?.present(bottomSheetController, animated: true, completion: nil)
        }
    }
    
}

public class UserPropAccess {
    public func get() -> UserState {
        return store.state.user.get()
    }
    
    public func get(field: String) -> Any {
        return store.state.user.get(field: field)
    }
    
    public func get<T>(field: String) -> T? {
        let value: T? = store.state.user.get(field: field)
        return value
    }
    
    public func set(data: Dictionary<String, AnyCodable>) -> Void {
        store.state.user.set(data: data)
    }
    
    public func set(field: String, value: AnyCodable) -> Void {
        store.state.user.set(field: field, value: value)
    }

    public func isEncryptionPossible() -> Bool {
        do {
            let key = RowndEncryption.loadKey(keyId: try getKeyId())

            guard let _ = key else {
                return false
            }

            return true
        } catch {
            return false
        }
    }

    public func encrypt(plaintext: String) throws -> String {
        return try RowndEncryption.encrypt(plaintext: plaintext, withKeyId: try getKeyId())
    }

    public func decrypt(ciphertext: String) throws -> String {
        return try RowndEncryption.decrypt(ciphertext: ciphertext, withKeyId: try getKeyId())
    }

    // MARK: User module internal methods
    internal func getKeyId() throws -> String {
        return try getKeyId(user: store.state.user)
    }

    internal func getKeyId(user: UserState) throws -> String {
        let userId: String? = user.get(field: "user_id")

        guard let userId = userId else {
            throw RowndError("An encryption key was requested, but the user has not been loaded yet. Are you signed in?")
        }

        return userId
    }

    internal func ensureEncryptionKey(user: UserState) -> String? {
        do {
            let keyId = try getKeyId(user: user)

            let key = RowndEncryption.loadKey(keyId: keyId)

            guard let _ = key else {
                let key = RowndEncryption.generateKey()
                RowndEncryption.storeKey(key: key, keyId: keyId)
                return keyId
            }

            return keyId
        } catch {
            logger.error("Failed to ensure that an encryption key exists: \(String(describing: error))")
            return nil
        }
    }
}

public enum RowndStateType {
    case auth, user, app, none
}

public enum UserFieldAccessType {
    case string, int, float, dictionary, array
}

public enum RowndSignInHint {
      case appleId
}

public struct RowndSignInOptions: Encodable {
    public init(postSignInRedirect: String? = Rownd.config.postSignInRedirect) {
        self.postSignInRedirect = postSignInRedirect
    }
    
    public var postSignInRedirect: String? = Rownd.config.postSignInRedirect
    
    enum CodingKeys: String, CodingKey {
        case postSignInRedirect = "post_login_redirect"
    }
}

struct RowndError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
