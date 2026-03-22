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
        let button = UIButton(type: .custom)
        button.setTitleColor(ColorPalette.color(withType: .primaryText), for: .normal)
        button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        button.contentHorizontalAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.backgroundColor = ColorPalette.color(withType: .fourth)
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(showHourPicker), for: .touchUpInside)
        button.addTarget(self, action: #selector(pickerButtonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(pickerButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }()
    private var hourItems: [String] = []
    private var selectedHour: Int = 0
    private var previousSelectedHour: Int = 0

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
        self.hourPickerButton.alpha = 0.5
        
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

        self.previousSelectedHour = self.selectedHour

        let pickerVC = HourPickerViewController()
        pickerVC.hourItems = self.hourItems
        pickerVC.selectedRow = self.selectedHour
        pickerVC.onDone = { [weak self] row in
            guard let self = self else { return }
            self.selectedHour = row
            self.updateHourButtonTitle()
            self.updatePreferredHourOnServer()
        }
        pickerVC.onCancel = { [weak self] in
            guard let self = self else { return }
            self.selectedHour = self.previousSelectedHour
            self.updateHourButtonTitle()
        }
        self.present(pickerVC, animated: true)
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
                self.hourPickerButton.alpha = 1.0
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
        self.hourPickerButton.alpha = sender.isOn ? 1.0 : 0.5

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

    @objc private func pickerButtonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.hourPickerButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    @objc private func pickerButtonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.hourPickerButton.transform = .identity
        }
    }
}

// MARK: - HourPickerViewController

private class HourPickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    var hourItems: [String] = []
    var selectedRow: Int = 0
    var onDone: ((Int) -> Void)?
    var onCancel: (() -> Void)?

    fileprivate let containerView = UIView()
    private let pickerView = UIPickerView()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Dimmed backdrop
        view.backgroundColor = .clear
        let dimmedView = UIView()
        dimmedView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.addSubview(dimmedView)
        dimmedView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dimmedView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmedView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        dimmedView.addGestureRecognizer(tapGesture)

        // Container
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Toolbar
        let toolbar = UIToolbar()
        toolbar.isTranslucent = false
        toolbar.barTintColor = .systemBackground
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        toolbar.items = [cancelButton, flexSpace, doneButton]
        containerView.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        // Separator
        let separator = UIView()
        separator.backgroundColor = UIColor.separator
        containerView.addSubview(separator)
        separator.translatesAutoresizingMaskIntoConstraints = false

        // Picker
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.selectRow(selectedRow, inComponent: 0, animated: false)
        containerView.addSubview(pickerView)
        pickerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: containerView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),

            separator.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            pickerView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            pickerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pickerView.heightAnchor.constraint(equalToConstant: 216),
            pickerView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    @objc private func doneTapped() {
        let row = pickerView.selectedRow(inComponent: 0)
        dismiss(animated: true) { [weak self] in
            self?.onDone?(row)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }

    // MARK: - UIPickerViewDataSource & UIPickerViewDelegate

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        hourItems.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        hourItems[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedRow = row
    }
}

// MARK: - HourPickerViewController Transition

extension HourPickerViewController: UIViewControllerTransitioningDelegate {

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        HourPickerTransition(presenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        HourPickerTransition(presenting: false)
    }
}

private class HourPickerTransition: NSObject, UIViewControllerAnimatedTransitioning {

    private let presenting: Bool

    init(presenting: Bool) {
        self.presenting = presenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.3 }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if presenting {
            guard let toView = transitionContext.view(forKey: .to),
                  let toVC = transitionContext.viewController(forKey: .to) as? HourPickerViewController else { return }
            let container = transitionContext.containerView
            toView.frame = transitionContext.finalFrame(for: toVC)
            container.addSubview(toView)

            toView.layoutIfNeeded()
            let sheetHeight = toVC.containerView.frame.height
            toVC.containerView.transform = CGAffineTransform(translationX: 0, y: sheetHeight)
            toView.backgroundColor = .clear

            UIView.animate(withDuration: transitionDuration(using: transitionContext),
                           delay: 0,
                           options: .curveEaseOut,
                           animations: {
                toVC.containerView.transform = .identity
                toView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
            }, completion: { finished in
                transitionContext.completeTransition(finished)
            })
        } else {
            guard let fromView = transitionContext.view(forKey: .from),
                  let fromVC = transitionContext.viewController(forKey: .from) as? HourPickerViewController else { return }
            let sheetHeight = fromVC.containerView.frame.height

            UIView.animate(withDuration: transitionDuration(using: transitionContext),
                           delay: 0,
                           options: .curveEaseIn,
                           animations: {
                fromVC.containerView.transform = CGAffineTransform(translationX: 0, y: sheetHeight)
                fromView.backgroundColor = .clear
            }, completion: { finished in
                fromView.removeFromSuperview()
                transitionContext.completeTransition(finished)
            })
        }
    }
}
