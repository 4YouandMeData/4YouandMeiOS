//
//  FeedViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift
import JJFloatingActionButton

class FeedViewController: UIViewController {
    
    private lazy var listManager: FeedListManager = {
        return FeedListManager(repository: self.repository,
                               navigator: self.navigator,
                               tableView: self.tableView,
                               delegate: self,
                               pageSize: Constants.Misc.FeedPageSize,
                               pullToRefresh: true)
    }()
    
    private lazy var headerView: FeedHeaderView = {
        let view = FeedHeaderView(profileButtonPressed: { [weak self] in
            self?.showProfile()
        }, comingSoonButtonPressed: { [weak self] in
            self?.showMessage()
        })
        view.setTitleText("")
        view.setSubtitleText("")
        return view
    }()
    
    private lazy var tableViewHeaderView: FeedTableViewHeader = {
        let view = FeedTableViewHeader()
        view.setPoints(0)
        view.refreshUI()
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView()
        
        tableView.tableHeaderView = self.tableViewHeaderView
        tableView.contentInsetAdjustmentBehavior = .never
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        return tableView
    }()
    
    private lazy var emptyView = FeedEmptyView(withTopOffset: FeedTableViewHeader.height)
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private let deeplinkService: DeeplinkService
    
    private let disposeBag = DisposeBag()
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        self.deeplinkService = Services.shared.deeplinkService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("FeedViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: Handle secondary color background when pull to refresh (should be primary gradient)
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        self.view.addSubview(self.headerView)
        self.headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.tableView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        
        let actionButton = JJFloatingActionButton()
        let actionItemRiflection = actionButton.addItem()
        actionItemRiflection.titleLabel.text = "Start a reflection"
        actionItemRiflection.imageView.image = ImagePalette.image(withName: .riflectionIcon)
        actionItemRiflection.buttonColor = ColorPalette.color(withType: .inactive)
        
        let actionNoticed = actionButton.addItem()
        actionNoticed.titleLabel.text = "I Have Noticed"
        actionNoticed.imageView.image = ImagePalette.image(withName: .noteGeneric)
        actionNoticed.buttonColor = ColorPalette.color(withType: .primary)
        actionNoticed.action = { [weak self] _ in
            guard let self = self else { return }
            self.navigator.openNoticedViewController(presenter: self)
        }

        view.addSubview(actionButton)
        actionButton.display(inViewController: self)
        actionButton.buttonColor = ColorPalette.color(withType: .primary)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.headerView.refreshUI()
        self.tableViewHeaderView.refreshUI()
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabFeed)))
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.feed.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        
        self.listManager.viewWillAppear()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.listManager.viewDidLayoutSubviews()
    }
    
    // MARK: - Private Methods
    
    private func showProfile() {
        self.navigator.showAboutYouPage(presenter: self)
    }
    
    private func showMessage() {
        guard let message = MessageMap.getMessageContent(byKey: "feed") else {return}
        self.navigator.openMessagePage(withTitle: message.title, body: message.body, presenter: self)
    }
    
    private func refreshUser() {
        self.repository.refreshUser()
            .toVoid()
            .catchErrorJustReturn(())
            .subscribe(onSuccess: { _ in
                guard let user = self.repository.currentUser else {
                    assertionFailure("Missing current user")
                    return
                }
                self.headerView.setTitleText(user.getFeedTitle(repository: self.repository))
                self.headerView.setSubtitleText(user.getFeedSubtitle(repository: self.repository))
                self.tableViewHeaderView.setPoints(user.points)
                self.tableViewHeaderView.refreshUI()
            }, onError: { error in
                print("FeedViewController - Error refreshing user: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
}

extension FeedViewController: FeedListManagerDelegate {
    
    var presenter: UIViewController { self }
    
    func handleEmptyList(show: Bool) {
        self.tableView.backgroundView = show ? self.emptyView : nil
    }
    
    func getDataProviderSingle(repository: Repository, fetchMode: FetchMode) -> Single<FeedContent> {
        return self.repository.getFeeds(fetchMode: fetchMode).map { FeedContent(withFeeds: $0) }
    }
    
    func onListRefresh() {
        self.refreshUser()
        self.navigator.checkForNotificationPermission(presenter: self)
        self.handleDeeplinks(deeplinkService: self.deeplinkService,
                             navigator: self.navigator,
                             repository: self.repository,
                             disposeBag: self.disposeBag)
    }
    
    func showError(error: Error) {
        self.navigator.handleError(error: error, presenter: self)
    }
}
