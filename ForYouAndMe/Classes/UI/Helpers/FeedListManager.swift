//
//  FeedListManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit
import RxSwift

protocol FeedItem {
    var date: Date { get }
}

struct FeedContent {
    let feedItems: [FeedItem]
}

protocol FeedListManagerDelegate: class {
    var presenter: UIViewController { get }
    func handleEmptyList(show: Bool)
    func getDataProviderSingle(repository: Repository) -> Single<FeedContent>
}

private struct FeedSection {
    let dateString: String
    let feedItems: [FeedItem]
}

class FeedListManager: NSObject {
    private let tableView: UITableView
    private let repository: Repository
    private let navigator: AppNavigator
    private weak var delegate: FeedListManagerDelegate?
    
    private var sections: [FeedSection] = []
    private var currentRequestDisposable: Disposable?
    
    final let disposeBag: DisposeBag = DisposeBag()
    
    init(repository: Repository,
         navigator: AppNavigator,
         tableView: UITableView,
         delegate: FeedListManagerDelegate,
         pullToRefresh: Bool = true) {
        self.repository = repository
        self.navigator = navigator
        self.tableView = tableView
        self.delegate = delegate
        
        super.init()
        
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.registerCellsWithClass(FeedTableViewCell.self)
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
                
                onCompletion?()
                
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.tableView.refreshControl?.endRefreshing()
                    
                    self.currentRequestDisposable = nil
                    self.navigator.handleError(error: error, presenter: delegate.presenter)
            })
    }
    
    private func reloadTableView() {
        // TODO: Update show logic when quick activities are added
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
    
    // MARK: - Actions
    
    @objc private func refreshControlPulled() {
        self.loadItems()
    }
}

extension FeedListManager: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // TODO: Update show logic when quick activities are added
        return self.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // TODO: Update show logic when quick activities are added
        return self.sections[section].feedItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = self.sections[indexPath.section].feedItems[indexPath.row]
        if let feed = item as? Feed {
            guard let cell = tableView.dequeueReusableCellOfType(type: FeedTableViewCell.self, forIndexPath: indexPath) else {
                assertionFailure("FeedTableViewCell not registered")
                return UITableViewCell()
            }
            cell.display(data: feed, buttonPressedCallback: { [weak self] in
                guard let delegate = self?.delegate else { return }
                guard let feedBehavior = feed.behavior else {
                    assertionFailure("Missing behavior for FeedTableViewCell button callback")
                    return
                }
                
                switch feedBehavior {
                case .info(let body):
                    // TODO: Show content page
                    print("TODO: Show content page with body '\(body)'")
                    delegate.presenter.showAlert(withTitle: "Info page", message: "Work in progress", closeButtonText: "OK")
                case .externalLink(let url):
                    // TODO: Show external link
                    print("TODO: Show external link with url '\(url)'")
                    delegate.presenter.showAlert(withTitle: "External Link", message: "Work in progress", closeButtonText: "OK")
                case .task(let taskId, let taskType):
                    // TODO: Show task
                    print("TODO: Show task with Id '\(taskId)' and type '\(taskType)'")
                    delegate.presenter.showAlert(withTitle: "Task", message: "Work in progress", closeButtonText: "OK")
                }
            })
            return cell
        } else {
            assertionFailure("Unhandled FeedItem")
            return UITableViewCell()
        }
    }
}

extension FeedListManager: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let cell = tableView.dequeueReusableHeaderFooterViewOfType(type: FeedListSectionHeader.self) else {
            assertionFailure("FeedListSectionHeader not registered")
            return UIView()
        }
        cell.display(text: self.sections[section].dateString)
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
    var sections: [FeedSection] {
        self.feedItems
            // This sorts the items within the section
            .sorted { $0.date > $1.date }
            .reduce([:]) { (result, item) -> [String: [FeedItem]] in
                let dateString = item.date.sectionDateString
                var items = result[dateString] ?? []
                items.append(item)
                var currentResult = result
                currentResult[dateString] = items
                return currentResult
        }
        .map { FeedSection(dateString: $0.key, feedItems: $0.value) }
        // This sorts the sections
        .sorted { (sectionA, sectionB) -> Bool in
            guard let dateA = sectionA.feedItems.first?.date, let dateB = sectionB.feedItems.first?.date else {
                return true
            }
            return dateA > dateB
        }
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

extension Feed: FeedItem {
    var date: Date { self.creationDate }
}
