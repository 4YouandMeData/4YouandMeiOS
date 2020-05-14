//
//  PhoneVerificationViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 08/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout
import RxSwift

public class PhoneVerificationViewController: UIViewController {
    
    private enum LabelInteractions: CaseIterable {
        case privacyPolicy
        case termsOfService
        
        var text: String {
            switch self {
            case .privacyPolicy: return StringsProvider.string(forKey: .phoneVerificationLegalPrivacyPolicy)
            case .termsOfService: return StringsProvider.string(forKey: .phoneVerificationLegalTermsOfService)
            }
        }
        
        func handleNavigation(navigator: AppNavigator, presenter: UIViewController) {
            switch self {
            case .privacyPolicy: navigator.showPrivacyPolicy(presenter: presenter)
            case .termsOfService: navigator.showTermsOfService(presenter: presenter)
            }
        }
    }
    
    static private let confirmButtonBottomInset: CGFloat = 16.0
    
    // KeyboardNotificationProvider
    var showNotification: NSObjectProtocol?
    var hideNotification: NSObjectProtocol?
    
    private let navigator: AppNavigator
    private let repository: Repository
    
    private let disposeBag = DisposeBag()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonLight), for: .normal)
        button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        return button
    }()
    private lazy var phoneNumberView: PhoneNumberView = PhoneNumberView()
    
    private lazy var legalNoteView: UIView = {
        let horizontalStackView = UIStackView()
        horizontalStackView.axis = .horizontal
        horizontalStackView.spacing = 8.0
        
        let checkboxContainerView = UIView()
        checkboxContainerView.addSubview(self.legalNoteCheckBoxView)
        self.legalNoteCheckBoxView.autoPinEdge(toSuperviewEdge: .leading)
        self.legalNoteCheckBoxView.autoPinEdge(toSuperviewEdge: .trailing)
        self.legalNoteCheckBoxView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        self.legalNoteCheckBoxView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        self.legalNoteCheckBoxView.autoAlignAxis(toSuperviewAxis: .horizontal)
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.lineBreakMode = .byWordWrapping
        self.legalLabelInteractionManager = UILabelInteractionManager(withLabel: label,
                                                                      text: StringsProvider.string(forKey: .phoneVerificationLegal),
                                                                      lineSpacing: 5.0,
                                                                      normalTextFont: FontPalette.font(withSize: 13),
                                                                      normalTextColor: ColorPalette.color(withType: .secondaryText),
                                                                      interactableFont: FontPalette.font(withSize: 13, type: .bold),
                                                                      interactableColor: ColorPalette.color(withType: .secondaryText),
                                                                      interactableUnderline: true,
                                                                      interactionCallback: self.handleLabelInteractions,
                                                                      interactableStrings: LabelInteractions.allCases.map { $0.text })
        
        horizontalStackView.addArrangedSubview(checkboxContainerView)
        horizontalStackView.addArrangedSubview(label)
        
        let containerView = UIView()
        containerView.addSubview(horizontalStackView)
        horizontalStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 16))
        return containerView
    }()
    
    private let legalNoteCheckBoxView: GenericCheckboxView = GenericCheckboxView(isDefaultChecked: false)
    
    private var confirmButtonBottomConstraint: NSLayoutConstraint?
    private var legalLabelInteractionManager: UILabelInteractionManager?
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addGradientView(GradientView(type: .defaultBackground))
        
        // ScrollView
        self.view.addSubview(self.scrollView)
        self.scrollView.autoPinEdgesToSuperviewSafeArea()
        
        // StackView
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.scrollView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: Self.confirmButtonBottomInset,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        stackView.addBlankSpace(space: 16.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationTitle),
                           font: FontPalette.font(withSize: 30.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 60.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationBody),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left,
                           lineSpacing: Constants.Style.DefaultBodyLineSpacing)
        stackView.addBlankSpace(space: 48.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationNumberDescription),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 24.0)
        stackView.addArrangedSubview(self.phoneNumberView)
        stackView.addBlankSpace(space: 40.0)
        stackView.addArrangedSubview(self.legalNoteView)
        
        // Confirm button
        self.view.addSubview(self.confirmButton)
        self.confirmButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        self.confirmButton.autoPinEdge(toSuperviewSafeArea: .bottom,
                                       withInset: Self.confirmButtonBottomInset,
                                       relation: .greaterThanOrEqual)
        NSLayoutConstraint.autoSetPriority(UILayoutPriority(rawValue: 999)) { [weak self] in
            guard let self = self else { return }
            self.confirmButtonBottomConstraint = self.confirmButton.autoPinEdge(toSuperviewEdge: .bottom,
                                                                                withInset: Self.confirmButtonBottomInset)
        }
        
        // Initialization
        self.phoneNumberView.isValid
            .subscribe(onNext: { [weak self] _ in self?.updateUI() })
            .disposed(by: self.disposeBag)
        
        self.legalNoteCheckBoxView.isCheckedSubject
            .subscribe(onNext: { [weak self] _ in self?.updateUI() })
            .disposed(by: self.disposeBag)
        
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.darkStyle)
        self.addCustomBackButton(withImage: ImagePalette.image(withName: .backButton))
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        
        self.registerKeyboardNotification()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.deRegisterKeyboardNotification()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.legalLabelInteractionManager?.refreshLabel()
    }
    
    // MARK: Actions
    
    @objc private func countryCodeButtonPressed() {
        // TODO: Country Code button behaviour
        print("TODO: Country Code button behaviour")
    }
    
    @objc private func confirmButtonPressed() {
        self.repository.submitPhoneNumber(phoneNumber: self.phoneNumberView.text)
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.view.endEditing(true)
                self.navigator.showCodeValidation(presenter: self)
            }, onError: { [weak self] error in
                guard let self = self else { return }
                // TODO: Handle error in UI
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        guard let numberValid = try? self.phoneNumberView.isValid.value() else {
            assertionFailure("Unexpected throw")
            return
        }
        self.confirmButton.isEnabled = numberValid && self.legalNoteCheckBoxView.isChecked
    }
    
    private func handleLabelInteractions(_ text: String) {
        if let interaction = LabelInteractions.allCases.first(where: { $0.text == text }) {
            interaction.handleNavigation(navigator: self.navigator, presenter: self)
        } else {
            assertionFailure("Unhandled legal interaction")
        }
    }
}

// MARK: - KeyboardNotificationProvider

extension PhoneVerificationViewController: KeyboardNotificationProvider {
    func keyboardWillShow(height: CGFloat, duration: TimeInterval, options: UIView.AnimationOptions) {
        let newBottomInset = self.confirmButton.frame.height + height + Self.confirmButtonBottomInset
        self.scrollView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: newBottomInset, right: 0.0)
        self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.confirmButtonBottomConstraint?.constant = -Self.confirmButtonBottomInset - height
            self.view.layoutIfNeeded()
            })
    }
    
    func keyboardWillHide(duration: TimeInterval, options: UIView.AnimationOptions) {
        self.scrollView.contentInset = UIEdgeInsets.zero
        self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.confirmButtonBottomConstraint?.constant = -Self.confirmButtonBottomInset
            self.view.layoutIfNeeded()
            })
    }
}
