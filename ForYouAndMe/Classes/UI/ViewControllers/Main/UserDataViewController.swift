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
    
    private lazy var comingSoonButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.messages.style)
        button.setTitle(MessageMap.getMessageContent(byKey: "user_data")?.title, for: .normal)
        button.addTarget(self, action: #selector(self.comingSoonButtonPressed), for: .touchUpInside)
        button.autoSetDimension(.width, toSize: 110)
        return button
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
        
        headerView.addSubview(self.comingSoonButton)
        self.comingSoonButton.autoPinEdge(.bottom, to: .bottom, of: headerView, withOffset: -20.0)
        self.comingSoonButton.autoPinEdge(.trailing, to: .trailing, of: headerView, withOffset: -12.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabUserData)))
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.yourData.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.webView.reload()
    }
    
    // MARK: Actions
    
    @objc private func comingSoonButtonPressed() {
        guard let message = MessageMap.getMessageContent(byKey: "user_data") else { return }
        self.navigator.openMessagePage(withTitle: message.title, body: message.body, presenter: self)
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
//       self.webView.evaluateJavaScript("document.body.innerHTML", completionHandler: { (value: Any!, error: Error!) -> Void in
//           if error != nil {
//               //Error logic
//               return
//           }
//
//           let result = value as? String
//           print(result)
//       })

   }
    
    // Implementazione del WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "chartPointTapped",
           let body = message.body as? [String: Any] {
            handleChartPointTap(eventData: body)
        }
        if message.name == "chartFullScreenTapped",
           let body = message.body as? [String: Any] {
            guard let chartId = body["chartId"] as? NSNumber else {return}
            let chartUrl = Constants.Network.CharPageUrlStr + chartId.stringValue
            self.navigator.openWebView(withTitle: "", url: URL(string: chartUrl)!, presenter: self)
            OrientationManager.lockOrientation(.landscape)
        }
    }
    
    // Metodo per gestire l'evento di tap sul punto del grafico
    private func handleChartPointTap(eventData: [String: Any]) {
        guard let dataPoint = eventData["datetime_ref"] as? String else {
            return
        }
        guard let interval = eventData["interval"] as? String else {
            return
        }
        guard let diaryNoteableType = eventData["diary_noteable_type"] as? String else {
            return
        }
        guard let diaryNoteableId = eventData["diary_noteable_id"] as? String else {
            return
        }
        
        let diaryNoteable = DiaryNoteable(id: diaryNoteableId,
                                          type: diaryNoteableType)
        
        let diaryNote = DiaryNoteItem(diaryNoteId: dataPoint,
                                      body: "",
                                      interval: interval,
                                      diaryNoteable: diaryNoteable)
        
        self.navigator.presentDiaryNotes(diaryNote: diaryNote, presenter: self, isFromChart: true)
    }
}
