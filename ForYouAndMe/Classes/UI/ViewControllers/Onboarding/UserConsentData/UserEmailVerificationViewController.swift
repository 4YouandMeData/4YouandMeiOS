//
//  UserEmailVerificationViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/06/2020.
//

import Foundation
import PureLayout
import TPKeyboardAvoiding
import RxSwift

protocol UserEmailVerificationCoordinator {
    func onUserEmailPressed()
    func onUserEmailVerified()
}

public class UserEmailVerificationViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private let coordinator: UserEmailVerificationCoordinator
    
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
        let attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .onboardingUserEmailVerificationResend),
                                                       fontStyle: .header3,
                                                       colorType: .secondaryText,
                                                       textAlignment: .left,
                                                       underlined: true)
        button.setAttributedTitle(attributedText, for: .normal)
        return button
    }()
    
    private lazy var emailFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .emailAddress, styleCategory: .secondary)
        let button = UIButton()
        view.addSubview(button)
        button.autoPinEdgesToSuperviewEdges()
        button.addTarget(self, action: #selector(self.emailPressed), for: .touchUpInside)
        return view
    }()
    
    private lazy var codeTextFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .numberPad, styleCategory: .secondary)
        view.validationCallback = { text -> Bool in
            return text.count == Constants.Misc.EmailValidationCodeDigitCount
        }
        view.maxCharacters = Constants.Misc.EmailValidationCodeDigitCount
        return view
    }()
    
    init(email: String, coordinator: UserEmailVerificationCoordinator) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
        self.emailFieldView.text = email
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
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserEmailVerificationTitle),
                           fontStyle: .title,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 30.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserEmailVerificationBody),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 48.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserEmailVerificationWrongEmail),
                           fontStyle: .paragraph,
                           color: ColorPalette.color(withType: .secondaryText).applyAlpha(0.5),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 24.0)
        stackView.addArrangedSubview(self.emailFieldView)
        stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserEmailVerificationCodeDescription),
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
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.emailVerification.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.active(hidden: false).style)
        self.addCustomBackButton()
    }
    
    // MARK: Actions
    
    @objc private func resendCodeButtonPressed() {
        self.repository.resendConfirmationEmail()
            .addProgress()
            .subscribe(onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    @objc private func confirmButtonPressed() {
        guard self.codeTextFieldView.isValid.value else {
            assertionFailure("Invalid text field data")
            return
        }
        
        self.repository.verifyEmail(validationCode: self.codeTextFieldView.text)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.codeTextFieldView.clearError(clearErrorText: true)
                self.view.endEditing(true)
                self.coordinator.onUserEmailVerified()
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                if let error = error as? RepositoryError, case .wrongEmailValidationCode = error {
                    self.codeTextFieldView.setError(errorText: error.localizedDescription)
                } else {
                    self.navigator.handleError(error: error, presenter: self)
                }
            }).disposed(by: self.disposeBag)
    }
    
    @objc private func emailPressed() {
        self.coordinator.onUserEmailPressed()
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        self.confirmButton.isEnabled = self.codeTextFieldView.isValid.value
    }
}
