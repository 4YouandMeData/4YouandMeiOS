//
//  UserDataViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift
import WebKit

enum ScriptMessage: String {
    case chartPointTapped
    case chartFullScreenTapped
    case chartShareTapped
}

class UserDataViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    private var pendingFabAction: FabAction?
    
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
        button.setTitle(self.messages.first?.title, for: .normal)
        button.addTarget(self, action: #selector(self.comingSoonButtonPressed), for: .touchUpInside)
        button.autoSetDimension(.width, toSize: 110)
        button.isHidden = (self.messages.count < 1)
        return button
    }()
    
    private lazy var messages: [MessageInfo] = {
        let messages = self.storage.infoMessages?.messages(withLocation: .tabUserData)
        return messages ?? []
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
        self.navigator.openMessagePage(withLocation: .tabUserData, presenter: self)
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
    
    // WKScriptMessageHandler implementation
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let msg = ScriptMessage(rawValue: message.name),
              let body = message.body as? [String: Any] else {
            return
        }

        switch msg {
        case .chartPointTapped:
        if let nav = self.presentedViewController as? UINavigationController,
           let webVC = nav.viewControllers.first(where: { $0 is WebViewViewController }) as? WebViewViewController {
            webVC.showFabIfNeeded()
            webVC.onFabActionSelected = { [weak self] action in
                guard let self = self else { return }
                self.pendingFabAction = action
                self.dismissRotateAndPresent(eventData: body)
            }
        } else {
            dismissRotateAndPresent(eventData: body)
        }

        case .chartFullScreenTapped:
            handleFullScreenTap(body: body)
            
        case .chartShareTapped:
            handleSharingTap(body: body)
        }
    }
    
    // Dismiss the current view, rotate back to portrait, then present diary note
    private func dismissRotateAndPresent(eventData: [String: Any]) {

        let afterDismiss = {
            OrientationManager.resetToDefaultWithCompletion {
                if let action = self.pendingFabAction {
                    self.pendingFabAction = nil
                    switch action {
                    case .insulin:
                        self.navigator.openMyDosesViewController(presenter: self)
                    case .noticed:
                        self.navigator.openNoticedViewController(presenter: self)
                    case .eaten:
                        self.navigator.openEatenViewController(presenter: self)
                    }
                } else {
                    self.handleChartPointTap(eventData: eventData, animated: true)
                }
            }
        }

        if let nav = self.navigationController {
            nav.dismiss(animated: true, completion: afterDismiss)
        } else {
            self.dismiss(animated: true, completion: afterDismiss)
        }
    }
    
    private func handleSharingTap(body: [String: Any]) {
        let urlString = body["shareUrl"] as? String ?? "https://www.google.com"

        guard let url = URL(string: urlString) else {
            assertionFailure("URL invalido: \(urlString)")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view

        self.present(activityViewController, animated: true, completion: nil)
        
    }
    
    private func handleFullScreenTap(body: [String: Any]) {
        guard let chartId = body["chartId"] as? NSNumber else { return }
        let query = body["queryString"] as? String ?? ""
        let urlString = Constants.Network.CharPageUrlStr + chartId.stringValue + query

        guard let url = URL(string: urlString) else {
            assertionFailure("URL invalido: \(urlString)")
            return
        }

        navigator.openWebView(
            withTitle: "",
            url: url,
            presenter: self,
            configuration: webView.configuration
        )
        OrientationManager.lockOrientation(.landscape)
    }
    
    // MARK: - Chart Point Tap Handler

    /// Processes a tap on a chart point by extracting the necessary data
    /// and presenting the corresponding diary note screen.
    /// - Parameter eventData: A dictionary containing the tap event payload.
    private func handleChartPointTap(eventData: [String: Any], animated: Bool) {
        // Extract all required fields in a single guard to fail early if any are missing or of wrong type
        guard
            let dataPoint      = eventData["datetime_ref"]        as? String,
            let interval       = eventData["interval"]            as? String,
            let noteableType   = eventData["diary_noteable_type"] as? String,
            let noteableId     = eventData["diary_noteable_id"]   as? String
        else {
            // If any value is unavailable, abort handling
            return
        }

        // Build the DiaryNoteable model
        let diaryNoteable = DiaryNoteable(
            id: noteableId,
            type: noteableType
        )

        // Construct the DiaryNoteItem representing the tapped point
        let diaryNote = DiaryNoteItem(
            diaryNoteId: dataPoint,
            body: "",             // Body is empty for chart-initiated notes
            interval: interval,
            diaryNoteable: diaryNoteable
        )

        // Present the diary note screen, flagging that it originated from a chart tap
        navigator.presentDiaryNotes(
            diaryNote: diaryNote,
            presenter: self,
            isFromChart: true,
            animated: animated
        )
    }
}

extension UIViewController {
    func presentedViewController<T: UIViewController>(ofType type: T.Type) -> T? {
        var presented = self.presentedViewController
        while let current = presented {
            if let match = current as? T {
                return match
            }
            presented = current.presentedViewController
        }
        return nil
    }
}
