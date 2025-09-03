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
    
    var isSurvey: Bool {
        if case .survey = self { return true }
        return false
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
                case .quickActivity(let quickActivity): return QuickActivityItem(taskId: feed.id, quickActivity: quickActivity, optionalFlag: false)
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
    
    /// Return true if the given survey is the "Daily Inputs" one (SABA rule).
    /// Default: false.
    func isDailyInputsSurvey(_ survey: Survey) -> Bool
}

extension FeedListManagerDelegate {
    func onListRefresh() {}
    func isDailyInputsSurvey(_ survey: Survey) -> Bool { false }
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
    
    // MARK: SABA gating + testing override
    private let isInfiniteScrollEnabled: Bool
    private let forceSabaFooterForTesting: Bool
    private var isSabaEffective: Bool {
        // NOTE: enable SABA behavior when real SABA or when testing override is on
        return ProjectInfo.StudyId.lowercased() == "saba" || forceSabaFooterForTesting
    }
    
    // Helper: check "non-daily" survey
    private func isDailySurvey(_ feed: Feed) -> Bool {
        guard let sched = feed.schedulable else { return false }
        switch sched {
        case .survey(let survey):
            // Delegate decides if this is "Daily Inputs"
            let isDailyInputs = self.delegate?.isDailyInputsSurvey(survey) ?? false
            return isDailyInputs
        default:
            return false
        }
    }

    // UI-window of visible feed items for SABA mode (nil = show all)
    private var visibleItemLimit: Int?
    private let sabaStep: Int = 2  // NOTE: number of items revealed per tap

    // Keep a “visible content” snapshot for SABA mode
    private var visibleContent: FeedContent?

    // Footer button views
    private weak var footerContainer: UIView?
    private weak var footerButtonView: GenericButtonView?

    // When we increase the window, we remember where to scroll
    private var pendingScrollGlobalIndex: Int?

    // Use visible content when present
    private var sections: [FeedListSection] {
        // NOTE: Avoid lazy-var “mutating getter” issue by binding to var
        if var v = self.visibleContent { return v.sections }
        if var c = self.content { return c.sections }
        return []
    }
    
//    private var sections: [FeedListSection] { return self.content?.sections ?? [] }
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
         pullToRefresh: Bool = true,
         isInfiniteScrollEnabled: Bool = true,
         forceSabaFooterForTesting: Bool = false) {
        
        self.repository = repository
        self.navigator = navigator
        self.tableView = tableView
        self.analytics = Services.shared.analytics
        self.delegate = delegate
        self.isInfiniteScrollEnabled = isInfiniteScrollEnabled
        self.forceSabaFooterForTesting = forceSabaFooterForTesting
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
        
        if self.isSabaEffective {
            self.visibleItemLimit = self.sabaStep // show first 2 items initially
            self.installFooterButton(style: .secondaryBackground(shadow: false))
        }
        
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
        if let footer = self.footerContainer, self.isSabaEffective {
            self.setTableFooterView(footer)
        }
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
                
                // Apply SABA reward rule for display
                self.content = self.applySabaRewardRule(to: content)
                
                // SABA: recompute visible window
                self.recalcVisibleContent()
                self.handleRefreshEnd()
                self.errorView.hideView()
                self.updateFooterVisibility() // SABA: show/hide footer accordingly
                self.updateFooterTitle()
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
        
        // SABA: disable footer while loading
        if self.isSabaEffective { self.footerButtonView?.setButtonEnabled(enabled: false) }
        
        let pageIndex = (self.content?.itemCount ?? 0) / pageSize
        let paginationInfo = PaginationInfo(pageSize: pageSize, pageIndex: pageIndex)
        self.currentRequestDisposable = delegate.getDataProviderSingle(repository: self.repository,
                                                                       fetchMode: .append(paginationInfo: paginationInfo))
            .do(onSuccess: { [weak self] _ in self?.handleFetchEnd() },
                onError: { [weak self] _ in self?.handleFetchEnd() })
            .subscribe(onSuccess: { [weak self] content in
                guard let self = self else { return }
                self.updateHasContent(withFeedContent: content)
                let merged = self.content.merge(withContent: content)
                self.content = self.applySabaRewardRule(to: merged)
                
                // SABA: after fetching, recompute window + scroll if needed
                self.recalcVisibleContent()
                self.tableView.reloadData()
                self.errorView.hideView()
                self.footerButtonView?.setButtonEnabled(enabled: true)
                self.updateFooterVisibility()
                self.updateFooterTitle()
                self.scrollToPendingTargetIfAny()
                
            }, onFailure: { error in
                delegate.showError(error: error)
                self.footerButtonView?.setButtonEnabled(enabled: true)
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
    
    private func sendQuickActiviyOption(_ option: QuickActivityOption, forTaskId taskId: String, optionalFlag: Bool) {
        guard let delegate = self.delegate else {
            assertionFailure("FeedListManager - Missing delegate")
            return
        }
        
        self.repository.sendQuickActivityResult(quickActivityTaskId: taskId,
                                                quickActivityOption: option,
                                                optionalFlag: optionalFlag)
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
    
    // MARK: - Footer Button (GenericButtonView)

    private func installFooterButton(style: GenericButtonTextStyleCategory) {
        let container = UIView()
        container.backgroundColor = .clear

        let button = GenericButtonView(withTextStyleCategory: style,
                                       fillWidth: true,
                                       horizontalInset: Constants.Style.DefaultHorizontalMargins,
                                       height: Constants.Style.DefaultFooterHeight)
        container.addSubview(button)
        button.autoPinEdgesToSuperviewEdges()
        self.updateFooterTitle()
        button.addTarget(target: self, action: #selector(self.footerButtonTapped))

        self.footerContainer = container
        self.footerButtonView = button

        // Initially hidden; will be shown by updateFooterVisibility() when we know hasMore
        self.setTableFooterView(container)
        self.updateFooterVisibility()
    }

    @objc private func footerButtonTapped() {
        // NOTE: Increase window by 2 and fetch more if needed, then scroll to first newly revealed row
        let oldLimit = self.visibleItemLimit ?? 0
        let newLimit = oldLimit + self.sabaStep
        self.visibleItemLimit = newLimit
        self.recalcVisibleContent()
        self.tableView.reloadData()

        // Remember where to scroll (first newly revealed global index)
        self.pendingScrollGlobalIndex = oldLimit

        // If we don't have enough loaded items to satisfy the new window, fetch the next page
        let loadedCount = (self.content?.feedItems.count ?? 0)
        if newLimit > loadedCount, self.hasMoreContent {
            self.footerButtonView?.setButtonEnabled(enabled: false)
            self.appendItems()
        } else {
            self.scrollToPendingTargetIfAny()
            self.updateFooterVisibility()
            self.updateFooterTitle()
        }
    }

    private func setTableFooterView(_ view: UIView) {
        // NOTE: Size footer to fit Auto Layout content
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let w = self.tableView.bounds.width
        let h = view.systemLayoutSizeFitting(
            CGSize(width: w, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        view.frame = CGRect(x: 0, y: 0, width: w, height: h)
        self.tableView.tableFooterView = (self.isSabaEffective ? view : UIView())
    }

    private func updateFooterVisibility() {
        // NOTE: Footer is used only in SABA mode and only if there is more to show or fetch
        guard self.isSabaEffective else {
            self.tableView.tableFooterView = UIView()
            return
        }
        guard let footer = self.footerContainer else { return }

        let totalLoaded = self.content?.feedItems.count ?? 0
        let visible = self.visibleItemLimit ?? totalLoaded
        let hasMoreToReveal = visible < totalLoaded
        let canFetchMore = self.hasMoreContent

        if hasMoreToReveal || canFetchMore {
            self.setTableFooterView(footer)
            self.footerButtonView?.setButtonEnabled(enabled: true)
        } else {
            self.tableView.tableFooterView = UIView()
        }
    }
    
    // MARK: - Visible content for SABA

    private func recalcVisibleContent() {
        guard self.isSabaEffective, let content = self.content else {
            self.visibleContent = nil
            return
        }
        guard let limit = self.visibleItemLimit else {
            self.visibleContent = content
            return
        }

        // NOTE: Keep the same order used by sections: most-recent-first
        let sorted = content.feedItems.sorted { $0.fromDate > $1.fromDate }
        let clamped = min(limit, sorted.count)
        let limitedItems = Array(sorted.prefix(clamped))
        self.visibleContent = FeedContent(withQuickActivities: content.quickActivities,
                                          feedItems: limitedItems)
    }

    private func scrollToPendingTargetIfAny() {
        // NOTE: Scroll to the first newly revealed row (global index in the visible feed items)
        guard let target = self.pendingScrollGlobalIndex else { return }
        self.pendingScrollGlobalIndex = nil

        // Build flat index-path list for visible feed items (exclude quick-activity section)
        var flat: [IndexPath] = []
        for (sectionIndex, section) in self.sections.enumerated() {
            guard let fs = section as? FeedSection else { continue }
            for row in 0..<fs.feedItems.count {
                flat.append(IndexPath(row: row, section: sectionIndex))
            }
        }
        guard target >= 0, target < flat.count else { return }
        self.tableView.scrollToRow(at: flat[target], at: .top, animated: true)
    }
    
    // MARK: - Footer title update

    // MARK: - Remaining surveys count (loaded only)

    /// Count remaining surveys among the *loaded* feed items:
    /// totalLoadedSurveys - visibleSurveys(in the current SABA window).
    private func remainingSurveysCount() -> Int {
        // If not in SABA (or no content), nothing to compute
        guard self.isSabaEffective, let content = self.content else { return 0 }

        // Keep same ordering used by sections (newest first)
        let sorted = content.feedItems.sorted { $0.fromDate > $1.fromDate }

        // How many surveys are loaded
        let totalLoadedSurveys = sorted.reduce(0) { $0 + (( $1.schedulable?.isSurvey == true ) ? 1 : 0) }

        // How many surveys are currently visible (within the visibleItemLimit window)
        let limit = min(self.visibleItemLimit ?? sorted.count, sorted.count)
        let visiblePrefix = sorted.prefix(limit)
        let visibleSurveys = visiblePrefix.reduce(0) { $0 + (( $1.schedulable?.isSurvey == true ) ? 1 : 0) }

        return max(totalLoadedSurveys - visibleSurveys, 0)
    }

    /// Update footer button title with remaining *surveys*.
    private func updateFooterTitle() {
        guard self.isSabaEffective, let button = self.footerButtonView else { return }
        let remaining = self.remainingSurveysCount()
        let title = StringsProvider.string(forKey: .footerFeedButton,
                                           withParameters: ["\(remaining)"])
        button.setButtonText(title)
    }
    
    // Apply SABA rule: hide reward items while there is at least one non-daily survey in the list.
    private func applySabaRewardRule(to content: FeedContent) -> FeedContent {
        // Only enforce in SABA
        guard isSabaEffective else { return content }

        // If there is any non-daily survey still present, remove rewards
        let hasBlockingSurvey = content.feedItems.contains(where: { self.isDailySurvey($0) })

        if hasBlockingSurvey {
            let filteredFeedItems = content.feedItems.filter { feed in
                // Keep everything except reward notifiable
                if let notifiable = feed.notifiable {
                    switch notifiable {
                    case .reward:
                        return false
                    default:
                        return true
                    }
                }
                return true
            }
            return FeedContent(withQuickActivities: content.quickActivities,
                               feedItems: filteredFeedItems)
        } else {
            // No blocking surveys -> rewards can be shown
            return content
        }
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
        if !self.isSabaEffective, self.isInfiniteScrollEnabled,
           self.hasMoreContent, section == self.sections.count - 1 {
            return self.sections[section].numberOfRows + 1
        } else {
            return self.sections[section].numberOfRows
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let getLoadingCell: (() -> UITableViewCell) = {
            assert(!self.isSabaEffective && self.isInfiniteScrollEnabled && self.hasMoreContent, "No need to show the Loading cell")
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
                self.sendQuickActiviyOption(selectedOption, forTaskId: item.taskId, optionalFlag: item.optionalFlag)
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
                        self.navigator.handleNotifiableTile(data: feed,
                                                            notifiableUrl: educational.urlString,
                                                            presenter: delegate.presenter,
                                                            weHaveNoticed: false)
                    })
                case .alert(let alert):
                    cell.display(data: alert, wehaveNoticed: true, buttonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        guard let delegate = self.delegate else { return }
                        self.navigator.handleNotifiableTile(data: feed,
                                                            notifiableUrl: alert.urlString,
                                                            presenter: delegate.presenter,
                                                            weHaveNoticed: true)
                    })
                case .reward(let reward):
                    cell.display(data: reward, buttonPressedCallback: { [weak self] in
                        guard let self = self else { return }
                        guard let delegate = self.delegate else { return }
                        self.navigator.handleNotifiableTile(data: feed,
                                                            notifiableUrl: reward.urlString,
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
        if !self.isSabaEffective,
           self.isInfiniteScrollEnabled,
           cell is LoadingTableViewCell,
           self.hasMoreContent {
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
