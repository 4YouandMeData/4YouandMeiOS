//
//  UserDataViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift
import WebKit
import JJFloatingActionButton

enum ScriptMessage: String {
    case chartPointTapped
    case chartFullScreenTapped
    case shareChart
}

class UserDataViewController: BaseViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    private var pendingFabAction: FabAction?
    private var pendingDiaryNoteItem: DiaryNoteItem?
    
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
        userContentController.add(self, name: "shareChart")
        
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
        let messages = self.cacheService.infoMessages?.messages(withLocation: .tabUserData)
        return messages ?? []
    }()
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("UserDataViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setFabHidden(true)
        self.floatingButton.delegate = self
        
        self.fabActionHandler = { [weak self] action in
            guard let self = self, let diaryNote = self.pendingDiaryNoteItem else { return }

            switch action {
            case .insulin:
                self.navigator.openMyDosesViewController(presenter: self, diaryNote: diaryNote)
            case .noticed:
                self.navigator.openNoticedViewController(presenter: self, diaryNote: diaryNote)
            case .eaten:
                self.navigator.openEatenViewController(presenter: self, diaryNote: diaryNote)
            }

            // Reset after action
            self.pendingDiaryNoteItem = nil
            self.setFabHidden(true)
        }

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
        guard let baseURL = URL(string: Constants.Network.YourDataUrlStr) else {
            assertionFailure("Cannot retrieve url from given string: \(Constants.Network.YourDataUrlStr)")
            self.navigator.handleError(error: nil, presenter: self)
            return
        }
        
        // Add dark_mode query param
        let url = self.urlBySettingDarkModeParam(baseURL)
        
        guard let domain = url.host else {
            assertionFailure("Cannot retrieve domain from given url: \(url.absoluteString)")
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
            
        case .shareChart:
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
        let urlString = body["url"] as? String ?? "https://www.google.com"

        guard let url = URL(string: urlString) else {
            assertionFailure("URL invalido: \(urlString)")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        
        if let nav = self.presentedViewController as? UINavigationController,
           let webVC = nav.viewControllers.first(where: { $0 is WebViewViewController }) as? WebViewViewController {
            webVC.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    private func handleFullScreenTap(body: [String: Any]) {
        guard let chartId = body["chartId"] as? NSNumber else { return }
        let query = body["queryString"] as? String
        
        // Base = page URL + chartId; extra query = payload
        guard let baseURL = URL(string: Constants.Network.CharPageUrlStr + chartId.stringValue) else {
            assertionFailure("Invalid base URL")
            return
        }
        
        let finalURL = buildURL(base: baseURL, mergingQueryString: query)
        
        navigator.openWebView(
            withTitle: "",
            url: finalURL,
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
        
        self.pendingDiaryNoteItem = diaryNote
        
//        // Present the diary note screen, flagging that it originated from a chart tap
//        navigator.presentDiaryNotes(
//            diaryNote: diaryNote,
//            presenter: self,
//            isFromChart: true,
//            animated: animated
//        )
        self.setFabHidden(false)
        self.floatingButton.open()
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

// MARK: - JJFloatingActionButtonDelegate
extension UserDataViewController: JJFloatingActionButtonDelegate {

    // Called when the menu finished closing
    func floatingActionButtonDidClose(_ actionButton: JJFloatingActionButton) {
        self.setFabHidden(true)
    }
}

// MARK: - Dark Mode URL helper
private extension UserDataViewController {
    /// Returns true if current trait is dark
    var isDarkModeActive: Bool {
        // NOTE: use current view's trait collection
        return self.traitCollection.userInterfaceStyle == .dark
    }
    
    /// Adds or updates `dark_mode=true|false` in the given URL.
    /// - Important: preserves existing query items.
    func urlBySettingDarkModeParam(_ url: URL) -> URL {
        // Build components safely
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = comps.queryItems ?? []
        // Remove any existing `dark_mode` before appending the fresh value
        items.removeAll { $0.name == "dark_mode" }
        items.append(URLQueryItem(name: "dark_mode", value: isDarkModeActive ? "true" : "false"))
        comps.queryItems = items
        return comps.url ?? url
    }
    
    /// Merges an arbitrary `queryString` (possibly starting with '?') into a base URL
    /// and also sets the `dark_mode` param.
    func buildURL(base baseURL: URL, mergingQueryString queryString: String?) -> URL {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return baseURL }
        
        // Start from existing items (if any)
        var items = comps.queryItems ?? []
        
        // Parse and merge extra query coming from JS payload (e.g. "?interval=day&foo=bar")
        if let qs = queryString, !qs.isEmpty {
            // Strip leading '?'
            var tmp = URLComponents()
            tmp.query = qs.hasPrefix("?") ? String(qs.dropFirst()) : qs
            if let extra = tmp.queryItems {
                items.append(contentsOf: extra)
            }
        }
        
        // Remove duplicates by name keeping the last occurrence
        var dedup: [String: URLQueryItem] = [:]
        for it in items { dedup[it.name] = it }
        items = Array(dedup.values)
        
        // Set dark_mode
        items.removeAll { $0.name == "dark_mode" }
        items.append(URLQueryItem(name: "dark_mode", value: isDarkModeActive ? "true" : "false"))
        
        comps.queryItems = items
        return comps.url ?? baseURL
    }
}
