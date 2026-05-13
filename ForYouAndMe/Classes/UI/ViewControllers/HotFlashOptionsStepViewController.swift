//
//  HotFlashOptionsStepViewController.swift
//  ForYouAndMe
//
//  FUAM-3247: reusable step screen for the Heat Up FAB additional questions
//  (Severity, Duration, Symptoms, Sleep onset). The step is parametrized by
//  title/message/options + selection mode so the coordinator can drive four
//  near-identical screens without duplicating layout code.
//

import UIKit
import PureLayout

protocol HotFlashOptionsStepViewControllerDelegate: AnyObject {
    /// Fired when the user taps Next with a valid selection. `selected` is
    /// the list of option codes (i.e. the BE-bound keys, not the labels).
    func hotFlashOptionsStepViewController(_ vc: HotFlashOptionsStepViewController,
                                           didConfirm selected: [String])
    /// Fired when the user dismisses the whole flow from this step.
    func hotFlashOptionsStepViewControllerDidCancel(_ vc: HotFlashOptionsStepViewController)
}

class HotFlashOptionsStepViewController: UIViewController {

    /// One row in the option list. `code` is what the BE will receive,
    /// `label` is what the user reads. The coordinator builds these from
    /// `StringsProvider` keys so the labels are study-configurable.
    struct Option {
        let code: String
        let label: String
    }

    enum SelectionMode {
        /// Multi-select; Next is enabled when at least one option is checked.
        case multi
        /// Single-select; Next is enabled when one option is selected.
        case single
    }

    weak var delegate: HotFlashOptionsStepViewControllerDelegate?

    private let stepTitle: String
    private let stepMessage: String?
    private let options: [Option]
    private let mode: SelectionMode
    private let nextButtonText: String

    private var selectedCodes: Set<String> = [] {
        didSet { footerView.setButtonEnabled(enabled: !selectedCodes.isEmpty) }
    }

    private var buttonsByCode: [String: OptionButton] = [:]

    private lazy var closeButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .closeButton),
            style: .plain,
            target: self,
            action: #selector(closeButtonPressed)
        )
        item.tintColor = ColorPalette.color(withType: .primaryText)
        return item
    }()

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(nextButtonText)
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(self.nextTapped))
        return buttonView
    }()

    init(title: String,
         message: String?,
         options: [Option],
         mode: SelectionMode,
         nextButtonText: String) {
        self.stepTitle = title
        self.stepMessage = message
        self.options = options
        self.mode = mode
        self.nextButtonText = nextButtonText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        // Close (X) on the right mirrors the rest of the Hot Flash flow; the
        // back arrow is supplied automatically by the nav controller stack.
        self.navigationItem.rightBarButtonItem = self.closeButton
    }

    private func setupLayout() {
        let scrollStackView = ScrollStackView(axis: .vertical,
                                              horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        scrollStackView.stackView.addLabel(
            attributedString: NSAttributedString(string: stepTitle, attributes: titleAttrs),
            numberOfLines: 0
        )

        if let message = stepMessage, !message.isEmpty {
            scrollStackView.stackView.addBlankSpace(space: 24)
            let messageAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: paragraphStyle
            ]
            scrollStackView.stackView.addLabel(
                attributedString: NSAttributedString(string: message, attributes: messageAttrs),
                numberOfLines: 0
            )
        }

        scrollStackView.stackView.addBlankSpace(space: 36)

        for option in options {
            let btn = OptionButton()
            btn.layoutStyle = .textLeft(padding: 16)
            btn.setTitle(option.label, for: .normal)
            btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
            btn.autoSetDimension(.height, toSize: 54)
            scrollStackView.stackView.addArrangedSubview(btn)
            scrollStackView.stackView.addBlankSpace(space: 12)
            buttonsByCode[option.code] = btn
        }

        self.view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    @objc private func optionTapped(_ sender: OptionButton) {
        guard let (tappedCode, _) = buttonsByCode.first(where: { $0.value === sender }) else { return }

        switch mode {
        case .single:
            // Exclusive selection: deselect everything, then select the tap.
            for (_, btn) in buttonsByCode { btn.isSelected = false }
            sender.isSelected = true
            selectedCodes = [tappedCode]
        case .multi:
            // Toggle the tapped row, keep the rest as-is.
            let nowSelected = !sender.isSelected
            sender.isSelected = nowSelected
            if nowSelected {
                selectedCodes.insert(tappedCode)
            } else {
                selectedCodes.remove(tappedCode)
            }
        }
    }

    @objc private func nextTapped() {
        guard !selectedCodes.isEmpty else { return }
        // Preserve original `options` order in the emitted payload so the
        // BE sees stable orderings irrespective of tap order.
        let ordered = options.map(\.code).filter { selectedCodes.contains($0) }
        delegate?.hotFlashOptionsStepViewController(self, didConfirm: ordered)
    }

    @objc private func closeButtonPressed() {
        delegate?.hotFlashOptionsStepViewControllerDidCancel(self)
    }
}
