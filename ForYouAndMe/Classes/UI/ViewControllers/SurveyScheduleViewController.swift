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
    private let disposeBag: DisposeBag = DisposeBag()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false),
                                     horizontalInset: 0,
                                     height: Constants.Style.DefaultTextButtonHeight)
        view.setButtonText(StringsProvider.string(forKey: .setupLaterConfirmButton))
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    init(withTitle title: String) {
        self.titleString = title
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
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
        self.scrollStackView.stackView.addArrangedSubview(datePicker)
        self.scrollStackView.stackView.addBlankSpace(space: 20)
        self.scrollStackView.stackView.addArrangedSubview(UIView())
        
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdges(toSuperviewMarginsExcludingEdge: .top)
        self.confirmButtonView.autoPinEdge(.top, to: .bottom, of: self.scrollStackView)
    }
    
    @objc func handleDatePicker(_ datePicker: UIDatePicker) {
        print("\(datePicker.date)")
//        self.delegate?.answerDidChange(self.surveyQuestion, answer: datePicker.date.string(withFormat: dateFormat))
    }
    
    @objc private func confirmButtonPressed() {
//        self.coordinator.onConfirmButtonPressed(popupViewController: self)
    }
}
