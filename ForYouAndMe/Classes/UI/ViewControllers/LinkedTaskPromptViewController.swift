//
//  LinkedTaskPromptViewController.swift
//  ForYouAndMe
//
//  Custom modal prompting the user to start a follow-up task (typically a
//  Survey) returned by the Quick Activity submission response. See FUAM-3037.
//

import UIKit
import PureLayout

final class LinkedTaskPromptViewController: UIViewController {

    struct Data {
        let title: String
        let body: String
        let confirmButtonText: String
        let cancelButtonText: String
    }

    private let data: Data
    private let onConfirm: () -> Void
    private let onCancel: () -> Void

    init(data: Data,
         onConfirm: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.data = data
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overCurrentContext
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = ColorPalette.overlayColor

        let panel = UIView()
        panel.backgroundColor = ColorPalette.color(withType: .secondary)
        panel.layer.cornerRadius = 16.0
        self.view.addSubview(panel)
        panel.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        panel.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        panel.autoAlignAxis(toSuperviewAxis: .horizontal)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16.0
        panel.addSubview(stack)
        stack.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0, left: 20.0, bottom: 20.0, right: 20.0))

        let closeButton = UIButton(type: .system)
        closeButton.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        closeButton.tintColor = ColorPalette.color(withType: .primaryText)
        closeButton.addTarget(self, action: #selector(self.cancelTapped), for: .touchUpInside)
        let closeContainer = UIView()
        closeContainer.addSubview(closeButton)
        closeButton.autoPinEdge(toSuperviewEdge: .leading)
        closeButton.autoPinEdge(toSuperviewEdge: .top)
        closeButton.autoPinEdge(toSuperviewEdge: .bottom)
        closeButton.autoSetDimensions(to: CGSize(width: 28, height: 28))
        stack.addArrangedSubview(closeContainer)

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        titleLabel.textColor = ColorPalette.color(withType: .primaryText)
        titleLabel.text = self.data.title
        stack.addArrangedSubview(titleLabel)

        let bodyLabel = UILabel()
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        bodyLabel.attributedText = NSAttributedString.create(
            withText: self.data.body,
            attributedTextStyle: AttributedTextStyle(
                fontStyle: .paragraph,
                colorType: .primaryText,
                textAlignment: .center
            )
        )
        stack.addArrangedSubview(bodyLabel)

        let buttonsRow = UIStackView()
        buttonsRow.axis = .horizontal
        buttonsRow.distribution = .fillEqually
        buttonsRow.spacing = 12.0
        stack.setCustomSpacing(24.0, after: bodyLabel)
        stack.addArrangedSubview(buttonsRow)

        let confirmButton = self.makePillButton(
            text: self.data.confirmButtonText,
            backgroundColor: ColorPalette.color(withType: .primary),
            titleColorType: .secondaryText,
            action: #selector(self.confirmTapped)
        )
        let cancelButton = self.makePillButton(
            text: self.data.cancelButtonText,
            backgroundColor: ColorPalette.color(withType: .inactive),
            titleColorType: .secondaryText,
            action: #selector(self.cancelTapped)
        )
        buttonsRow.addArrangedSubview(confirmButton)
        buttonsRow.addArrangedSubview(cancelButton)
    }

    private func makePillButton(text: String,
                                backgroundColor: UIColor,
                                titleColorType: ColorType,
                                action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        let height: CGFloat = 48.0
        button.autoSetDimension(.height, toSize: height)
        button.layer.cornerRadius = height / 2.0
        button.backgroundColor = backgroundColor
        let attributed = NSAttributedString.create(
            withText: text,
            attributedTextStyle: AttributedTextStyle(
                fontStyle: .header2,
                colorType: titleColorType,
                textAlignment: .center
            )
        )
        button.setAttributedTitle(attributed, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func confirmTapped() {
        self.dismiss(animated: true) { [weak self] in
            self?.onConfirm()
        }
    }

    @objc private func cancelTapped() {
        self.dismiss(animated: true) { [weak self] in
            self?.onCancel()
        }
    }
}
