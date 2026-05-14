//
//  MenstrualPeriodRelatedViewController.swift
//  ForYouAndMe
//
//  FUAM-2935 — Step 4 of menstrual cycle wizard. Determines the bleeding
//  field (yes/no/other) via the user's answer.
//

import UIKit
import PureLayout

protocol MenstrualPeriodRelatedViewControllerDelegate: AnyObject {
    func menstrualPeriodRelatedViewController(_ vc: MenstrualPeriodRelatedViewController,
                                              didSelect related: MenstrualPeriodRelated)
}

final class MenstrualPeriodRelatedViewController: UIViewController {

    var alert: Alert?
    weak var delegate: MenstrualPeriodRelatedViewControllerDelegate?

    private let variant: FlowVariant
    private let navigator: AppNavigator

    private var optionButtons: [MenstrualPeriodRelated: OptionButton] = [:]

    private var selectedRelated: MenstrualPeriodRelated? {
        didSet { footerView.setButtonEnabled(enabled: selectedRelated != nil) }
    }

    private lazy var footerView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        view.setButtonText(StringsProvider.string(forKey: .menstrualNextButton))
        view.setButtonEnabled(enabled: false)
        view.addTarget(target: self, action: #selector(nextTapped))
        return view
    }()

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        addCustomBackButton()
    }

    private func setupLayout() {
        let scrollStackView = ScrollStackView(axis: .vertical,
                                              horizontalInset: Constants.Style.DefaultHorizontalMargins)
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        scrollStackView.stackView.addLabel(
            attributedString: NSAttributedString(
                string: StringsProvider.string(forKey: .menstrualStepPeriodTitle),
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
                string: StringsProvider.string(forKey: .menstrualStepPeriodMessage),
                attributes: messageAttrs),
            numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 44)

        let order: [(MenstrualPeriodRelated, StringKey)] = [
            (.yes, .menstrualStepPeriodYes),
            (.no, .menstrualStepPeriodNo),
            (.notSure, .menstrualStepPeriodNotSure),
            (.letMeExplain, .menstrualStepPeriodLetMeExplain)
        ]
        for (idx, item) in order.enumerated() {
            let btn = makeOptionButton(title: StringsProvider.string(forKey: item.1), related: item.0)
            optionButtons[item.0] = btn
            scrollStackView.stackView.addArrangedSubview(btn)
            btn.autoSetDimension(.height, toSize: 54)
            if idx < order.count - 1 {
                scrollStackView.stackView.addBlankSpace(space: 16)
            }
        }

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func makeOptionButton(title: String, related: MenstrualPeriodRelated) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(title, for: .normal)
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func optionTapped(_ sender: OptionButton) {
        for (related, btn) in optionButtons {
            btn.isSelected = (btn == sender)
            if btn == sender { selectedRelated = related }
        }
    }

    @objc private func nextTapped() {
        guard let related = selectedRelated else { return }
        delegate?.menstrualPeriodRelatedViewController(self, didSelect: related)
    }
}
