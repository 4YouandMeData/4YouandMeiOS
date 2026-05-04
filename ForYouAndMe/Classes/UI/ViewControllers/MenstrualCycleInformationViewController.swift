//
//  MenstrualCycleInformationViewController.swift
//  ForYouAndMe
//
//  FUAM-2936 — Settings panel for the menstrual cycle baseline. Pre-populates
//  from the API on appear and auto-saves on every change. The date row is
//  disabled and grayed out when the dropdown is set to "No"; switching to
//  "No" also clears any previously-stored date for data hygiene.
//

import UIKit
import RxSwift
import PureLayout

final class MenstrualCycleInformationViewController: UIViewController {

    private let repository: Repository = Services.shared.repository
    private let navigator: AppNavigator = Services.shared.navigator
    private let analytics: AnalyticsService = Services.shared.analytics
    private let disposeBag = DisposeBag()

    private var hadPeriod3Mo: MenstrualHadPeriod3Mo?
    private var lastPeriodDate: Date?

    // MARK: - UI

    private let questionPeriod3MoLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        lbl.numberOfLines = 0
        lbl.text = StringsProvider.string(forKey: .menstrualOnboardingPeriod3MoTitle)
        return lbl
    }()

    private lazy var period3MoButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .preferredFont(forTextStyle: .body)
        btn.contentHorizontalAlignment = .right
        let chevron = UIImage(systemName: "chevron.up.chevron.down")
        btn.setImage(chevron, for: .normal)
        btn.semanticContentAttribute = .forceRightToLeft
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        btn.tintColor = ColorPalette.color(withType: .primary)
        btn.setTitleColor(ColorPalette.color(withType: .primary), for: .normal)
        btn.showsMenuAsPrimaryAction = true
        return btn
    }()

    private let questionLastPeriodLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        lbl.numberOfLines = 0
        lbl.text = StringsProvider.string(forKey: .menstrualOnboardingLastPeriodTitle)
        return lbl
    }()

    private let lastPeriodValueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .preferredFont(forTextStyle: .body)
        btn.setTitleColor(ColorPalette.color(withType: .primaryText), for: .normal)
        btn.contentHorizontalAlignment = .right
        btn.backgroundColor = UIColor(hexString: Constants.Style.FormBackgroundColor)
        btn.layer.cornerRadius = 14
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return btn
    }()

    private lazy var lastPeriodPicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .inline
        dp.tintColor = ColorPalette.color(withType: .primary)
        // BE schema requires the date to be in the past.
        dp.maximumDate = Date()
        return dp
    }()

    private let lastPeriodSection: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondaryBackgroungColor)
        setupLayout()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Use the green InfoDetailHeaderView (not the system nav bar) to match
        // the rest of the Settings panels (Preferences, Permissions, etc.).
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        loadFromBackend()
    }

    // MARK: - Layout

    private func setupLayout() {
        let headerView = InfoDetailHeaderView(withTitle: StringsProvider.string(forKey: .menstrualSettingsTitle))
        view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        headerView.backButton.addTarget(self, action: #selector(backButtonPressed), for: .touchUpInside)

        // ScrollStackView with generous horizontal padding (matches Preferences).
        let stackContainer = ScrollStackView(axis: .vertical,
                                             horizontalInset: Constants.Style.DefaultHorizontalMargins)
        view.addSubview(stackContainer)
        stackContainer.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        stackContainer.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 32)

        // Q1 row: question + dropdown
        let q1Row = UIStackView()
        q1Row.axis = .horizontal
        q1Row.alignment = .center
        q1Row.distribution = .fill
        q1Row.spacing = 16
        q1Row.addArrangedSubview(questionPeriod3MoLabel)
        q1Row.addArrangedSubview(period3MoButton)
        period3MoButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        period3MoButton.setContentHuggingPriority(.required, for: .horizontal)
        stackContainer.stackView.addArrangedSubview(q1Row)

        stackContainer.stackView.addBlankSpace(space: 40)

        // Q2 section: question + value pill button + inline picker
        let q2Row = UIStackView()
        q2Row.axis = .horizontal
        q2Row.alignment = .center
        q2Row.distribution = .fill
        q2Row.spacing = 16
        q2Row.addArrangedSubview(questionLastPeriodLabel)
        q2Row.addArrangedSubview(lastPeriodValueButton)
        lastPeriodValueButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        lastPeriodValueButton.setContentHuggingPriority(.required, for: .horizontal)

        lastPeriodSection.addArrangedSubview(q2Row)
        lastPeriodSection.addBlankSpace(space: 16)
        lastPeriodSection.addArrangedSubview(lastPeriodPicker)
        lastPeriodPicker.isHidden = true

        stackContainer.stackView.addArrangedSubview(lastPeriodSection)
    }

    @objc private func backButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    private func setupActions() {
        lastPeriodValueButton.addTarget(self, action: #selector(toggleLastPeriodPicker), for: .touchUpInside)
        lastPeriodPicker.addTarget(self, action: #selector(lastPeriodPickerChanged(_:)), for: .valueChanged)
        period3MoButton.menu = makePeriod3MoMenu()
    }

    // MARK: - Data

    private func loadFromBackend() {
        self.repository.getUserSettings()
            .addProgress()
            .subscribe(onSuccess: { [weak self] settings in
                guard let self = self else { return }
                self.hadPeriod3Mo = settings.menstrualHadPeriod3Mo
                self.lastPeriodDate = settings.menstrualLastPeriodDate
                self.refreshUI()
                // Rebuild the menu so the current selection is reflected via state.
                self.period3MoButton.menu = self.makePeriod3MoMenu()
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }

    private func refreshUI() {
        // Period-3-mo dropdown title
        if let value = hadPeriod3Mo {
            period3MoButton.setTitle(StringsProvider.string(forKey: value.localizedKey), for: .normal)
        } else {
            period3MoButton.setTitle(StringsProvider.string(forKey: .menstrualSettingsSelectPlaceholder),
                                     for: .normal)
        }

        // Date row + picker
        let dateAvailable = (hadPeriod3Mo != .no)
        questionLastPeriodLabel.alpha = dateAvailable ? 1.0 : 0.4
        lastPeriodValueButton.alpha = dateAvailable ? 1.0 : 0.4
        lastPeriodValueButton.isEnabled = dateAvailable
        if !dateAvailable {
            lastPeriodPicker.isHidden = true
        }

        if let date = lastPeriodDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            lastPeriodValueButton.setTitle(fmt.string(from: date), for: .normal)
            lastPeriodPicker.date = date
        } else {
            lastPeriodValueButton.setTitle(StringsProvider.string(forKey: .menstrualSettingsSelectPlaceholder),
                                           for: .normal)
        }
    }

    private func saveCurrentValuesToBackend() {
        self.repository
            .sendMenstrualUserSettings(hadPeriod3Mo: hadPeriod3Mo,
                                       lastPeriodDate: lastPeriodDate)
            .addProgress()
            .subscribe(onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }

    // MARK: - Actions

    private func makePeriod3MoMenu() -> UIMenu {
        let order: [(MenstrualHadPeriod3Mo, StringKey)] = [
            (.yes, .menstrualOnboardingPeriod3MoYes),
            (.no, .menstrualOnboardingPeriod3MoNo),
            (.unsure, .menstrualOnboardingPeriod3MoUnsure)
        ]
        let actions: [UIAction] = order.map { (value, key) in
            let isCurrent = (value == self.hadPeriod3Mo)
            return UIAction(title: StringsProvider.string(forKey: key),
                            state: isCurrent ? .on : .off) { [weak self] _ in
                self?.handlePeriod3MoChange(value)
            }
        }
        return UIMenu(title: StringsProvider.string(forKey: .menstrualSettingsSelectPlaceholder),
                      children: actions)
    }

    private func handlePeriod3MoChange(_ value: MenstrualHadPeriod3Mo) {
        let previousValue = hadPeriod3Mo
        hadPeriod3Mo = value
        // FUAM-2937 / FUAM-2936: when the user switches to "no" we wipe the
        // stored date to keep BE state coherent (no period → no last date).
        if value == .no {
            lastPeriodDate = nil
        }
        refreshUI()
        period3MoButton.menu = makePeriod3MoMenu()
        if value != previousValue {
            saveCurrentValuesToBackend()
        }
    }

    @objc private func toggleLastPeriodPicker() {
        guard hadPeriod3Mo != .no else { return }
        lastPeriodPicker.isHidden.toggle()
        if !lastPeriodPicker.isHidden, lastPeriodDate == nil {
            // Seed the model with the picker's default so the user sees a value.
            lastPeriodPickerChanged(lastPeriodPicker)
        }
    }

    @objc private func lastPeriodPickerChanged(_ dp: UIDatePicker) {
        lastPeriodDate = dp.date
        refreshUI()
        saveCurrentValuesToBackend()
    }
}

// MARK: - Localization keys

private extension MenstrualHadPeriod3Mo {
    var localizedKey: StringKey {
        switch self {
        case .yes:    return .menstrualOnboardingPeriod3MoYes
        case .no:     return .menstrualOnboardingPeriod3MoNo
        case .unsure: return .menstrualOnboardingPeriod3MoUnsure
        }
    }
}
