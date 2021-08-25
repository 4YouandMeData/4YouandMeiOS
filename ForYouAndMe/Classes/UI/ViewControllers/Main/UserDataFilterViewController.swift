//
//  UserDataFilterViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/06/21.
//

import UIKit
import RxSwift

class UserDataFilterViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    
    private let userDataAggregationFilterData: [UserDataAggregationFilter]
    
    private let disposeBag = DisposeBag()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .secondaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        let containerView = UIView()
        containerView.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 20.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: StringsProvider.string(forKey: .userDataFilterTitle),
                           fontStyle: .title,
                           colorType: .secondaryText)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 26.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
        return containerView
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        // Subtract button content inset and checkbox inset on the right to keep vertical alignment (not elegant but it gets things done...)
        let scrollStackView = ScrollStackView(axis: .vertical,
                                              leftInset: Constants.Style.DefaultHorizontalMargins,
                                              rightInset: Constants.Style.DefaultHorizontalMargins - 8.0)
        return scrollStackView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground())
        view.setButtonText(StringsProvider.string(forKey: .userDataFilterSaveButton))
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    private lazy var clearButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.clearSelectAll.style)
        button.setTitle(StringsProvider.string(forKey: .userDataFilterClearButton), for: .normal)
        button.addTarget(self, action: #selector(self.clearButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var selectAllButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.clearSelectAll.style)
        button.setTitle(StringsProvider.string(forKey: .userDataFilterSelectAllButton), for: .normal)
        button.addTarget(self, action: #selector(self.selectAllButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var toolbarView: UIView = {
        let view = UIView()
        view.autoSetDimension(.height, toSize: 88.0)
        view.addSubview(self.clearButton)
        self.clearButton.autoPinEdge(toSuperviewEdge: .trailing)
        self.clearButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        view.addSubview(self.selectAllButton)
        self.selectAllButton.autoPinEdge(toSuperviewEdge: .trailing)
        self.selectAllButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        return view
    }()
    
    private var storage: CacheService
    private var itemViewsByIds: [String: GenericTextCheckboxView] = [:]
    private var excludedUserDataAggregationIds: Set<String>
    
    init(withUserDataAggregationFilterData userDataAggregationFilterData: [UserDataAggregationFilter]) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.userDataAggregationFilterData = userDataAggregationFilterData
        self.excludedUserDataAggregationIds = (self.storage.excludedUserDataAggregationIds ?? []).toSet
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("AboutYouViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Main Stack View
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addArrangedSubview(self.headerView)
        stackView.addArrangedSubview(self.scrollStackView)
        stackView.addArrangedSubview(self.confirmButtonView)
        
        // toolbar
        self.scrollStackView.stackView.addArrangedSubview(self.toolbarView)
        
        // filters
        self.userDataAggregationFilterData.forEach { userDataAggregationFilterItem in
            let isActive = false == self.excludedUserDataAggregationIds.contains(userDataAggregationFilterItem.identifier)
            let itemView = GenericTextCheckboxView(isDefaultChecked: isActive,
                                                   styleCategory: .primary(fontStyle: .paragraph, textFirst: true))
            itemView.setLabelText(userDataAggregationFilterItem.title)
            itemView.isCheckedSubject.subscribe(onNext: { [weak self] checked in
                guard let self = self else { return }
                if checked {
                    self.excludedUserDataAggregationIds.remove(userDataAggregationFilterItem.identifier)
                } else {
                    self.excludedUserDataAggregationIds.insert(userDataAggregationFilterItem.identifier)
                }
                self.updateToolBar()
            }).disposed(by: self.disposeBag)
            self.itemViewsByIds[userDataAggregationFilterItem.identifier] = itemView
            self.scrollStackView.stackView.addArrangedSubview(itemView)
        }
        
        self.updateToolBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.yourDataFilter.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func confirmButtonPressed() {
        self.storage.excludedUserDataAggregationIds = Array(self.excludedUserDataAggregationIds)
        self.customCloseButtonPressed()
    }
    
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
    
    @objc private func clearButtonPressed() {
        self.excludedUserDataAggregationIds = self.userDataAggregationFilterData.map { $0.identifier }.toSet
        self.updateToolBar()
        self.updateItemViews()
    }
    
    @objc private func selectAllButtonPressed() {
        self.excludedUserDataAggregationIds = []
        self.updateToolBar()
        self.updateItemViews()
    }
    
    // MARK: - Private Methods
    
    private func updateToolBar() {
        self.clearButton.isHidden = true
        self.selectAllButton.isHidden = true
        
        // Show select all only when every option is unselected, otherwise show clear
        if self.excludedUserDataAggregationIds.count == self.userDataAggregationFilterData.count {
            self.selectAllButton.isHidden = false
        } else {
            self.clearButton.isHidden = false
        }
    }
    
    private func updateItemViews() {
        self.itemViewsByIds.forEach { itemViewById in
            let isActive = false == self.excludedUserDataAggregationIds.contains(itemViewById.key)
            itemViewById.value.updateCheckBox(isActive)
        }
    }
}
