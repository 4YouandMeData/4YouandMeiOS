//
//  MenstrualFlowViewController.swift
//  ForYouAndMe
//
//  FUAM-2935 — Step 3 of menstrual cycle wizard. Pick the flow amount.
//

import UIKit
import PureLayout

protocol MenstrualFlowViewControllerDelegate: AnyObject {
    func menstrualFlowViewController(_ vc: MenstrualFlowViewController,
                                     didSelect flow: MenstrualFlowAmount)
}

final class MenstrualFlowViewController: UIViewController {

    var alert: Alert?
    weak var delegate: MenstrualFlowViewControllerDelegate?

    private let variant: FlowVariant
    private let navigator: AppNavigator

    private var optionButtons: [MenstrualFlowAmount: OptionButton] = [:]

    private var selectedFlow: MenstrualFlowAmount? {
        didSet { footerView.setButtonEnabled(enabled: selectedFlow != nil) }
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
        let titleString = NSAttributedString(
            string: StringsProvider.string(forKey: .menstrualStepFlowTitle),
            attributes: titleAttrs)
        scrollStackView.stackView.addLabel(attributedString: titleString, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 36)

        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let messageString = NSAttributedString(
            string: StringsProvider.string(forKey: .menstrualStepFlowMessage),
            attributes: messageAttrs)
        scrollStackView.stackView.addLabel(attributedString: messageString, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 44)

        let order: [(MenstrualFlowAmount, StringKey)] = [
            (.spotting, .menstrualStepFlowSpotting),
            (.light, .menstrualStepFlowLight),
            (.moderate, .menstrualStepFlowModerate),
            (.heavy, .menstrualStepFlowHeavy),
            (.veryHeavy, .menstrualStepFlowVeryHeavy)
        ]
        for (idx, item) in order.enumerated() {
            let btn = makeOptionButton(title: StringsProvider.string(forKey: item.1), flow: item.0)
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

    private func makeOptionButton(title: String, flow: MenstrualFlowAmount) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .horizontal(spacing: 16, horizontalAlignment: .leading)
        let img = ImagePalette.templateImage(withName: flow.iconName)?
            .withRenderingMode(.alwaysTemplate)
        btn.setImage(img, for: .normal)
        btn.tintColor = ColorPalette.color(withType: .primary)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func optionTapped(_ sender: OptionButton) {
        for (flow, btn) in optionButtons {
            btn.isSelected = (btn == sender)
            if btn == sender { selectedFlow = flow }
        }
    }

    @objc private func nextTapped() {
        guard let flow = selectedFlow else { return }
        delegate?.menstrualFlowViewController(self, didSelect: flow)
    }
}
