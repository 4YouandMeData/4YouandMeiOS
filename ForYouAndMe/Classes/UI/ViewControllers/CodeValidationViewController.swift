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
    private let disposeBag = DisposeBag()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonLight), for: .normal)
        button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var resendCodeButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(self.resendCodeButtonPressed), for: .touchUpInside)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let text = NSAttributedString(string: StringsProvider.string(forKey: .phoneVerificationCodeResend),
                                      attributes: [
                                        .font: FontPalette.font(withSize: 16.0),
                                        .foregroundColor: ColorPalette.color(withType: .secondaryText),
                                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                                        .paragraphStyle: paragraphStyle
                                        
        ])
        button.setAttributedTitle(text, for: .normal)
        return button
    }()
    
    private lazy var phoneNumberView: PhoneNumberView = {
        // TODO: Initialized country code based of server data
        let phoneNumberView = PhoneNumberView(presenter: self,
                                              allowedCountryCodes: ["IT", "US", "GB"])
        let button = UIButton()
        phoneNumberView.addSubview(button)
        button.autoPinEdgesToSuperviewEdges()
        button.addTarget(self, action: #selector(self.phoneNumberPressed), for: .touchUpInside)
        return phoneNumberView
    }()
    
    private lazy var codeTextFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .numberPad)
        view.textField.textContentType = .oneTimeCode
        view.validationCallback = { text -> Bool in
            return text.count == Constants.Misc.ValidationCodeDigitCount
        }
        view.maxCharacters = Constants.Misc.ValidationCodeDigitCount
        return view
    }()
    
    init(countryCode: String, phoneNumber: String) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
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
        
        stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationCodeTitle),
                           font: FontPalette.font(withSize: 30.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 60.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationCodeBody),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left,
                           lineSpacing: Constants.Style.DefaultBodyLineSpacing)
        stackView.addBlankSpace(space: 48.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationWrongNumber),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText).applyAlpha(0.5),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 24.0)
        stackView.addArrangedSubview(self.phoneNumberView)
        stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationCodeDescription),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
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
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.activeStyle)
        self.addCustomBackButton(withImage: ImagePalette.image(withName: .backButton))
    }
    
    // MARK: Actions
    
    @objc private func resendCodeButtonPressed() {
        self.navigator.pushProgressHUD()
        self.repository.submitPhoneNumber(phoneNumber: self.phoneNumberView.fullNumber)
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    @objc private func confirmButtonPressed() {
        self.navigator.pushProgressHUD()
        self.repository.verifyPhoneNumber(phoneNumber: self.phoneNumberView.fullNumber, secureCode: self.codeTextFieldView.text)
        .subscribe(onSuccess: { [weak self] in
            guard let self = self else { return }
            self.navigator.popProgressHUD()
            self.codeTextFieldView.clearError(clearErrorText: true)
            self.view.endEditing(true)
            self.navigator.showIntroVideo(presenter: self)
        }, onError: { [weak self] error in
            guard let self = self else { return }
            self.navigator.popProgressHUD()
            if let error = error as? RepositoryError, case .wrongValidationCode = error {
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
        guard let codeValid = try? self.codeTextFieldView.isValid.value() else {
            assertionFailure("Unexpected throw")
            return
        }
        self.confirmButton.isEnabled = codeValid
    }
}
