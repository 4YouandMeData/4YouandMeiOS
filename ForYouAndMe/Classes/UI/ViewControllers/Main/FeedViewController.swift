//
//  FeedViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift
import JJFloatingActionButton

class FeedViewController: BaseViewController {
    
    private lazy var listManager: FeedListManager = {
        return FeedListManager(repository: self.repository,
                               navigator: self.navigator,
                               tableView: self.tableView,
                               delegate: self,
                               pageSize: Constants.Misc.FeedPageSize,
                               pullToRefresh: true,
                               isInfiniteScrollEnabled: true,
                               forceSabaFooterForTesting: true)
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
    
    override init() {
        super.init()
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
        
        self.checkForWalkThrough()
        self.checkForHealthPermission()
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
        self.getInfoMessages()
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
        self.navigator.openMessagePage(withLocation: .tabFeed, presenter: self)
    }
    
    private func getInfoMessages() {
        self.repository.getInfoMessages()
                        .subscribe(onSuccess: { [weak self] infoMessages in
                            guard let self = self else { return }
                            self.cacheService.infoMessages = infoMessages
                            if let infoMessage = infoMessages.firstMessage(withLocation: .tabFeed) {
                                self.headerView.setComingSoonTitle(title: infoMessage.buttonText ?? "Coming Soon")
                            } else {
                                self.headerView.showComingSoonButton(show: false)
                            }
                        }, onFailure: { [weak self] error in
                            guard let self = self else { return }
                            self.navigator.handleError(error: error, presenter: self)
                        }).disposed(by: self.disposeBag)
    }
    
    private func refreshUser() {
        self.repository.refreshUser()
            .toVoid()
            .catchAndReturn(())
            .subscribe(onSuccess: { _ in
                guard let user = self.repository.currentUser else {
                    assertionFailure("Missing current user")
                    return
                }
                self.headerView.setTitleText(user.getFeedTitle(repository: self.repository))
                self.headerView.setSubtitleText(user.getFeedSubtitle(repository: self.repository))
                self.tableViewHeaderView.setPoints(user.points)
                self.tableViewHeaderView.refreshUI()
            }, onFailure: { error in
                print("FeedViewController - Error refreshing user: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
    
    private func checkForHealthPermission() {
    #if HEALTHKIT
        if IntegrationProvider.oAuthIntegrations().contains(.terra) {
            Services.shared.terraService
                .initialize()
                .flatMap {
                    Services.shared.terraService.connectToTerraIfAvailable()
                }
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: {}, onFailure: { _ in})
                .disposed(by: disposeBag)
        }
        
    #endif
    }
    
    private func checkForWalkThrough() {
        guard let user = self.repository.currentUser else {
            assertionFailure("Missing current user")
            return
        }
        
        let walkThrough = user.studyWalkthroughDone
        if !walkThrough {
            self.repository.getStudyInfoSection().subscribe(onSuccess: { [weak self] infoSection in
                guard let self = self else { return }
                self.navigator.showWalkThrough(presenter: self,
                                               studyInfoSection: infoSection)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
        }
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
