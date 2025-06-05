//
//  NoticedIntroViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 05/06/25.
//

import UIKit
import PureLayout

protocol NoticedIntroViewControllerDelegate: AnyObject {
    func noticedIntroViewControllerDidSelectYes(_ vc: NoticedIntroViewController)
    func noticedIntroViewControllerDidSelectNo(_ vc: NoticedIntroViewController)
    func noticedIntroViewControllerDidCancel(_ vc: NoticedIntroViewController)
}

class NoticedIntroViewController: UIViewController {
    
    weak var delegate: NoticedIntroViewControllerDelegate?
    private let dynamicMessage: String
    
    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )
    
    private let closeButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .closeButton),
            style: .plain,
            target: nil,
            action: #selector(closeButtonPressed)
        )
        item.tintColor = ColorPalette.color(withType: .primaryText)
        return item
    }()
    
    private let infoButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .infoMessage),
            style: .plain,
            target: nil,
            action: #selector(infoButtonPressed)
        )
        item.tintColor = ColorPalette.color(withType: .primary)
        return item
    }()
    
    /// OptionButton configured for “Yes”
    private lazy var yesButton: OptionButton = {
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(StringsProvider.string(forKey: .noticedStepOneFirstButton), for: .normal)
        return btn
    }()
    
    /// OptionButton configured for “No”
    private lazy var noButton: OptionButton = {
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(StringsProvider.string(forKey: .noticedStepOneSecondButton), for: .normal)
        return btn
    }()
    
    /// Footer “Next” button (disabled until user selects Yes/No)
    private lazy var footerView: GenericButtonView = {
        let gv = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        gv.setButtonText(StringsProvider.string(forKey: .noticedStepNextButton))
        gv.setButtonEnabled(enabled: false)
        gv.addTarget(target: self, action: #selector(nextTapped))
        return gv
    }()
    
    /// `true` if user tapped Yes, `false` if user tapped No, `nil` if no selection yet
    private var selectedYes: Bool? {
        didSet {
            // Enable “Next” only after either Yes or No is selected
            footerView.setButtonEnabled(enabled: selectedYes != nil)
        }
    }
    
    init(dynamicMessage: String) {
        self.dynamicMessage = dynamicMessage
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupNavigationBar()
        setupLayout()
        setupActions()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        closeButton.target = self
        infoButton.target = self
        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = infoButton
    }
    
    private func setupLayout() {
        
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(
            with: .zero,
            excludingEdge: .bottom
        )
        
        let header = NSAttributedString(
            string: StringsProvider.string(forKey: .noticedStepOneTitle),
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
            withText: StringsProvider.string(forKey: .noticedStepOneMessage),
            fontStyle: .paragraph,
            color: ColorPalette.color(withType: .primaryText)
        )
        scrollStack.stackView.addBlankSpace(space: 44)
        
        scrollStack.stackView.addArrangedSubview(yesButton)
        scrollStack.stackView.addBlankSpace(space: 16)
        yesButton.autoSetDimension(.height, toSize: 60)
        
        scrollStack.stackView.addArrangedSubview(noButton)
        scrollStack.stackView.addBlankSpace(space: 16)
        noButton.autoSetDimension(.height, toSize: 60)
        
        // 6) Footer “Next”
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(
            with: .zero,
            excludingEdge: .top
        )
        scrollStack.scrollView.autoPinEdge(
            .bottom,
            to: .top,
            of: footerView
        )
    }
    
    private func setupActions() {
        // Both “Yes” and “No” can be selected
        yesButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        noButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
    }
    
    // MARK: – Actions
    
    /// Called when either yesButton or noButton is tapped
    @objc private func optionTapped(_ sender: OptionButton) {
        // Deselect both, then select only the tapped button
        yesButton.isSelected = (sender == yesButton)
        noButton.isSelected = (sender == noButton)
        
        // Store the choice: true = Yes, false = No
        selectedYes = (sender == yesButton)
    }
    
    /// Called when the user taps “Next”
    @objc private func nextTapped() {
        guard let yes = selectedYes else { return }
        if yes {
            delegate?.noticedIntroViewControllerDidSelectYes(self)
        } else {
            delegate?.noticedIntroViewControllerDidSelectNo(self)
        }
    }
    
    @objc private func closeButtonPressed() {
        delegate?.noticedIntroViewControllerDidCancel(self)
    }
    
    @objc private func infoButtonPressed() {
        
    }
}
