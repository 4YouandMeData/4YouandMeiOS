//
//  UserSignatureViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/06/2020.
//

import Foundation
import UberSignature

protocol UserSignatureCoordinator {
    func onUserSignatureCreated(signatureImage: UIImage)
    func onUserSignatureBackButtonPressed()
}

class UserSignatureViewController: UIViewController {
    
    private let coordinator: UserSignatureCoordinator
    
    private lazy var signatureViewController: SignatureDrawingViewController = {
        let controller = SignatureDrawingViewController()
        controller.delegate = self
        return controller
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .onboardingUserSignaturePlaceholder),
                                                         fontStyle: .paragraph,
                                                         color: ColorPalette.color(withType: .fourthText).applyAlpha(0.2),
                                                         textAlignment: .left)
        return label
    }()
    
    private lazy var signatureContainerView: UIView = {
        let view = UIView()
        
        view.clipsToBounds = true
        
        let bottomLineView = UIView()
        bottomLineView.autoSetDimension(.height, toSize: 1.0)
        bottomLineView.backgroundColor = ColorPalette.color(withType: .primaryText).applyAlpha(0.2)
        
        view.addSubview(bottomLineView)
        bottomLineView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 40.0, right: 0.0),
                                          excludingEdge: .top)
        
        view.addSubview(self.placeholderLabel)
        self.placeholderLabel.autoPinEdge(toSuperviewEdge: .leading)
        self.placeholderLabel.autoPinEdge(toSuperviewEdge: .trailing)
        bottomLineView.autoPinEdge(.top, to: .bottom, of: self.placeholderLabel, withOffset: 12.0)
        
        return view
    }()
    
    private lazy var clearButtonView: UIView = {
        let view = UIView()
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8.0
        view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0))
        
        let imageView = UIImageView(image: ImagePalette.image(withName: .clearButton))
        let imageContainerView = UIView()
        imageContainerView.addSubview(imageView)
        imageView.autoPinEdge(toSuperviewEdge: .leading)
        imageView.autoPinEdge(toSuperviewEdge: .trailing)
        imageView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        imageView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        imageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        stackView.addArrangedSubview(imageContainerView)
        
        let label = UILabel()
        label.attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .onboardingUserSignatureClear),
                                                         fontStyle: .header3,
                                                         color: ColorPalette.color(withType: .primaryText).applyAlpha(0.61))
        
        let labelContainerView = UIView()
        labelContainerView.addSubview(label)
        label.autoPinEdge(toSuperviewEdge: .leading)
        label.autoPinEdge(toSuperviewEdge: .trailing)
        label.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        label.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        label.autoAlignAxis(toSuperviewAxis: .horizontal)
        stackView.addArrangedSubview(labelContainerView)
        
        let button = UIButton()
        button.addTarget(self, action: #selector(self.clearButtonPressed), for: .touchUpInside)
        view.addSubview(button)
        NSLayoutConstraint.autoSetPriority(UILayoutPriority(rawValue: 200)) {
            button.autoSetContentHuggingPriority(for: .horizontal)
            button.autoSetContentHuggingPriority(for: .vertical)
        }
        button.autoPinEdgesToSuperviewEdges()
        return view
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    init(coordinator: UserSignatureCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        scrollStackView.stackView.addBlankSpace(space: 30.0)
        scrollStackView.stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserSignatureTitle),
                                           fontStyle: .title,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        scrollStackView.stackView.addBlankSpace(space: 30.0)
        scrollStackView.stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserSignatureBody),
                                           fontStyle: .paragraph,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        scrollStackView.stackView.addBlankSpace(space: 8.0)
        
        // Signature View
        scrollStackView.stackView.addArrangedSubview(self.signatureContainerView)
        self.signatureContainerView.autoSetDimension(.height, toSize: 162.0)
        self.addChild(self.signatureViewController)
        self.signatureContainerView.addSubview(self.signatureViewController.view)
        self.signatureViewController.view.autoPinEdgesToSuperviewEdges()
        self.signatureViewController.didMove(toParent: self)
        
        // Clear Button View
        let clearButtonContainerView = UIView()
        clearButtonContainerView.addSubview(self.clearButtonView)
        self.clearButtonView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .leading)
        scrollStackView.stackView.addArrangedSubview(clearButtonContainerView)
        
        // Confirm Button View
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: self.confirmButtonView)
        
        // Initialization
        self.updateUI(signatureIsEmpty: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        guard let signatureImage = self.signatureViewController.fullSignatureImage else {
            assertionFailure("Missing signature image")
            return
        }
        self.coordinator.onUserSignatureCreated(signatureImage: signatureImage)
    }
    
    @objc private func clearButtonPressed() {
        self.signatureViewController.reset()
        self.updateUI(signatureIsEmpty: true)
    }
    
    @objc override func customBackButtonPressed() {
        self.coordinator.onUserSignatureBackButtonPressed()
    }
    
    // MARK: Private Methods
    
    private func updateUI(signatureIsEmpty: Bool) {
        self.confirmButtonView.setButtonEnabled(enabled: false == signatureIsEmpty)
        self.placeholderLabel.isHidden = false == signatureIsEmpty
    }
}

extension UserSignatureViewController: SignatureDrawingViewControllerDelegate {
    func signatureDrawingViewControllerIsEmptyDidChange(controller: SignatureDrawingViewController, isEmpty: Bool) {
        self.updateUI(signatureIsEmpty: isEmpty)
    }
}
