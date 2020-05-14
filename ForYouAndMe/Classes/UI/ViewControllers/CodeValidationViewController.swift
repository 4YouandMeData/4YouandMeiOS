//
//  CodeValidationViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout
import RxSwift

public class CodeValidationViewController: UIViewController {
    
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
    
    private lazy var phoneNumberView: PhoneNumberView = {
        let phoneNumberView = PhoneNumberView()
        let button = UIButton()
        phoneNumberView.addSubview(button)
        button.autoPinEdgesToSuperviewEdges()
        button.addTarget(self, action: #selector(self.phoneNumberPressed), for: .touchUpInside)
        return phoneNumberView
    }()
    
    private lazy var codeTextFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .asciiCapable) { text -> Bool in
            // TODO: Decide if validation code has format rule
            return text.count >= 4
        }
        return view
    }()
    
    private var confirmButtonBottomConstraint: NSLayoutConstraint?
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init(nibName: nil, bundle: nil)
        // TODO: Init phone number
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
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: Self.confirmButtonBottomInset,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        stackView.addBlankSpace(space: 16.0)
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
        
        self.codeTextFieldView.isValid
            .subscribe(onNext: { [weak self] _ in self?.updateUI() })
            .disposed(by: self.disposeBag)
        
        // Initialization
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.activeStyle)
        self.addCustomBackButton(withImage: ImagePalette.image(withName: .backButton))
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        
        self.registerKeyboardNotification()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.deRegisterKeyboardNotification()
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        self.navigator.pushProgressHUD()
        self.repository.verifyPhoneNumber(phoneNumber: self.phoneNumberView.text, secureCode: self.codeTextFieldView.text)
        .subscribe(onSuccess: { [weak self] in
            guard let self = self else { return }
            self.navigator.popProgressHUD()
            self.view.endEditing(true)
            self.navigator.showIntroVideo(presenter: self)
        }, onError: { [weak self] error in
            guard let self = self else { return }
            self.navigator.popProgressHUD()
            self.codeTextFieldView.setError(errorText: error.localizedDescription)
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

// MARK: - KeyboardNotificationProvider

extension CodeValidationViewController: KeyboardNotificationProvider {
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
