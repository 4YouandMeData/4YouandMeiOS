//
//  UserDataViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift
import WebKit

class UserDataViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    // MARK: - AttributedTextStyles
    
    private let titleLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                    colorType: .primaryText,
                                                                    textAlignment: .left)
    private let subtitleLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .paragraph,
                                                                       colorType: .primaryText,
                                                                       textAlignment: .left)
    
    private lazy var webView: WKWebView = {
        // Configura la WKWebView per supportare i messaggi JavaScript
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "chartPointTapped")
        userContentController.add(self, name: "chartFullScreenTapped")
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        return webView
    }()

    // Stored so they can be used by the filter page
    private let navigator: AppNavigator
    private let repository: Repository
    private let storage: CacheService
    private let analytics: AnalyticsService
    
    private let disposeBag = DisposeBag()
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("UserDataViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .fourth)
        
        // Header View
        let headerView = SingleTextHeaderView()
        headerView.setTitleText(StringsProvider.string(forKey: .tabUserDataTitle))
        
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        // Content (webview)
        self.view.addSubview(self.webView)
        self.webView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.webView.autoPinEdge(.top, to: .bottom, of: headerView)
        self.webView.navigationDelegate = self
        self.webView.scrollView.isScrollEnabled = true
        self.loadWebViewWithSessionToken()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabUserData)))
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.yourData.rawValue,
                                                  screenClass: String(describing: type(of: self))))
    }
    
    // MARK: WebView Methods
    
    private func loadWebViewWithSessionToken() {
        
        guard let url = URL(string: Constants.Network.YourDataUrlStr) else {
            assertionFailure("Cannot retrieve url from given string: \(Constants.Network.YourDataUrlStr)")
            self.navigator.handleError(error: nil, presenter: self)
            return
        }
        
        guard let domain = url.host else {
            assertionFailure("Cannot retrieve domain from given url: \(Constants.Network.YourDataUrlStr)")
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
            .secure: "TRUE",
            .expires: Date(timeIntervalSinceNow: 31556926)
        ]
        
        guard let authenticationCookie = HTTPCookie(properties: httpCookieProperties) else {
            assertionFailure("Couldn't create authentication cookie")
            self.navigator.handleError(error: nil, presenter: self)
            return
        }

        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = true
        self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(authenticationCookie, completionHandler: { [weak self] in
            guard let self = self else { return }
            print("ReactiveAuthWebViewController - Authentication cookie setup done")
            self.webView.load(request)
        })
    }
    
    // Nel metodo webView(_:didFinish:)
   func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
       // Inietta il listener JavaScript dopo il caricamento
//       injectChartEventListener()
   }
    
//    // Metodo per iniettare il listener JavaScript
//    private func injectChartEventListener() {
//        let script = """
//        document.addEventListener('chartPointTapped', function(event) {
//            window.webkit.messageHandlers.chartPointTapped.postMessage({
//                dataPointID: event.detail.dataPointID,
//            });
//            window.webkit.messageHandlers.chartPointTapped.postMessage({
//                dataPointID: event.detail.dataPointID,
//            });
//        });
//        """
//        
//        webView.evaluateJavaScript(script, completionHandler: nil)
//    }
    
    // Implementazione del WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "chartPointTapped",
           let body = message.body as? [String: Any] {
            handleChartPointTap(eventData: body)
        }
        if message.name == "chartFullScreenTapped",
           let body = message.body as? [String: Any] {
            print(body)
        }
    }
    
    // Metodo per gestire l'evento di tap sul punto del grafico
    private func handleChartPointTap(eventData: [String: Any]) {
//        guard let dataPoint = eventData["dataPoint"] as? String else {
//            return
//        }
//        print("Datapoint: \(dataPoint)")
        self.navigator.presentDiaryNotes(dataPointId: nil, presenter: self)
    }
}
