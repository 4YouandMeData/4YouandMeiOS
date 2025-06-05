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
    
    lazy var sections: [FeedListSection] = {
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
    }()
    
    init(withQuickActivities quickActivities: [Feed], feedItems: [Feed]) {
        self.quickActivities = quickActivities
        self.feedItems = feedItems
    }
    
    init(withFeeds feeds: [Feed]) {
        self.quickActivities = feeds.filter { $0.schedulable?.isQuickActivity ?? false}
        self.feedItems = feeds.filter { false == $0.schedulable?.isQuickActivity ?? false}
    }
    
    var itemCount: Int {
        return self.quickActivities.count + self.feedItems.count + 1
    }
}

protocol FeedListManagerDelegate: AnyObject {
    var presenter: UIViewController { get }
    func handleEmptyList(show: Bool)
    func getDataProviderSingle(repository: Repository, fetchMode: FetchMode) -> Single<FeedContent>
    func onListRefresh()
    func showError(error: Error)
}

extension FeedListManagerDelegate {
    func onListRefresh() {}
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
    
    private let pageSize: Int?
    
    private weak var delegate: FeedListManagerDelegate?
    
    private var sections: [FeedListSection] { return self.content?.sections ?? [] }
    private var content: FeedContent?
    private var hasMoreContent: Bool = false
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
         pageSize: Int?,
         pullToRefresh: Bool = true) {
        self.repository = repository
        self.navigator = navigator
        self.tableView = tableView
        self.analytics = Services.shared.analytics
        self.delegate = delegate
        self.pageSize = {
            if let pageSize = pageSize {
                return max(1, pageSize)
            } else {
                return nil
            }
        }()
        
        super.init()
        
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.registerCellsWithClass(FeedTableViewCell.self)
        self.tableView.registerCellsWithClass(QuickActivityListTableViewCell.self)
        self.tableView.registerCellsWithClass(LoadingTableViewCell.self)
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
        print("FeedListManager - deinit")
        self.currentRequestDisposable?.dispose()
    }
    
    // MARK: - Public Methods
    
    public func refreshItems(onCompletion: NotificationCallback? = nil) {
        self.reloadItems(onCompletion: onCompletion)
    }
    
    public func viewWillAppear() {
        self.reloadItems()
    }
    
    public func viewDidLayoutSubviews() {
        self.tableView.reloadData()
        self.tableView.sizeHeaderToFit()
    }
    
    // MARK: - Private Methods
    
    private func reloadItems(onCompletion: NotificationCallback? = nil) {
        
        guard let delegate = self.delegate else {
            assertionFailure("FeedListManager - Missing delegate")
            return
        }
        
        self.currentRequestDisposable?.dispose()
        self.currentRequestDisposable = delegate.getDataProviderSingle(repository: self.repository,
                                                                       fetchMode: .refresh(pageSize: self.pageSize))
            .do(onSuccess: { [weak self] _ in self?.handleFetchEnd() },
                onError: { [weak self] _ in self?.handleFetchEnd() })
            .addProgress()
            .subscribe(onSuccess: { [weak self] content in
                guard let self = self else { return }
                self.updateHasContent(withFeedContent: content)
                self.content = content
                self.handleRefreshEnd()
                self.errorView.hideView()
                onCompletion?()
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.content = nil
                self.handleRefreshEnd()
                self.errorView.showViewWithError(error)
            })
    }
    
    private func appendItems() {
        guard let delegate = self.delegate else {
            assertionFailure("FeedListManager - Missing delegate")
            return
        }
        guard let pageSize = self.pageSize else {
            assertionFailure("Trying to append items without page size")
            return
        }
        
        if self.currentRequestDisposable != nil {
            return
        }
        
        let pageIndex = (self.content?.itemCount ?? 0) / pageSize
        let paginationInfo = PaginationInfo(pageSize: pageSize, pageIndex: pageIndex)
        self.currentRequestDisposable = delegate.getDataProviderSingle(repository: self.repository,
                                                                       fetchMode: .append(paginationInfo: paginationInfo))
            .do(onSuccess: { [weak self] _ in self?.handleFetchEnd() },
                onError: { [weak self] _ in self?.handleFetchEnd() })
            .subscribe(onSuccess: { [weak self] content in
                guard let self = self else { return }
                self.updateHasContent(withFeedContent: content)
                self.content = self.content.merge(withContent: content)
                self.tableView.reloadData()
                self.errorView.hideView()
            }, onFailure: { error in
                delegate.showError(error: error)
            })
    }
    
    private func handleRefreshEnd() {
        self.delegate?.onListRefresh()
        
        let showEmptyView = self.sections.count == 0
        self.delegate?.handleEmptyList(show: showEmptyView)
        self.tableView.reloadData()
        self.tableView.sizeHeaderToFit()
        self.goToTop()
    }
    
    private func handleFetchEnd() {
        self.tableView.refreshControl?.endRefreshing()
        self.currentRequestDisposable = nil
    }
    
    private func updateHasContent(withFeedContent feedContent: FeedContent) {
        if let pageSize = self.pageSize {
            self.hasMoreContent = (feedContent.itemCount == 0 || feedContent.itemCount >= pageSize)
        } else {
            self.hasMoreContent = false
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
        
        self.repository.sendQuickActivityResult(quickActivityTaskId: taskId,
                                                quickActivityOption: option)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.analytics.track(event: .quickActivity(taskId, option: option.id))
                self.reloadItems()
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: delegate.presenter)
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: - Actions
    
    @objc private func refreshControlPulled() {
        self.reloadItems()
    }
}

extension FeedListManager: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.hasMoreContent, section == self.sections.count - 1 {
            // If there is more content and this is the last section
            // add one cell for the loading cell
            return self.sections[section].numberOfRows + 1
        } else {
            return self.sections[section].numberOfRows
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let getLoadingCell: (() -> UITableViewCell) = {
            assert(self.hasMoreContent, "No need to show the Loading cell")
            guard let cell = tableView.dequeueReusableCellOfType(type: LoadingTableViewCell.self, forIndexPath: indexPath) else {
                assertionFailure("LoadingTableViewCell not registered")
                return UITableViewCell()
            }
            return cell
        }
        
        let section = self.sections[indexPath.section]
        if let quickActivitySection = section as? QuickActivitySection {
            
            guard indexPath.row < 1 else {
                return getLoadingCell()
            }
            
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
            
            guard indexPath.row < feedSection.feedItems.count else {
                return getLoadingCell()
            }
            
            let feed = feedSection.feedItems[indexPath.row]
            guard let cell = tableView.dequeueReusableCellOfType(type: FeedTableViewCell.self, forIndexPath: indexPath) else {
                assertionFailure("FeedTableViewCell not registered")
                return UITableViewCell()
            }
            if let schedulable = feed.schedulable {
                switch schedulable {
                case .quickActivity:
                    assertionFailure("Unexpected quick activity as schedulable type")
                case .activity(let activity):
                    cell.display(data: activity,
                                 skippable: feed.skippable ?? false,
                                 buttonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        guard let delegate = self.delegate else { return }
                        self.navigator.startTaskSection(withTask: feed,
                                                        activity: activity,
                                                        taskOptions: nil,
                                                        presenter: delegate.presenter)
                    }, skipButtonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        self.repository.sendSkipTask(taskId: feed.id)
                            .addProgress()
                            .subscribe(onSuccess: { [weak self] in
                                guard let self = self else { return }
                                self.reloadItems()
                            })
                            .disposed(by: self.disposeBag)
                    })
                case .survey(let survey):
                    cell.display(data: survey,
                                 skippable: feed.skippable ?? false,
                                 buttonPressedCallback: { () in
                        self.repository.getSurvey(surveyId: survey.id)
                            .addProgress()
                            .subscribe(onSuccess: { [weak self] surveyGroup in
                                guard let self = self else { return }
                                guard let delegate = self.delegate else { return }
                                self.navigator.startSurveySection(withTask: feed,
                                                                  surveyGroup: surveyGroup,
                                                                  presenter: delegate.presenter)
                            }, onFailure: { [weak self] error in
                                guard let self = self else { return }
                                guard let delegate = self.delegate else { return }
                                self.navigator.handleError(error: error, presenter: delegate.presenter)
                            }).disposed(by: self.disposeBag)
                    }, skipButtonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        self.repository.sendSkipTask(taskId: feed.id)
                            .addProgress()
                            .subscribe(onSuccess: { [weak self] in
                                guard let self = self else { return }
                                self.reloadItems()
                            })
                            .disposed(by: self.disposeBag)
                    })
                }
            } else if let notifiable = feed.notifiable {
                switch notifiable {
                case .educational(let educational):
                    cell.display(data: educational, buttonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        guard let delegate = self.delegate else { return }
                        self.navigator.handleNotifiableTile(notifiableUrl: educational.urlString,
                                                            presenter: delegate.presenter,
                                                            weHaveNoticed: false)
                    })
                case .alert(let alert):
                    cell.display(data: alert, wehaveNoticed: true, buttonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        guard let delegate = self.delegate else { return }
                        self.navigator.handleNotifiableTile(notifiableUrl: alert.urlString,
                                                            presenter: delegate.presenter,
                                                            weHaveNoticed: true)
                    })
                case .reward(let reward):
                    cell.display(data: reward, buttonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        guard let delegate = self.delegate else { return }
                        self.navigator.handleNotifiableTile(notifiableUrl: reward.urlString,
                                                            presenter: delegate.presenter,
                                                            weHaveNoticed: false)
                    })
                }
            } else {
                assertionFailure("Unhandle Type")
            }
            return cell
        } else {
            assertionFailure("Unhandled Feed")
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if cell is LoadingTableViewCell, self.hasMoreContent {
            print("FeedListManager - load more contents")
            self.appendItems()
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

fileprivate extension Date {
    var sectionDateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .long
        return dateFormatter.string(from: self)
    }
}

fileprivate extension Optional where Wrapped == FeedContent {
    func merge(withContent content: FeedContent) -> FeedContent {
        guard let self = self else {
            return content
        }
        return FeedContent(withQuickActivities: self.quickActivities + content.quickActivities,
                           feedItems: self.feedItems + content.feedItems)
    }
}
