//
//  WearableLoginViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 09/07/2020.
//

import Foundation
import WebKit

class WearableLoginViewController: UIViewController {
    
    private enum WearableLoginResult: String {
        case success
        case failure
    }
    
    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.progressTintColor = ColorPalette.color(withType: .primary)
        return view
    }()
    
    private let webView: WKWebView
    private let url: URL
    private let onLoginSuccessCallback: ViewControllerCallback
    private let onLoginFailureCallback: ViewControllerCallback
    private let navigator: AppNavigator
    private let repository: Repository
    
    private var progressObserver: NSKeyValueObservation?
    
    init(withTitle title: String,
         url: URL,
         onLoginSuccessCallback: @escaping ViewControllerCallback,
         onLoginFailureCallback: @escaping ViewControllerCallback) {
        self.webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        self.url = url
        self.onLoginSuccessCallback = onLoginSuccessCallback
        self.onLoginFailureCallback = onLoginFailureCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Content (webview)
        self.view.addSubview(self.webView)
        self.webView.autoPinEdgesToSuperviewSafeArea()
        self.webView.navigationDelegate = self
        self.webView.configuration.userContentController.add(self, name: "wearableLogin")
        
        // Progress bar
        self.view.addSubview(self.progressView)
        self.progressView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        self.progressView.autoSetDimension(.height, toSize: 2.0)
        
        // Shadow
        let shadowView = UIView()
        shadowView.autoSetDimension(.height, toSize: 1.0)
        self.view.addSubview(shadowView)
        shadowView.autoPinEdge(toSuperviewSafeArea: .leading)
        shadowView.autoPinEdge(toSuperviewSafeArea: .trailing)
        shadowView.backgroundColor = ColorPalette.color(withType: .secondary)
        shadowView.autoPinEdge(toSuperviewSafeArea: .top, withInset: -1.0)
        shadowView.addShadowLinear(goingDown: true)
        
        self.progressObserver = self.webView.observe(\WKWebView.estimatedProgress, changeHandler: { [weak self] _, _ in
            guard let self = self else { return }
            self.progressView.progress = Float(self.webView.estimatedProgress)
        })
        
        guard let domain = self.url.host else {
            assertionFailure("Cannot retrieve domain from given url: \(self.url)")
            self.navigator.handleError(error: nil, presenter: self)
            return
        }
        
        guard let accessToken = self.repository.accessToken else {
            assertionFailure("Cannot retrieve access token")
            self.navigator.handleError(error: RepositoryError.userNotLoggedIn, presenter: self)
            return
        }
        
        let httpCookieProperties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .path: "/",
            .name: "token",
            .value: "Bearer \(accessToken)",
            .secure: "TRUE"
        ]
        
        guard let authenticationCookie = HTTPCookie(properties: httpCookieProperties) else {
            assertionFailure("Couldn't create authentication cookie")
            self.navigator.handleError(error: nil, presenter: self)
            return
        }

        var request = URLRequest(url: self.url)
        request.httpShouldHandleCookies = true
        self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(authenticationCookie, completionHandler: { [weak self] in
            guard let self = self else { return }
            print("WearableLoginViewController - Authentication cookie setup done")
            self.webView.load(request)
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)
        self.addCustomCloseButton()
    }
    
    // MARK: - Private Methods
    
    private func showProgressView() {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
            guard let self = self else { return }
            self.progressView.alpha = 1
        }, completion: nil)
    }
    
    private func hideProgressView() {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
            guard let self = self else { return }
            self.progressView.alpha = 0
        }, completion: nil)
    }
    
    private func handleNavigationError(error: Error) {
        self.hideProgressView()
        let error = error as NSError
        switch error.code {
        case -1009: self.navigator.handleError(error: RepositoryError.connectivityError, presenter: self)
        default: self.navigator.handleError(error: nil, presenter: self)
        }
    }
}

extension WearableLoginViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.hideProgressView()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.showProgressView()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WearableLoginViewController - Navigation did fail with error: \(error.localizedDescription)")
        self.handleNavigationError(error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WearableLoginViewController - Navigation did fail provisional navigation with error: \(error.localizedDescription)")
        self.handleNavigationError(error: error)
    }
}

extension WearableLoginViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let result = WearableLoginResult(rawValue: message.name) else {
            print("WearableLoginViewController - Unhandled message: \(message)")
            return
        }
        switch result {
        case .success: self.onLoginSuccessCallback(self)
        case .failure: self.onLoginFailureCallback(self)
        }
    }
}
