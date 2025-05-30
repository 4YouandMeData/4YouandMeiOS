//
//  UserEmailViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/06/2020.
//

import Foundation
import PureLayout
import TPKeyboardAvoiding
import RxSwift
import Validator

protocol UserEmailCoordinator {
    func onUserEmailSubmitted(email: String)
}

public class UserEmailViewController: UIViewController {
    
    private class UserEmailValidationError: ValidationError {
        var message: String = ""
    }
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private let coordinator: UserEmailCoordinator
    private let consentRole: ConsentRole
    
    private let disposeBag = DisposeBag()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonPrimary), for: .normal)
        button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        button.autoSetDimensions(to: CGSize(width: 50.0, height: 50.0))
        return button
    }()
    
    private lazy var emailFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .emailAddress, styleCategory: .primary)
        view.validationCallback = { text -> Bool in
            let rule = ValidationRulePattern(pattern: EmailValidationPattern.standard, error: UserEmailValidationError())
            switch text.validate(rule: rule) {
            case .valid: return true
            case .invalid: return false
            }
        }
        view.textField.textContentType = .emailAddress
        view.textField.autocapitalizationType = .none
        return view
    }()
    
    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .onboardingUserEmailInfo),
                                                         fontStyle: .header3,
                                                         colorType: .fourthText)
        return label
    }()
    
    private var headerImageView: UIImageView?
    
    init(coordinator: UserEmailCoordinator,
         consentRole: ConsentRole) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        self.coordinator = coordinator
        self.consentRole = consentRole
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
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
        
        self.headerImageView = stackView.addHeaderImage(image: ImagePalette.image(withName: .mainLogo), height: 100.0)
        stackView.addBlankSpace(space: 100.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserEmailEmailDescription),
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 16.0)
        stackView.addArrangedSubview(self.emailFieldView)
        stackView.addArrangedSubview(self.infoLabel)
        stackView.addBlankSpace(space: 16.0)
        
        // Bottom View
        let confirmButtonContainerView = UIView()
        confirmButtonContainerView.addSubview(self.confirmButton)
        self.confirmButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0),
                                                        excludingEdge: .leading)
        stackView.addArrangedSubview(confirmButtonContainerView)
        
        // Initialization
        self.emailFieldView.isValid
            .subscribe(onNext: { [weak self] _ in self?.updateUI() })
            .disposed(by: self.disposeBag)
        
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.headerImageView?.syncWithPhase(repository: self.repository, imageName: .mainLogo)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.emailInsert.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.navigationItem.hidesBackButton = true
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        self.submitEmail()
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        self.confirmButton.isEnabled = self.emailFieldView.isValid.value
        self.infoLabel.alpha = self.emailFieldView.isValid.value ? 1.0 : 0.0
    }
    
    private func submitEmail() {
        guard self.emailFieldView.isValid.value else {
            assertionFailure("Invalid text field data")
            return
        }
        self.repository.submitEmail(email: self.emailFieldView.text)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.emailFieldView.clearError(clearErrorText: true)
                self.view.endEditing(true)
                self.coordinator.onUserEmailSubmitted(email: self.emailFieldView.text)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
}
