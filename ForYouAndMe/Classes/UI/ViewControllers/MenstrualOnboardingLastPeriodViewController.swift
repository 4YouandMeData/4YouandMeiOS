//
//  MenstrualOnboardingLastPeriodViewController.swift
//  ForYouAndMe
//
//  FUAM-2937 — Inline onboarding step 2: "When was the date of the start of
//  your last period?". Shown only when step 1 is yes/unsure (skipped on no).
//

import UIKit
import PureLayout

protocol MenstrualOnboardingLastPeriodViewControllerDelegate: AnyObject {
    func menstrualOnboardingLastPeriodViewController(_ vc: MenstrualOnboardingLastPeriodViewController,
                                                     didSelect date: Date)
}

final class MenstrualOnboardingLastPeriodViewController: UIViewController {

    weak var delegate: MenstrualOnboardingLastPeriodViewControllerDelegate?

    private let navigator: AppNavigator

    private let scrollStackView = ScrollStackView(axis: .vertical,
                                                  horizontalInset: Constants.Style.DefaultHorizontalMargins)

    private let dateRow: UIControl = {
        let ctrl = UIControl()
        ctrl.backgroundColor = .clear
        ctrl.tintColor = ColorPalette.color(withType: .primary)
        return ctrl
    }()

    private let dateFieldLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .footnote)
        lbl.textColor = ColorPalette.color(withType: .primary)
        lbl.text = StringsProvider.string(forKey: .menstrualOnboardingLastPeriodFieldLabel)
        return lbl
    }()

    private let dateValueLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }()

    private let dateIcon: UIImageView = {
        let img = ImagePalette.templateImage(withName: .clockIcon)
        let iv = UIImageView(image: img)
        iv.tintColor = ColorPalette.color(withType: .primary)
        return iv
    }()

    private let underline: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .primary)
        return view
    }()

    private lazy var datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .inline
        dp.tintColor = ColorPalette.color(withType: .primary)
        // BE schema (FUAM-2929) requires a past date — clamp at today.
        dp.maximumDate = Date()
        return dp
    }()

    private lazy var footerView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        view.setButtonText(StringsProvider.string(forKey: .menstrualNextButton))
        view.setButtonEnabled(enabled: false)
        view.addTarget(target: self, action: #selector(nextTapped))
        return view
    }()

    private var chosenDate: Date? {
        didSet {
            footerView.setButtonEnabled(enabled: chosenDate != nil)
            if let date = chosenDate {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = .none
                dateValueLabel.text = fmt.string(from: date)
            }
        }
    }

    init() {
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        addCustomBackButton()
    }

    private func setupLayout() {
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        // Mirror MenstrualWhenViewController.setupLayout: Title (header2 bold)
        // + 36pt + Message (17pt) + 60pt + Date field + footer.
        // Title reuses `menstrualDetailTitle` ("Menstrual Flow Tracking").
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        scrollStackView.stackView.addLabel(
            attributedString: NSAttributedString(
                string: StringsProvider.string(forKey: .menstrualDetailTitle),
                attributes: titleAttrs),
            numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 36)

        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        scrollStackView.stackView.addLabel(
            attributedString: NSAttributedString(
                string: StringsProvider.string(forKey: .menstrualOnboardingLastPeriodTitle),
                attributes: messageAttrs),
            numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 60)

        scrollStackView.stackView.addArrangedSubview(dateFieldLabel)
        scrollStackView.stackView.addBlankSpace(space: 4)

        scrollStackView.stackView.addArrangedSubview(dateRow)
        dateRow.autoSetDimension(.height, toSize: 44)
        dateRow.addSubview(dateValueLabel)
        dateRow.addSubview(dateIcon)
        dateRow.addSubview(underline)

        dateValueLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        dateValueLabel.autoPinEdge(.leading, to: .leading, of: dateRow)

        dateIcon.autoAlignAxis(.horizontal, toSameAxisOf: dateValueLabel)
        dateIcon.autoPinEdge(.trailing, to: .trailing, of: dateRow)
        dateIcon.autoSetDimensions(to: CGSize(width: 15, height: 15))

        underline.autoPinEdge(.bottom, to: .bottom, of: dateRow)
        underline.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        underline.autoSetDimension(.height, toSize: 1)

        scrollStackView.stackView.addArrangedSubview(datePicker)
        datePicker.isHidden = true

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func setupActions() {
        dateRow.addTarget(self, action: #selector(rowTapped), for: .touchUpInside)
        datePicker.addTarget(self, action: #selector(pickerChanged(_:)), for: .valueChanged)
    }

    @objc private func rowTapped() {
        datePicker.isHidden.toggle()
        if !datePicker.isHidden {
            pickerChanged(datePicker)
        }
    }

    @objc private func pickerChanged(_ dp: UIDatePicker) {
        chosenDate = dp.date
    }

    @objc private func nextTapped() {
        guard let date = chosenDate else { return }
        delegate?.menstrualOnboardingLastPeriodViewController(self, didSelect: date)
    }
}
