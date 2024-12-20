//
//  TaskViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift

class TaskViewController: UIViewController {
    
    private lazy var listManager: FeedListManager = {
        return FeedListManager(repository: self.repository,
                                    navigator: self.navigator,
                                    tableView: self.tableView,
                                    delegate: self,
                                    pageSize: Constants.Misc.TaskPageSize,
                                    pullToRefresh: true)
    }()
    
    private lazy var emptyView: TaskEmptyView = {
        let view = TaskEmptyView(buttonCallback: { [weak self] in
            guard let self = self else { return }
            self.navigator.switchToFeedTab(presenter: self)
        })
        return view
    }()
    
    private lazy var comingSoonButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.messages.style)
        button.setTitle(MessageMap.getMessageContent(byKey: "task")?.title, for: .normal)
        button.addTarget(self, action: #selector(self.comingSoonButtonPressed), for: .touchUpInside)
        button.autoSetDimension(.width, toSize: 110)
        return button
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView()
        
        // Needed to get rid of the top inset when using grouped style
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: CGFloat.leastNormalMagnitude))
        tableView.contentInsetAdjustmentBehavior = .never
        
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        tableView.contentInset = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        
        return tableView
    }()
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("TaskViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = SingleTextHeaderView()
        headerView.setTitleText(StringsProvider.string(forKey: .tabTaskTitle))
        
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.tableView.autoPinEdge(.top, to: .bottom, of: headerView)
        
        self.view.addSubview(self.emptyView)
        self.emptyView.autoPinEdge(to: self.tableView)
        self.emptyView.isHidden = true
        
        headerView.addSubview(self.comingSoonButton)
        self.comingSoonButton.autoPinEdge(.bottom, to: .bottom, of: headerView, withOffset: -20.0)
        self.comingSoonButton.autoPinEdge(.trailing, to: .trailing, of: headerView, withOffset: -12.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabTask)))
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.task.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        
        self.listManager.viewWillAppear()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.listManager.viewDidLayoutSubviews()
    }
    
    @objc private func comingSoonButtonPressed() {
        guard let message = MessageMap.getMessageContent(byKey: "task") else {return}
        self.navigator.openMessagePage(withTitle: message.title, body: message.body, presenter: self)
    }
}

extension TaskViewController: FeedListManagerDelegate {
    
    var presenter: UIViewController { self }
    
    func handleEmptyList(show: Bool) {
        self.emptyView.isHidden = !show
    }
    
    func getDataProviderSingle(repository: Repository, fetchMode: FetchMode) -> Single<FeedContent> {
        return self.repository.getTasks(fetchMode: fetchMode).map { FeedContent(withFeeds: $0) }
    }
    
    func showError(error: Error) {
        self.navigator.handleError(error: error, presenter: self)
    }
}
