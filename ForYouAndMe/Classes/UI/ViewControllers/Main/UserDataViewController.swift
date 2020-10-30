//
//  UserDataViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift

class UserDataViewController: UIViewController, CustomSegmentViewDelegate {
    
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
    
    private let ratingView: StarRatingView = {
        let starView = StarRatingView()
        starView.editable = false
        starView.emptyImage = ImagePalette.image(withName: .starEmpty)
        starView.fullImage = ImagePalette.image(withName: .starFill)
        starView.minImageSize = CGSize(width: 22, height: 22)
        starView.type = .floatRatings
        starView.autoSetDimension(.height, toSize: 22)
        return starView
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
        stackView.addBlankSpace(space: 30.0)
        stackView.addArrangedSubview(self.ratingView)
        
        return view
    }()
    
    private lazy var chartStackView: UIStackView = {
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 30.0)
        return stackView
    }()
    
    private lazy var periodSegmentView: CustomSegmentView = {
        var segmentProperties = CustomSegmentViewProperties.init(switchTexts: [.week, .month, .year])
        segmentProperties.sliderOffset = 0
        let segmentView = CustomSegmentView(frame: .zero, switchProperties: segmentProperties)
        segmentView.autoSetDimension(.height, toSize: 47)
        segmentView.switchDelegate = self
        return segmentView
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
        
        stackView.addArrangedSubview(self.periodSegmentView)
        stackView.addArrangedSubview(self.chartStackView)
        return view
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private var isViewInitialized: Bool {
        return self.scrollStackView.stackView.arrangedSubviews.count != 0
    }
    
    private var currentPeriod: StudyPeriod {
        return StudyPeriod.allCases[self.periodSegmentView.selectedIndex]
    }
    
    private lazy var errorView: GenericErrorView = {
        return GenericErrorView(retryButtonCallback: { [weak self] in self?.refreshUI() })
    }()
    
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
    
    deinit {
        print("UserDataViewController - deinit")
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
        
        // Error View
        self.view.addSubview(self.errorView)
        self.errorView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        self.errorView.autoPinEdge(.top, to: .bottom, of: headerView)
        self.errorView.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabUserData)))
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.yourData.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.refreshUI()
    }
    
    // MARK: - Private Methods
    
    private func refreshUI() {
        let userDataRequest = self.repository.getUserData()
        let userDataAggregationRequest = self.repository.getUserDataAggregation(period: self.currentPeriod)
        
        self.navigator.pushProgressHUD()
        // Fetch both UserData and UserDataAggregation
        Single.zip(userDataRequest, userDataAggregationRequest).subscribe(onSuccess: { [weak self] (userData, userDataAggregations) in
            guard let self = self else { return }
            self.errorView.hideView()
            self.navigator.popProgressHUD()
            // Prepare UI if needed
            if false == self.isViewInitialized {
                self.scrollStackView.stackView.addArrangedSubview(self.summaryView)
                self.scrollStackView.stackView.addArrangedSubview(self.dataView)
            }
            // Show data on UI
            self.refreshSummary(withUserData: userData)
            self.refreshCharts(withUserDataAggregations: userDataAggregations)
        }, onError: { [weak self] error in
            guard let self = self else { return }
            self.navigator.popProgressHUD()
            self.errorView.showViewWithError(error)
        }).disposed(by: self.disposeBag)
    }
    
    private func refreshCharts(withStudyPeriod studyPeriod: StudyPeriod) {
        self.navigator.pushProgressHUD()
        // Fetch UserDataAggregation
        self.repository.getUserDataAggregation(period: studyPeriod).subscribe(onSuccess: { [weak self] userDataAggregations in
            guard let self = self else { return }
            self.navigator.popProgressHUD()
            // Show data on UI
            self.refreshCharts(withUserDataAggregations: userDataAggregations)
        }, onError: { [weak self] error in
            guard let self = self else { return }
            print("UserDataViewController - Error Fetching User Data Aggregation: \(error.localizedDescription)")
            self.navigator.popProgressHUD()
            self.showChartsError()
        }).disposed(by: self.disposeBag)
    }
    
    private func refreshSummary(withUserData userData: UserData) {
        self.titleLabel.attributedText = NSAttributedString.create(withText: userData.title ?? "",
                                                                   attributedTextStyle: self.titleLabelAttributedTextStyle)
        self.subtitleLabel.attributedText = NSAttributedString.create(withText: userData.body ?? "",
                                                                      attributedTextStyle: self.subtitleLabelAttributedTextStyle)
        self.ratingView.rating = userData.stars
    }
    
    private func refreshCharts(withUserDataAggregations userDataAggregations: [UserDataAggregation]) {
        self.chartStackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })

        userDataAggregations.forEach { userDataAggragation in
            let testChartView = UserDataChartView(title: userDataAggragation.title ?? "",
                                                  plotColor: userDataAggragation.color ?? ColorPalette.color(withType: .primary),
                                                  data: userDataAggragation.chartData.data,
                                                  xLabels: userDataAggragation.chartData.xLabels,
                                                  yLabels: userDataAggragation.chartData.yLabels,
                                                   studyPeriod: self.currentPeriod)
            self.chartStackView.addArrangedSubview(testChartView)
        }
    }
    
    private func showChartsError() {
        self.chartStackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        
        self.chartStackView.addArrangedSubview(UserDataAggregationErrorView(buttonCallback: { [weak self] in
            guard let self = self else { return }
            self.refreshCharts(withStudyPeriod: self.currentPeriod)
        }))
    }
    
    //Delegate Methods
    func segmentDidChanged(_ studyPeriod: StudyPeriod) {
        self.refreshCharts(withStudyPeriod: studyPeriod)
        self.analytics.track(event: .yourDataSelectionPeriod(studyPeriod.title))
    }
}
