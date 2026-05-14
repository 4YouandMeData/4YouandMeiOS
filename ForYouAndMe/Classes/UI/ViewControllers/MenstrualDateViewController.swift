//
//  MenstrualDateViewController.swift
//  ForYouAndMe
//
//  FUAM-2935 — Step 2 of menstrual cycle wizard. Shown only when the user
//  selects "Earlier than today" on Step 1.
//

import UIKit
import PureLayout

protocol MenstrualDateViewControllerDelegate: AnyObject {
    func menstrualDateViewController(_ vc: MenstrualDateViewController, didSelect date: Date)
}

final class MenstrualDateViewController: UIViewController {

    var alert: Alert?
    weak var delegate: MenstrualDateViewControllerDelegate?

    private let variant: FlowVariant
    private let navigator: AppNavigator

    private let scrollStackView = ScrollStackView(axis: .vertical,
                                                  horizontalInset: Constants.Style.DefaultHorizontalMargins)

    private let dateRow: UIControl = {
        let ctrl = UIControl()
        ctrl.backgroundColor = .clear
        ctrl.tintColor = ColorPalette.color(withType: .primary)
        return ctrl
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
        let now = Date()
        dp.maximumDate = now
        // 6 months before today
        if let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: now) {
            dp.minimumDate = sixMonthsAgo
        }
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

    init(variant: FlowVariant) {
        self.variant = variant
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

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let titleString = NSAttributedString(
            string: StringsProvider.string(forKey: .menstrualStepDateTitle),
            attributes: titleAttrs)
        scrollStackView.stackView.addLabel(attributedString: titleString, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 36)

        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let messageString = NSAttributedString(
            string: StringsProvider.string(forKey: .menstrualStepDateMessage),
            attributes: messageAttrs)
        scrollStackView.stackView.addLabel(attributedString: messageString, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 44)

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
        delegate?.menstrualDateViewController(self, didSelect: date)
    }
}
