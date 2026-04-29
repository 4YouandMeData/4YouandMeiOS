//
//  MenstrualExplainViewController.swift
//  ForYouAndMe
//
//  FUAM-2935 — Optional sub-step shown only when the user picks
//  "Let me explain" on the period-related question. Captures a free-text
//  explanation; tapping Next then leads to the standard final note step.
//

import UIKit
import PureLayout

protocol MenstrualExplainViewControllerDelegate: AnyObject {
    func menstrualExplainViewController(_ vc: MenstrualExplainViewController, didFinishWith explanation: String?)
}

final class MenstrualExplainViewController: UIViewController, UITextViewDelegate {

    private static let characterLimit: Int = 2500

    var alert: Alert?
    weak var delegate: MenstrualExplainViewControllerDelegate?

    private let variant: FlowVariant
    private let navigator: AppNavigator

    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.textColor = ColorPalette.color(withType: .primaryText)
        tv.backgroundColor = .clear
        tv.layer.borderColor = ColorPalette.color(withType: .primary).cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = 8
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.delegate = self
        return tv
    }()

    private lazy var placeholderLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .menstrualStepExplainPlaceholder)
        lbl.textColor = .placeholderText
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.numberOfLines = 0
        return lbl
    }()

    private lazy var footerView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        view.setButtonText(StringsProvider.string(forKey: .menstrualNextButton))
        view.setButtonEnabled(enabled: true)
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
        setupKeyboardDismissGesture()
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
                string: StringsProvider.string(forKey: .menstrualStepExplainTitle),
                attributes: titleAttrs),
            numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 24)

        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        scrollStackView.stackView.addLabel(
            attributedString: NSAttributedString(
                string: StringsProvider.string(forKey: .menstrualStepExplainMessage),
                attributes: messageAttrs),
            numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 24)

        scrollStackView.stackView.addArrangedSubview(textView)
        textView.autoSetDimension(.height, toSize: 200)

        textView.addSubview(placeholderLabel)
        placeholderLabel.autoPinEdge(.top, to: .top, of: textView, withOffset: 16)
        placeholderLabel.autoPinEdge(.leading, to: .leading, of: textView, withOffset: 16)
        placeholderLabel.autoPinEdge(.trailing, to: .trailing, of: textView, withOffset: -16)

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func setupKeyboardDismissGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func nextTapped() {
        view.endEditing(true)
        let trimmed = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let explanation: String? = trimmed.isEmpty ? nil : trimmed
        delegate?.menstrualExplainViewController(self, didFinishWith: explanation)
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updated = currentText.replacingCharacters(in: stringRange, with: text)
        return updated.count <= Self.characterLimit
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}
