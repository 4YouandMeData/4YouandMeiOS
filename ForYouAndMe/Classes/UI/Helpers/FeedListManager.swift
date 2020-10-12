//
//  FeedListManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit
import RxSwift

fileprivate extension Schedulable {
    var isQuickActivity: Bool {
        switch self {
        case .quickActivity: return true
        default: return false
        }
    }
}

struct FeedContent {
    let quickActivities: [Feed]
    let feedItems: [Feed]
    
    init(withFeeds feeds: [Feed]) {
        self.quickActivities = feeds.filter { $0.schedulable.isQuickActivity }
        self.feedItems = feeds.filter { false == $0.schedulable.isQuickActivity }
    }
}

protocol FeedListManagerDelegate: class {
    var presenter: UIViewController { get }
    func handleEmptyList(show: Bool)
    func getDataProviderSingle(repository: Repository) -> Single<FeedContent>
}

protocol FeedListSection {
    var numberOfRows: Int { get }
    var sectionText: String? { get }
}

private struct FeedSection: FeedListSection {
    let dateString: String
    let feedItems: [Feed]
    
    var numberOfRows: Int { self.feedItems.count }
    var sectionText: String? { self.dateString }
}

private struct QuickActivitySection: FeedListSection {
    let quickActivies: [QuickActivityItem]
    
    var numberOfRows: Int { 1 }
    var sectionText: String? { nil }
}

class FeedListManager: NSObject {
    private let tableView: UITableView
    private let repository: Repository
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private weak var delegate: FeedListManagerDelegate?
    
    private var sections: [FeedListSection] = []
    private var currentRequestDisposable: Disposable?
    
    private var quickActivitySelections: [QuickActivityItem: QuickActivityOption] = [:]
    
    private lazy var errorView: GenericErrorView = {
        return GenericErrorView(retryButtonCallback: { [weak self] in self?.refreshItems() })
    }()
    
    final let disposeBag: DisposeBag = DisposeBag()
    
    init(repository: Repository,
         navigator: AppNavigator,
         tableView: UITableView,
         delegate: FeedListManagerDelegate,
         pullToRefresh: Bool = true) {
        self.repository = repository
        self.navigator = navigator
        self.tableView = tableView
        self.analytics = Services.shared.analytics
        self.delegate = delegate
        
        super.init()
        
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.registerCellsWithClass(FeedTableViewCell.self)
        self.tableView.registerCellsWithClass(QuickActivityListTableViewCell.self)
        self.tableView.registerHeaderFooterViewWithClass(FeedListSectionHeader.self)
        self.tableView.tableFooterView = UIView()
        self.tableView.separatorStyle = .none
        self.tableView.estimatedRowHeight = 300.0
        
        // Pull to refresh
        if pullToRefresh {
            let refreshControl = UIRefreshControl()
            refreshControl.tintColor = ColorPalette.color(withType: .primary)
            refreshControl.addTarget(self, action: #selector(self.refreshControlPulled), for: .valueChanged)
            self.tableView.refreshControl = refreshControl
        }
        
        // Error View
        delegate.presenter.view.addSubview(self.errorView)
        self.errorView.autoPinEdge(.leading, to: .leading, of: self.tableView)
        self.errorView.autoPinEdge(.trailing, to: .trailing, of: self.tableView)
        self.errorView.autoPinEdge(.top, to: .top, of: self.tableView)
        self.errorView.autoPinEdge(.bottom, to: .bottom, of: self.tableView)
        self.errorView.isHidden = true
    }
    
    deinit {
        self.currentRequestDisposable?.dispose()
    }
    
    // MARK: - Public Methods
    
    public func refreshItems(onCompletion: NotificationCallback? = nil) {
        self.loadItems(onCompletion: onCompletion)
    }
    
    public func viewWillAppear() {
        self.loadItems()
    }
    
    public func viewDidLayoutSubviews() {
        self.tableView.reloadData()
        self.tableView.sizeHeaderToFit()
    }
    
    // MARK: - Private Methods
    
    private func loadItems(onCompletion: NotificationCallback? = nil) {
        
        guard let delegate = self.delegate else {
            assertionFailure("FeedListManager - Missing delegate")
            return
        }
        
        self.currentRequestDisposable?.dispose()
        self.navigator.pushProgressHUD()
        self.currentRequestDisposable = delegate.getDataProviderSingle(repository: self.repository)
            .do(onSuccess: { [weak self] _ in self?.navigator.popProgressHUD() },
                onError: { [weak self] _ in self?.navigator.popProgressHUD() },
                onDispose: { [weak self] in self?.navigator.popProgressHUD() })
            .subscribe(onSuccess: { [weak self] content in
                guard let self = self else { return }
                self.tableView.refreshControl?.endRefreshing()
                
                self.sections = content.sections
                self.reloadTableView()
                
                self.currentRequestDisposable = nil
                
                self.errorView.hideView()
                
                onCompletion?()
                
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.tableView.refreshControl?.endRefreshing()
                
                self.currentRequestDisposable = nil
                self.errorView.showViewWithError(error)
            })
    }
    
    private func reloadTableView() {
        let showEmptyView = self.sections.count == 0
        self.delegate?.handleEmptyList(show: showEmptyView)
        self.tableView.reloadData()
        self.tableView.sizeHeaderToFit()
        if showEmptyView {
            self.goToTop()
        }
    }
    
    private func goToTop() {
        self.tableView.contentOffset = .zero
        self.tableView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
    }
    
    private func sendQuickActiviyOption(_ option: QuickActivityOption, forTaskId taskId: String) {
        guard let delegate = self.delegate else {
            assertionFailure("FeedListManager - Missing delegate")
            return
        }
        
        self.navigator.pushProgressHUD()
        self.repository.sendQuickActivityResult(quickActivityTaskId: taskId,
                                                quickActivityOption: option)
            .do(onSuccess: { [weak self] _ in self?.navigator.popProgressHUD() },
                onError: { [weak self] _ in self?.navigator.popProgressHUD() },
                onDispose: { [weak self] in self?.navigator.popProgressHUD() })
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.analytics.track(event: .quickActivity(taskId, option: option.id))
                self.loadItems()
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: delegate.presenter)
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: - Actions
    
    @objc private func refreshControlPulled() {
        self.loadItems()
    }
}

extension FeedListManager: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].numberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = self.sections[indexPath.section]
        if let quickActivitySection = section as? QuickActivitySection {
            guard let cell = tableView.dequeueReusableCellOfType(type: QuickActivityListTableViewCell.self, forIndexPath: indexPath) else {
                assertionFailure("QuickActivityListTableViewCell not registered")
                return UITableViewCell()
            }
            cell.display(items: quickActivitySection.quickActivies,
                         selections: self.quickActivitySelections,
                         confirmCallback: { [weak self] item in
                            guard let self = self else { return }
                            guard let selectedOption = self.quickActivitySelections[item] else {
                                assertionFailure("Missing selected quick activity option")
                                return
                            }
                            self.sendQuickActiviyOption(selectedOption, forTaskId: item.taskId)
                         },
                         selectionCallback: { [weak self] (item, option) in
                            guard let self = self else { return }
                            self.quickActivitySelections[item] = option
                         })
            return cell
        } else if let feedSection = section as? FeedSection {
            let feed = feedSection.feedItems[indexPath.row]
            guard let cell = tableView.dequeueReusableCellOfType(type: FeedTableViewCell.self, forIndexPath: indexPath) else {
                assertionFailure("FeedTableViewCell not registered")
                return UITableViewCell()
            }
            switch feed.schedulable {
            case .quickActivity:
                assertionFailure("Unexpected quick activity as schedulable type")
            case .activity(let activity):
                cell.display(data: activity, buttonPressedCallback: { [weak self] in
                    guard let self = self else { return }
                    guard let delegate = self.delegate else { return }
                    guard let taskType = activity.taskType else { return }
                    self.navigator.startTaskSection(taskIdentifier: feed.id,
                                                    taskType: taskType,
                                                    taskOptions: nil,
                                                    presenter: delegate.presenter)
                })
            case .survey(let survey):
                cell.display(data: survey, buttonPressedCallback: { () in
                    self.navigator.pushProgressHUD()
                    self.repository.getSurvey(surveyId: feed.id)
                        .subscribe(onSuccess: { [weak self] surveyGroup in
                            guard let self = self else { return }
                            guard let delegate = self.delegate else { return }
                            self.navigator.popProgressHUD()
                            self.navigator.startSurveySection(surveyGroup: surveyGroup, presenter: delegate.presenter)
                        }, onError: { [weak self] error in
                            guard let self = self else { return }
                            guard let delegate = self.delegate else { return }
                            self.navigator.popProgressHUD()
                            self.navigator.handleError(error: error, presenter: delegate.presenter)
                        }).disposed(by: self.disposeBag)
                })
            case .educational(let educational):
                cell.display(data: educational, buttonPressedCallback: { [weak self] in
                    guard let self = self else { return }
                    guard let delegate = self.delegate else { return }
                    self.navigator.handleInfoTile(info: educational,
                                                  presenter: delegate.presenter)
                })
            case .alert(let alert):
                cell.display(data: alert, buttonPressedCallback: { [weak self] in
                    guard let self = self else { return }
                    guard let delegate = self.delegate else { return }
                    self.navigator.handleInfoTile(info: alert,
                                                  presenter: delegate.presenter)
                })
            case .rewards(let rewards):
                cell.display(data: rewards, buttonPressedCallback: { [weak self] in
                    guard let self = self else { return }
                    guard let delegate = self.delegate else { return }
                    self.navigator.handleInfoTile(info: rewards,
                                                  presenter: delegate.presenter)
                })
            }
            return cell
        } else {
            assertionFailure("Unhandled Feed")
            return UITableViewCell()
        }
    }
}

extension FeedListManager: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionText = self.sections[section].sectionText else {
            return nil
        }
        guard let cell = tableView.dequeueReusableHeaderFooterViewOfType(type: FeedListSectionHeader.self) else {
            assertionFailure("FeedListSectionHeader not registered")
            return UIView()
        }
        cell.display(text: sectionText)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Needed to remove the default blank footer under each section
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
}

fileprivate extension FeedContent {
    var sections: [FeedListSection] {
        var quickActivitySections: [QuickActivitySection] = []
        if self.quickActivities.count > 0 {
            let items: [QuickActivityItem] = self.quickActivities.compactMap { feed in
                switch feed.schedulable {
                case .quickActivity(let quickActivity): return QuickActivityItem(taskId: feed.id, quickActivity: quickActivity)
                default: return nil
                }
            }
            quickActivitySections.append(QuickActivitySection(quickActivies: items))
        }
        let feedSections: [FeedSection] = self.feedItems
            // This sorts the items within the section
            .sorted { $0.fromDate > $1.fromDate }
            .reduce([:]) { (result, item) -> [String: [Feed]] in
                let dateString = item.fromDate.sectionDateString
                var items = result[dateString] ?? []
                items.append(item)
                var currentResult = result
                currentResult[dateString] = items
                return currentResult
            }
            .map { FeedSection(dateString: $0.key, feedItems: $0.value) }
            // This sorts the sections
            .sorted { (sectionA, sectionB) -> Bool in
                guard let dateA = sectionA.feedItems.first?.fromDate, let dateB = sectionB.feedItems.first?.fromDate else {
                    return true
                }
                return dateA > dateB
            }
        return quickActivitySections + feedSections
    }
}

fileprivate extension Date {
    var sectionDateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .long
        return dateFormatter.string(from: self)
    }
}
