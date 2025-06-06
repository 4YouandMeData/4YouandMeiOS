//
//  EatenIntroViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 05/06/25.
//

import UIKit
import PureLayout

protocol EatenIntroViewControllerDelegate: AnyObject {
    func eatenIntroViewControllerDidSelectYes(_ vc: EatenIntroViewController)
    func eatenIntroViewControllerDidSelectNo(_ vc: EatenIntroViewController)
    func eatenIntroViewControllerDidCancel(_ vc: EatenIntroViewController)
}

class EatenIntroViewController: UIViewController {
    
    // MARK: – UI Elements
    
    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )
    
    private lazy var yesButton: OptionButton = makeOptionButton(text: StringsProvider.string(forKey: .noticedStepFourFirstButton))
    private lazy var noButton: OptionButton  = makeOptionButton(text: StringsProvider.string(forKey: .noticedStepFourSecondButton))
    
    private lazy var footerView: GenericButtonView = {
        let gv = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        gv.setButtonText(StringsProvider.string(forKey: .noticedStepNextButton))
        gv.setButtonEnabled(enabled: false)
        gv.addTarget(target: self, action: #selector(nextTapped))
        return gv
    }()
    
    // MARK: – State
    
    private var didSelectYes: Bool? {
        didSet {
            footerView.setButtonEnabled(enabled: didSelectYes != nil)
        }
    }
    
    weak var delegate: EatenIntroViewControllerDelegate?
    
    // MARK: – Init
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: – Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupNavBar()
        setupLayout()
        setupActions()
    }
    
    // MARK: – Setup
    
    private func setupNavBar() {
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        addCustomBackButton()
    }
    
    private func setupLayout() {

        let header = NSAttributedString(
            string: StringsProvider.string(forKey: .noticedStepFourTitle),
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = .center
                    return paragraph
                }()
            ]
        )
        scrollStack.stackView.addLabel(attributedString: header, numberOfLines: 1)
        scrollStack.stackView.addBlankSpace(space: 36)
        
        scrollStack.stackView.addLabel(
            withText: StringsProvider.string(forKey: .noticedStepFourMessage),
            fontStyle: .paragraph,
            color: ColorPalette.color(withType: .primaryText)
        )
        scrollStack.stackView.addBlankSpace(space: 44)
        
        // Bottoni Yes / No
        [yesButton, noButton].forEach { btn in
            scrollStack.stackView.addArrangedSubview(btn)
            scrollStack.stackView.addBlankSpace(space: 16)
            btn.autoSetDimension(.height, toSize: 60)
        }
        
        // Aggiungo scrollStack sulla view
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        // Footer “Next”
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStack.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }
    
    private func makeOptionButton(text: String) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(text, for: .normal)
        return btn
    }
    
    private func setupActions() {
        yesButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        noButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
    }
    
    // MARK: – Actions
    
    @objc private func optionTapped(_ sender: OptionButton) {
        yesButton.isSelected = (sender == yesButton)
        noButton.isSelected  = (sender == noButton)
        didSelectYes = (sender == yesButton)
    }
    
    @objc private func nextTapped() {
        guard let ate = didSelectYes else { return }
        if ate {
            delegate?.eatenIntroViewControllerDidSelectYes(self)
        } else {
            delegate?.eatenIntroViewControllerDidSelectNo(self)
        }
    }
    
    @objc private func closeTapped() {
        delegate?.eatenIntroViewControllerDidCancel(self)
    }
}
