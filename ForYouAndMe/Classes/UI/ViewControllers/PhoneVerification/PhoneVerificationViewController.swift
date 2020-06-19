//
//  PhoneVerificationViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 08/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout
import TPKeyboardAvoiding
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
    
    private let navigator: AppNavigator
    private let repository: Repository
    
    private let disposeBag = DisposeBag()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonSmallSecondary), for: .normal)
        button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var phoneNumberView: PhoneNumberView = PhoneNumberView(presenter: self,
                                                                        allowedCountryCodes: CountryCodeProvider.countryCodes)
    
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
        let fontStyleData = FontPalette.fontStyleData(forStyle: .header3)
        self.legalLabelInteractionManager = UILabelInteractionManager(withLabel: label,
                                                                      text: StringsProvider.string(forKey: .phoneVerificationLegal),
                                                                      lineSpacing: fontStyleData.lineSpacing,
                                                                      normalTextFont: fontStyleData.font,
                                                                      normalTextColor: ColorPalette.color(withType: .secondaryText),
                                                                      interactableFont: fontStyleData.font,
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
        
        self.view.addGradientView(GradientView(type: .primaryBackground))
        
        // ScrollView
        self.view.addSubview(self.scrollView)
        self.scrollView.autoPinEdgesToSuperviewSafeArea()
        
        // StackView
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.scrollView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 16.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .phoneVerificationTitle),
                           fontStyle: .title,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 30.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .phoneVerificationBody),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 48.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .phoneVerificationNumberDescription),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 24.0)
        stackView.addArrangedSubview(self.phoneNumberView)
        stackView.addBlankSpace(space: 8.0)
        stackView.addArrangedSubview(self.legalNoteView)
        stackView.addBlankSpace(space: 16.0)
        
        // Bottom View
        let confirmButtonContainerView = UIView()
        confirmButtonContainerView.addSubview(self.confirmButton)
        self.confirmButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0),
                                                        excludingEdge: .leading)
        stackView.addArrangedSubview(confirmButtonContainerView)
        
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
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.primaryStyle)
        self.addCustomBackButton()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.legalLabelInteractionManager?.refreshLabel()
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        self.navigator.pushProgressHUD()
        self.repository.submitPhoneNumber(phoneNumber: self.phoneNumberView.fullNumber)
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                self.phoneNumberView.clearError(clearErrorText: true)
                self.view.endEditing(true)
                self.navigator.showCodeValidation(countryCode: self.phoneNumberView.countryCode,
                                                  phoneNumber: self.phoneNumberView.text,
                                                  presenter: self)
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                if let error = error as? RepositoryError, case .missingPhoneNumber = error {
                    self.phoneNumberView.setError(errorText: error.localizedDescription)
                } else {
                    self.navigator.handleError(error: error, presenter: self)
                }
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        self.confirmButton.isEnabled = self.phoneNumberView.isValid.value && self.legalNoteCheckBoxView.isChecked
    }
    
    private func handleLabelInteractions(_ text: String) {
        if let interaction = LabelInteractions.allCases.first(where: { $0.text == text }) {
            interaction.handleNavigation(navigator: self.navigator, presenter: self)
        } else {
            assertionFailure("Unhandled legal interaction")
        }
    }
}
