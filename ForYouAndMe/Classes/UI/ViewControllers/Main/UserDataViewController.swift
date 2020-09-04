//
//  UserDataViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import Foundation

import UIKit

class UserDataViewController: UIViewController {
    
    // MARK: - AttributedTextStyles
    
    private let titleLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                    colorType: .primaryText,
                                                                    textAlignment: .left)
    private let subtitleLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .paragraph,
                                                                       colorType: .primaryText,
                                                                       textAlignment: .left)
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var summaryView: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        let stackView = UIStackView.create(withAxis: .vertical)
        view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 40.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 40.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        stackView.addArrangedSubview(self.titleLabel)
        stackView.addBlankSpace(space: 20.0)
        stackView.addArrangedSubview(self.subtitleLabel)
        // TODO: Add stars view
        return view
    }()
    
    private lazy var chartStackView: UIStackView = {
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 30.0)
        return stackView
    }()
    
    private lazy var dataView: UIView = {
        let view = UIView()
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 30.0)
        view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 40.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 40.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabUserDataPeriodTitle),
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .left)
        // TODO: Add period selector
        stackView.addArrangedSubview(self.chartStackView)
        return view
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private var isViewPrepared: Bool {
        return self.scrollStackView.stackView.arrangedSubviews.count != 0
    }
    
    private let navigator: AppNavigator
    private let repository: Repository
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .fourth)
        
        // Header View
        let headerView = SingleTextHeaderView()
        headerView.setTitleText(StringsProvider.string(forKey: .tabUserDataTitle))
        
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        
        self.refreshUI()
    }
    
    // MARK: - Private Methods
    
    private func refreshUI() {
        // TODO: replace this with actual refresh
        self.navigator.pushProgressHUD()
        let closure: (() -> Void) = {
            self.navigator.popProgressHUD()
            self.prepareUI()
            self.refreshSummary(title: "You’ve participated in this study for 67 days so far",
                                subtitle: "On average, you complete 82% of your weekly assigned tasks - Which makes you a MASTER CONTRIBUTOR to science. Thank you! Keep it up!",
                                rating: 4)
            self.refreshCharts()
        }
        let delayTime = DispatchTime.now() + 1.0
        let dispatchWorkItem = DispatchWorkItem(block: closure)
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: dispatchWorkItem)
    }
    
    private func prepareUI() {
        if false == self.isViewPrepared {
            self.scrollStackView.stackView.addArrangedSubview(self.summaryView)
            self.scrollStackView.stackView.addArrangedSubview(self.dataView)
        }
    }
    
    private func refreshSummary(title: String, subtitle: String, rating: Int) {
        self.titleLabel.attributedText = NSAttributedString.create(withText: title,
                                                                   attributedTextStyle: self.titleLabelAttributedTextStyle)
        self.subtitleLabel.attributedText = NSAttributedString.create(withText: subtitle,
                                                                      attributedTextStyle: self.subtitleLabelAttributedTextStyle)
        // TODO: Refresh rating
    }
    
    private func refreshCharts() {
        // TODO: Implement chart refresh
    }
}
