//
//  CodeValidationViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout
import TPKeyboardAvoiding
import RxSwift

public class CodeValidationViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private let disposeBag = DisposeBag()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonSecondary), for: .normal)
        button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        button.autoSetDimensions(to: CGSize(width: 50.0, height: 50.0))
        return button
    }()
    
    private lazy var resendCodeButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(self.resendCodeButtonPressed), for: .touchUpInside)
        let attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .phoneVerificationCodeResend),
                                                       fontStyle: .header3,
                                                       colorType: .secondaryText,
                                                       textAlignment: .left,
                                                       underlined: true)
        button.setAttributedTitle(attributedText, for: .normal)
        return button
    }()
    
    private lazy var phoneNumberView: PhoneNumberView = {
        let phoneNumberView = PhoneNumberView(presenter: self,
                                              allowedCountryCodes: CountryCodeProvider.countryCodes,
                                              styleCategory: .secondary)
        let button = UIButton()
        phoneNumberView.addSubview(button)
        button.autoPinEdgesToSuperviewEdges()
        button.addTarget(self, action: #selector(self.phoneNumberPressed), for: .touchUpInside)
        return phoneNumberView
    }()
    
    private lazy var codeTextFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .numberPad, styleCategory: .secondary)
        view.textField.textContentType = .oneTimeCode
        view.validationCallback = { text -> Bool in
            return text.count == Constants.Misc.PhoneValidationCodeDigitCount
        }
        view.maxCharacters = Constants.Misc.PhoneValidationCodeDigitCount
        return view
    }()
    
    init(countryCode: String, phoneNumber: String) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
        self.phoneNumberView.countryCode = countryCode
        self.phoneNumberView.text = phoneNumber
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .active)
        
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
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .phoneVerificationCodeTitle),
                           fontStyle: .title,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 30.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .phoneVerificationCodeBody),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 48.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .phoneVerificationWrongNumber),
                           fontStyle: .paragraph,
                           color: ColorPalette.color(withType: .secondaryText).applyAlpha(0.5),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 24.0)
        stackView.addArrangedSubview(self.phoneNumberView)
        stackView.addLabel(withText: StringsProvider.string(forKey: .phoneVerificationCodeDescription),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 24.0)
        stackView.addArrangedSubview(self.codeTextFieldView)
        
        // Bottom View
        let bottomView = UIView()
        bottomView.addSubview(self.confirmButton)
        
        self.confirmButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0),
                                                        excludingEdge: .leading)
        bottomView.addSubview(self.resendCodeButton)
        self.resendCodeButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0),
                                                        excludingEdge: .trailing)
        stackView.addArrangedSubview(bottomView)
        
        // Initialization
        self.codeTextFieldView.isValid
            .subscribe(onNext: { [weak self] _ in self?.updateUI() })
            .disposed(by: self.disposeBag)
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.otpValidation.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.active(hidden: false).style)
        self.addCustomBackButton()
    }
    
    // MARK: Actions
    
    @objc private func resendCodeButtonPressed() {
        self.repository.submitPhoneNumber(phoneNumber: self.phoneNumberView.fullNumber)
            .addProgress()
            .subscribe(onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    @objc private func confirmButtonPressed() {
        self.repository.verifyPhoneNumber(phoneNumber: self.phoneNumberView.fullNumber, validationCode: self.codeTextFieldView.text)
            .addProgress()
            .subscribe(onSuccess: { [weak self] user in
                guard let self = self else { return }
                self.analytics.track(event: .setUserID("\(user.id)"))
                self.analytics.track(event: .userRegistration(self.phoneNumberView.countryCode))
                self.codeTextFieldView.clearError(clearErrorText: true)
                self.view.endEditing(true)
                self.navigator.onLoginCompleted(presenter: self)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                if let error = error as? RepositoryError, case .wrongPhoneValidationCode = error {
                    self.codeTextFieldView.setError(errorText: error.localizedDescription)
                } else {
                    self.navigator.handleError(error: error, presenter: self)
                }
            }).disposed(by: self.disposeBag)
    }
    
    @objc private func phoneNumberPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        self.confirmButton.isEnabled = self.codeTextFieldView.isValid.value
    }
}
