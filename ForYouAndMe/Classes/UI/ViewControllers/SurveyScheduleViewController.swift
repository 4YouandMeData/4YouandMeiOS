//
//  SurveyScheduleViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 07/04/21.
//

import Foundation
import RxSwift

public class SurveyScheduleViewController: UIViewController {
    
    private var titleString: String
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    private let disposeBag: DisposeBag = DisposeBag()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false),
                                     horizontalInset: Constants.Style.DefaultHorizontalMargins,
                                     height: Constants.Style.DefaultTextButtonHeight)
        view.setButtonText(StringsProvider.string(forKey: .dailySurveyTimingTitleButton))
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    private lazy var datePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.minuteInterval = 60
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        datePicker.datePickerMode = .time
        datePicker.locale = NSLocale(localeIdentifier: "en_US") as Locale
        datePicker.tintColor = ColorPalette.color(withType: .primary)
        datePicker.backgroundColor = .white
        datePicker.addTarget(self, action: #selector(self.handleDatePicker), for: .valueChanged)
        return datePicker
    }()
    
    init(withTitle title: String) {
        self.titleString = title
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.repository = Services.shared.repository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = InfoDetailHeaderView(withTitle: self.titleString )
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        headerView.backButton.addTarget(self, action: #selector(self.backButtonPressed), for: .touchUpInside)
        // ScrollStackView
        self.scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        self.scrollStackView.stackView.spacing = 30
        
        self.refreshStatus()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.openPermissions.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: Actions
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    private func refreshStatus() {
        
        self.scrollStackView.stackView.addLabel(withText: StringsProvider.string(forKey: .dailySurveyTimingDescription),
                                                fontStyle: .paragraph,
                                                colorType: .primaryText,
                                                textAlignment: .left)
                                                
        self.scrollStackView.stackView.addArrangedSubview(self.datePicker)
        self.scrollStackView.stackView.addBlankSpace(space: 20)
        self.scrollStackView.stackView.addArrangedSubview(UIView())
        
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0,
                                                                                  left: 0,
                                                                                  bottom: Constants.Style.DefaultBottomMargin,
                                                                                  right: 0),
                                                               excludingEdge: .top)
        
        self.getUserSettings()
    }
    
    @objc func handleDatePicker(_ datePicker: UIDatePicker) {
        print("\(datePicker.date)")
    }
    
    @objc private func confirmButtonPressed() {
        print("\(self.datePicker.date.getSecondsSinceMidnight())")
        self.sendUserSettings()
    }
    
    private func getUserSettings() {
        self.repository.getUserSettings()
            .addProgress()
            .subscribe(onSuccess: { [weak self] userSettings in
                guard let self = self else { return }
                guard let secondsFromMidnight = userSettings.secondsFromMidnight else {
                    return
                }
                let date = secondsFromMidnight.dateFromSeconds()
                print("\(date.string(withFormat: "HH:mm"))")
                self.datePicker.date = date
            }, onError: { error in
                print("SurveyScheduleViewController - Error refreshing user: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
    
    private func sendUserSettings() {
        self.repository.sendUserSettings(seconds: self.datePicker.date.getSecondsSinceMidnight())
            .addProgress()
            .subscribe(onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
}
