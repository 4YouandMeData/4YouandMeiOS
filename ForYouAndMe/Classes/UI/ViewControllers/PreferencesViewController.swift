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
    private lazy var hourPickerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(ColorPalette.color(withType: .primaryText), for: .normal)
        button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        button.contentHorizontalAlignment = .right
        button.addTarget(self, action: #selector(showHourPicker), for: .touchUpInside)
        return button
    }()
    private var hourPickerView: UIPickerView?
    private var hourItems: [String] = []
    private var selectedHour: Int = 0
    private var currentAlertController: UIAlertController?

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
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondaryBackgroungColor)
        
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
        self.hourPickerButton.isEnabled = false
        
        self.generateHourItems()
        self.refreshUI()
    }
    
    // MARK: - Helper Methods
    
    private func generateHourItems() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // Get locale-appropriate hour format
        if let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current) {
            formatter.dateFormat = dateFormat
        } else {
            // Fallback: check if locale uses 12-hour format
            let testFormatter = DateFormatter()
            testFormatter.locale = Locale.current
            if let testFormat = DateFormatter.dateFormat(fromTemplate: "hma", options: 0, locale: Locale.current) {
                testFormatter.dateFormat = testFormat
                let testDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: calendar.startOfDay(for: Date()))!
                let testString = testFormatter.string(from: testDate)
                if testString.contains("AM") || testString.contains("PM") || testString.contains("am") || testString.contains("pm") {
                    formatter.dateFormat = "h a"
                } else {
                    formatter.dateFormat = "HH"
                }
            } else {
                formatter.dateFormat = "HH"
            }
        }
        
        self.hourItems = []
        let baseDate = calendar.startOfDay(for: Date())
        
        for hour in 0..<24 {
            if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) {
                let displayText = formatter.string(from: date)
                self.hourItems.append(displayText)
            }
        }
    }
    
    private func updateHourButtonTitle() {
        if selectedHour < hourItems.count {
            hourPickerButton.setTitle(hourItems[selectedHour], for: .normal)
        }
    }
    
    @objc private func showHourPicker() {
        guard hourPickerButton.isEnabled else { return }
        
        let alertController = UIAlertController(title: nil, message: "\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        self.currentAlertController = alertController
        
        let pickerFrame = CGRect(x: 0, y: 0, width: alertController.view.bounds.width - 20, height: 216)
        let picker = UIPickerView(frame: pickerFrame)
        picker.delegate = self
        picker.dataSource = self
        picker.selectRow(selectedHour, inComponent: 0, animated: false)
        self.hourPickerView = picker
        
        alertController.view.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.centerXAnchor.constraint(equalTo: alertController.view.centerXAnchor),
            picker.topAnchor.constraint(equalTo: alertController.view.topAnchor, constant: 50)
        ])
        
        // For iPad
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = hourPickerButton
            popover.sourceRect = hourPickerButton.bounds
        }
        
        self.present(alertController, animated: true)
    }
    
    private func dismissPickerAndUpdate() {
        guard let alertController = self.currentAlertController else { return }
        alertController.dismiss(animated: true) { [weak self] in
            self?.currentAlertController = nil
            self?.hourPickerView = nil
        }
    }
    
    private func refreshUI() {
        self.scrollStackView.stackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })

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
        
        updateHourButtonTitle()
            
        let timePickerStack = UIStackView(arrangedSubviews: [hourLabel, hourPickerButton])
        timePickerStack.axis = .horizontal
        timePickerStack.alignment = .center
        timePickerStack.distribution = .equalSpacing

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
                
                self.selectedHour = hourValue
                self.hourPickerButton.isEnabled = true
                self.notificationSwitch.isOn = true
                self.updateHourButtonTitle()
                self.refreshUI()
            }, onFailure: { error in
                print("SurveyScheduleViewController - Error refreshing user: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
    
    private func updatePreferredHourOnServer() {
        let hour = self.selectedHour
        self.repository.sendUserSettings(seconds: nil, notificationTime: hour)
            .subscribe(onSuccess: {
                print("Notification time updated successfully")
            }, onFailure: { error in
                print("Error updating notification time: \(error.localizedDescription)")
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: Actions
    
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func didToggleNotificationSwitch(_ sender: UISwitch) {
        self.hourPickerButton.isEnabled = sender.isOn
        
        if sender.isOn {
            // If no hour is selected, set current hour as default
            if self.selectedHour == 0 && hourItems.count > 0 {
                let calendar = Calendar.current
                let currentHour = calendar.component(.hour, from: Date())
                self.selectedHour = currentHour
                self.updateHourButtonTitle()
            }
            self.updatePreferredHourOnServer()
        } else {
            // When switch is turned off, reset to hour 0 and send nil to disable notifications
            self.selectedHour = 0
            self.updateHourButtonTitle()
            self.repository.sendUserSettings(seconds: nil, notificationTime: nil)
                .subscribe(onSuccess: {
                    print("Notification time updated successfully")
                }, onFailure: { error in
                    print("Error updating notification time: \(error.localizedDescription)")
                }).disposed(by: self.disposeBag)
        }
    }
}

// MARK: - UIPickerViewDataSource & UIPickerViewDelegate

extension PreferencesViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return hourItems.count
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return hourItems[row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Update selected hour when picker stops
        self.selectedHour = row
        self.updateHourButtonTitle()
        self.updatePreferredHourOnServer()
        
        // Dismiss the alert after a short delay to allow the picker animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.dismissPickerAndUpdate()
        }
    }
}
