//
//  WebViewViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import WebKit

class WebViewViewController: UIViewController {
    
    private let webView: WKWebView
    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.progressTintColor = ColorPalette.color(withType: .primary)
        return view
    }()
    
    private let allowNavigation: Bool
    private let url: URL?
    private let htmlString: String?
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    
    private var progressObserver: NSKeyValueObservation?
    
    convenience init(withTitle title: String, allowNavigation: Bool, url: URL) {
        self.init(withTitle: title,
                  allowNavigation: allowNavigation,
                  url: url,
                  htmlString: nil,
                  webViewConfiguration: WKWebViewConfiguration())
    }
    
    convenience init(withTitle title: String, allowNavigation: Bool, htmlString: String) {
        self.init(withTitle: title,
                  allowNavigation: allowNavigation,
                  url: nil,
                  htmlString: htmlString,
                  webViewConfiguration: WKWebViewConfiguration())
    }
    
    init(withTitle title: String,
         allowNavigation: Bool,
         url: URL?,
         htmlString: String?,
         webViewConfiguration: WKWebViewConfiguration) {
        self.webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        self.allowNavigation = allowNavigation
        self.url = url
        self.htmlString = htmlString
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
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
        
        // Progress bar
        self.view.addSubview(self.progressView)
        self.progressView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .bottom)
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
        
        if let url = self.url {
            self.webView.load(URLRequest(url: url))
        } else if let htmlString = self.htmlString {
            self.webView.loadHTMLString(htmlString, baseURL: nil)
        }
        
        self.progressObserver = self.webView.observe(\WKWebView.estimatedProgress, changeHandler: { [weak self] _, _ in
            guard let self = self else { return }
            self.progressView.progress = Float(self.webView.estimatedProgress)
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.browser.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomCloseButton()
    }
    
    // MARK: - Actions
    
    @objc private func backButtonPressed(_ sender: Any?) {
        if self.webView.canGoBack {
            self.webView.goBack()
        } else {
            self.navigationController?.popViewController(animated: true)
        }
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

extension WebViewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.hideProgressView()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.showProgressView()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebViewViewController - Navigation did fail with error: \(error.localizedDescription)")
        self.handleNavigationError(error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebViewViewController - Navigation did fail provisional navigation with error: \(error.localizedDescription)")
        self.handleNavigationError(error: error)
    }
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if self.allowNavigation || navigationAction.request.url == self.url {
            decisionHandler(WKNavigationActionPolicy.allow)
        } else {
            decisionHandler(WKNavigationActionPolicy.cancel)
        }
    }
}
