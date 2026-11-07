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
    private var isSaba: Bool {
        return ProjectInfo.StudyId.lowercased() == "saba"
    }

    private var forceSabaForTesting: Bool {
        #if DEBUG
        return false
        #else
        return false
        #endif
    }

    private var effectiveIsSaba: Bool {
        return isSaba || forceSabaForTesting
    }

    private lazy var listManager: FeedListManager = {

        return FeedListManager(repository: self.repository,
                               navigator: self.navigator,
                               tableView: self.tableView,
                               delegate: self,
                               pageSize: Constants.Misc.FeedPageSize,
                               pullToRefresh: true,
                               isInfiniteScrollEnabled: true,
                               forceSabaFooterForTesting: self.forceSabaForTesting,
                               kpiWidgetStore: self.kpiWidgetStore)
    }()
    
    // FUAM-4315: KPI widgets, loaded once per local day independently of the feed (D2).
    private let kpiWidgetStore: KpiWidgetStore = Services.shared.kpiWidgetStore
    
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
        
        // Header View
        self.view.addSubview(self.headerView)
        self.headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.tableView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        
        self.checkForWalkThrough()
        self.checkForHealthPermission()
        
        // The KPI section re-renders whenever the store changes, without refetching the feed.
        self.kpiWidgetStore.state
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.listManager.updateKpiState(state)
            }).disposed(by: self.disposeBag)
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
        self.kpiWidgetStore.refreshIfNeeded()
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
                            // FUAM-4315 (D15): the KPI info icon reads the cache at render time.
                            // A plain reload: reloadItems() would refetch the feed and jump to the top.
                            self.tableView.reloadData()
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
                self.tableViewHeaderView.setPoints(user.points ?? 0)
                self.tableViewHeaderView.refreshUI()
            }, onFailure: { error in
                print("FeedViewController - Error refreshing user: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
    
    private func checkForHealthPermission() {
    #if TERRA
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
        // FUAM-2937: when the user's menstrual baseline is "no", suppress the
        // pinned menstrual feed card client-side. The BE trigger should already
        // skip it, but we guard here against any drift between settings and
        // the server's evaluation window.
        let feedsSingle = self.repository.getFeeds(fetchMode: fetchMode)
        let settingsSingle: Single<UserSettings?> = self.repository.getUserSettings()
            .map { Optional($0) }
            .catchAndReturn(nil)
        return Self.feedContentSingle(feeds: feedsSingle, settings: settingsSingle, kpiWidgetStore: self.kpiWidgetStore)
    }
    
    static func feedContentSingle(feeds feedsSingle: Single<[Feed]>,
                                  settings settingsSingle: Single<UserSettings?>,
                                  kpiWidgetStore: KpiWidgetStore) -> Single<FeedContent> {
        return Single.zip(feedsSingle, settingsSingle).map { feeds, settings in
            var processed = feeds
            if settings?.menstrualHadPeriod3Mo == .no {
                processed = processed.filter { feed in
                    guard case .alert(let alert) = feed.notifiable else { return true }
                    return !alert.isPinned
                }
            }
            // FUAM-4315: read the KPI state when the response arrives, so a slow feed cannot
            // overwrite a newer one.
            return FeedContent(withFeeds: processed, kpiState: kpiWidgetStore.state.value)
        }
    }
    
    func onListRefresh() {
        // Foreground, Quick Activity submission and every other feed reload: same-day no-op.
        self.kpiWidgetStore.refreshIfNeeded()
        self.refreshUser()
        self.navigator.checkForNotificationPermission(presenter: self)
        self.handleDeeplinks(deeplinkService: self.deeplinkService,
                             navigator: self.navigator,
                             repository: self.repository,
                             disposeBag: self.disposeBag)
    }
    
    func onPullToRefresh() {
        // An explicit user refresh always reloads the widgets (D2).
        self.kpiWidgetStore.refreshIfNeeded(force: true)
    }
    
    func isDailyInputsSurvey(_ survey: Survey) -> Bool {
        // Example strategies (pick the one that matches your model):
        // By exact title (case-insensitive)
//        if let title = survey.title?.lowercased(), title == "daily inputs" {
//            return true
//        }
        
        if Int(survey.id) == 25 {
            return true
        }

        // By tags/metadata if you have them
        // if survey.tags.contains("daily_inputs") { return true }

        return false
    }
    
    func showError(error: Error) {
        self.navigator.handleError(error: error, presenter: self)
    }
}
