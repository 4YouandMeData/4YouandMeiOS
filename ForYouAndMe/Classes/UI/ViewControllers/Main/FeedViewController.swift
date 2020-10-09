//
//  FeedViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift

class FeedViewController: UIViewController {
    
    private lazy var listManager: FeedListManager = {
        return FeedListManager(repository: self.repository,
                                    navigator: self.navigator,
                                    tableView: self.tableView,
                                    delegate: self,
                                    pullToRefresh: true)
    }()
    
    private lazy var headerView: FeedHeaderView = {
        let view = FeedHeaderView(profileButtonPressed: { [weak self] in
            self?.showProfile()
        })
        view.setTitleText("")
        view.setSubtitleText("")
        return view
    }()
    
    private lazy var tableViewHeaderView: FeedTableViewHeader = {
        let view = FeedTableViewHeader()
        view.setPoints(0)
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
    
    private let disposeBag = DisposeBag()
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabFeed)))
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.feed.rawValue,
                                                         screenClass: String(describing: type(of: self))))

        self.listManager.viewWillAppear()
        
        self.repository.refreshUser()
            .toVoid()
            .catchErrorJustReturn(())
            .subscribe(onSuccess: { _ in
                guard let user = self.repository.currentUser else {
                    assertionFailure("Missing current user")
                    return
                }
                self.headerView.setTitleText(user.feedTitle)
                self.headerView.setSubtitleText(user.feedSubtitle)
                self.tableViewHeaderView.setPoints(user.points)
            }, onError: { error in
                print("FeedViewController - Error refreshing user: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.listManager.viewDidLayoutSubviews()
    }
    
    // MARK: - Private Methods
    
    private func showProfile() {
        self.navigator.showAboutYouPage(presenter: self)
    }
}

extension FeedViewController: FeedListManagerDelegate {
    
    var presenter: UIViewController { self }
    
    func handleEmptyList(show: Bool) {
        self.tableView.backgroundView = show ? self.emptyView : nil
    }
    
    func getDataProviderSingle(repository: Repository) -> Single<FeedContent> {
        return self.repository.getFeeds().map { FeedContent(withFeeds: $0) }
    }
}
