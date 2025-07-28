//
//  PreferencesViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 26/06/25.
//

import UIKit
import RxSwift

public class PreferencesViewController: UIViewController {
    
    private static let IntegrationItemHeight: CGFloat = 72.0
    
    private var titleString: String
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    private var notificationSwitch = UISwitch()
    private var hourLabel = UILabel()
    private let hourPicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "en_GB")
        picker.minuteInterval = 60
        return picker
    }()

    private let disposeBag = DisposeBag()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
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
        self.notificationSwitch.isOn = false
        self.hourPicker.isEnabled = false
        
        self.refreshUI()
    }
    
    private func refreshUI() {
        self.scrollStackView.stackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        
        hourPicker.addTarget(self, action: #selector(didChangePreferredHour), for: .valueChanged)

        let stackView = scrollStackView.stackView
        stackView.addLabel(withText: StringsProvider.string(forKey: .preferencesTitlePage),
                           fontStyle: .paragraphBold,
                           color: ColorPalette.color(withType: .primaryText),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 8.0)
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 0, isVertical: false)
        
        self.scrollStackView.stackView.addBlankSpace(space: 20.0)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = StringsProvider.string(forKey: .preferenceToggle)
        descriptionLabel.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        descriptionLabel.textColor = ColorPalette.color(withType: .primaryText)
        descriptionLabel.numberOfLines = 0
            
        let switchStack = UIStackView(arrangedSubviews: [descriptionLabel, notificationSwitch])
        switchStack.axis = .horizontal
        switchStack.distribution = .equalSpacing
        switchStack.alignment = .center
            
        stackView.addArrangedSubview(switchStack)
        switchStack.autoSetDimension(.height, toSize: 40.0)

        stackView.addBlankSpace(space: 20.0)

        hourLabel.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        hourLabel.textColor = ColorPalette.color(withType: .primaryText)
        hourLabel.text = StringsProvider.string(forKey: .preferencesHour)
            
        let timePickerStack = UIStackView(arrangedSubviews: [hourLabel, hourPicker])
        timePickerStack.axis = .horizontal
        timePickerStack.alignment = .center
        timePickerStack.distribution = .equalSpacing

        hourPicker.datePickerMode = .time
        hourPicker.preferredDatePickerStyle = .compact

        stackView.addArrangedSubview(timePickerStack)
        timePickerStack.autoSetDimension(.height, toSize: 40.0)

        stackView.addBlankSpace(space: 40.0)

        notificationSwitch.addTarget(self, action: #selector(didToggleNotificationSwitch), for: .valueChanged)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.openPreferences.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        
        self.repository.getUserSettings()
            .addProgress()
            .subscribe(onSuccess: { [weak self] userSettings in
                guard let self = self else { return }
                guard let hourValue = userSettings.notificationTime else {
                    self.refreshUI()
                    return
                }
                
                var components = DateComponents()
                components.hour = hourValue
                components.minute = 0
                let calendar = Calendar.current
                if let date = calendar.date(from: components) {
                    self.hourPicker.isEnabled = true
                    self.hourPicker.date = date
                    self.notificationSwitch.isOn = true
                }
                            
                self.refreshUI()
            }, onFailure: { error in
                print("SurveyScheduleViewController - Error refreshing user: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
    
    private func updatePreferredHourOnServer(_ sender: UIDatePicker?) {
        if let datePicker = sender {

            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour], from: datePicker.date)
            if let hour = components.hour {
                
                let newDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: datePicker.date)!
                datePicker.setDate(newDate, animated: false)
                
                self.repository.sendUserSettings(seconds: nil, notificationTime: hour)
                    .subscribe(onSuccess: {
                        print("Notification time updated successfully")
                    }, onFailure: { error in
                        print("Error updating notification time: \(error.localizedDescription)")
                    }).disposed(by: self.disposeBag)
            }
        } else {
            self.repository.sendUserSettings(seconds: nil, notificationTime: nil)
                .subscribe(onSuccess: {
                    print("Notification time updated successfully")
                }, onFailure: { error in
                    print("Error updating notification time: \(error.localizedDescription)")
                }).disposed(by: self.disposeBag)
        }
    }
    
    // MARK: Actions
    
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func didToggleNotificationSwitch(_ sender: UISwitch) {
        self.hourPicker.isEnabled = sender.isOn
        self.updatePreferredHourOnServer(nil)
    }
    
    @objc private func didChangePreferredHour(_ sender: UIDatePicker) {
        guard self.notificationSwitch.isOn else { return }
        self.updatePreferredHourOnServer(sender)
    }
}
