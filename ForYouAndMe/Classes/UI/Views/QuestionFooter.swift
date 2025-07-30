//
//  QuestionFooter.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 29/07/25.
//

final class QuestionFooterView: UIView {
    
    public lazy var textFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .default, styleCategory: .secondary)
        view.textField.attributedPlaceholder = NSAttributedString(
            string: StringsProvider.string(forKey: .questionOtherHint),
            attributes: [
                .foregroundColor: ColorPalette.color(withType: .secondaryText).applyAlpha(0.5)
            ]
        )
        return view
    }()

    init() {
        super.init(frame: .zero)

        let label = UILabel()
        label.numberOfLines = 0
        label.setHTMLFromString(
            StringsProvider.string(forKey: .questionFooter),
            font: FontPalette.fontStyleData(forStyle: .paragraph).font,
            color: "#FFFFFF")

        let stackView = UIStackView(arrangedSubviews: [label, textFieldView])
        stackView.axis = .vertical
        stackView.spacing = 16

        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
