//
//  MenstrualWhenViewController.swift
//  ForYouAndMe
//
//  FUAM-2935 — Step 1 of menstrual cycle wizard.
//

import UIKit
import PureLayout

protocol MenstrualWhenViewControllerDelegate: AnyObject {
    func menstrualWhenViewController(_ vc: MenstrualWhenViewController,
                                     didSelect when: MenstrualWhenViewController.WhenChoice)
    func menstrualWhenViewControllerDidCancel(_ vc: MenstrualWhenViewController)
}

final class MenstrualWhenViewController: UIViewController {

    enum WhenChoice {
        case today
        case earlier
    }

    var alert: Alert?
    weak var delegate: MenstrualWhenViewControllerDelegate?

    private let variant: FlowVariant
    private let navigator: AppNavigator

    private lazy var closeButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .closeButton),
            style: .plain,
            target: self,
            action: #selector(closeButtonPressed))
        item.tintColor = ColorPalette.color(withType: .primaryText)
        return item
    }()

    private lazy var todayButton: OptionButton = makeOptionButton(
        title: StringsProvider.string(forKey: .menstrualStepWhenTodayButton),
        choice: .today)
    private lazy var earlierButton: OptionButton = makeOptionButton(
        title: StringsProvider.string(forKey: .menstrualStepWhenEarlierButton),
        choice: .earlier)

    private var selectedChoice: WhenChoice? {
        didSet { footerView.setButtonEnabled(enabled: selectedChoice != nil) }
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
        // First step is the modal root: a back button has nowhere to pop to.
        // Show a close button that dismisses the wizard, mirroring EatenTypeViewController.
        navigationItem.leftBarButtonItem = closeButton
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
            string: StringsProvider.string(forKey: .menstrualStepWhenTitle),
            attributes: titleAttrs)
        scrollStackView.stackView.addLabel(attributedString: titleString, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 36)

        if let body = alert?.body {
            scrollStackView.stackView.addLabel(withText: body,
                                               fontStyle: .paragraph,
                                               color: ColorPalette.color(withType: .primaryText))
            scrollStackView.stackView.addBlankSpace(space: 40)
        }

        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let messageString = NSAttributedString(
            string: StringsProvider.string(forKey: .menstrualStepWhenMessage),
            attributes: messageAttrs)
        scrollStackView.stackView.addLabel(attributedString: messageString, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 44)

        scrollStackView.stackView.addArrangedSubview(todayButton)
        scrollStackView.stackView.addBlankSpace(space: 16)
        scrollStackView.stackView.addArrangedSubview(earlierButton)

        earlierButton.autoSetDimension(.height, toSize: 54)
        todayButton.autoMatch(.height, to: .height, of: earlierButton)

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func makeOptionButton(title: String, choice: WhenChoice) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(title, for: .normal)
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        btn.tag = (choice == .today) ? 0 : 1
        return btn
    }

    @objc private func optionTapped(_ sender: OptionButton) {
        todayButton.isSelected = (sender == todayButton)
        earlierButton.isSelected = (sender == earlierButton)
        selectedChoice = (sender == todayButton) ? .today : .earlier
    }

    @objc private func nextTapped() {
        guard let choice = selectedChoice else { return }
        delegate?.menstrualWhenViewController(self, didSelect: choice)
    }

    @objc private func closeButtonPressed() {
        delegate?.menstrualWhenViewControllerDidCancel(self)
    }
}
