//
//  UserNameViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/06/2020.
//

import Foundation
import PureLayout
import TPKeyboardAvoiding
import RxSwift

protocol UserNameCoordinator {
    func onUserNameConfirmPressed(firstName: String, lastName: String, relation: String?, currentRole: ConsentRole)
}

public class UserNameViewController: UIViewController {
    
    private let coordinator: UserNameCoordinator
    private let analytics: AnalyticsService
    private let consentRole: ConsentRole
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
    
    private lazy var firstNameFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .default, styleCategory: .secondary)
        view.validationCallback = { text -> Bool in
            return text.count > 0
        }
        view.textField.textContentType = .givenName
        return view
    }()
    
    private lazy var lastNameFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .default, styleCategory: .secondary)
        view.validationCallback = { text -> Bool in
            return text.count > 0
        }
        view.textField.textContentType = .familyName
        return view
    }()
    
    private lazy var relationFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .default, styleCategory: .secondary)
        view.validationCallback = { text -> Bool in
            return text.count > 0
        }
        view.textField.textContentType = .givenName
        return view
    }()
    
    init(coordinator: UserNameCoordinator,
         consentRole: ConsentRole) {
        self.coordinator = coordinator
        self.analytics = Services.shared.analytics
        self.consentRole = consentRole
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
        
        var title: StringKey
        var body: StringKey
        switch self.consentRole {
        case .adult:
            title = .onboardingUserNameTitle
            body = .onboardingUserNameBody
        case .minor:
            title = .onboardingUserNameMinorTitle
            body = .onboardingUserNameMinorBody
        case .guardian:
            title = .onboardingUserNameGuardianTitle
            body = .onboardingUserNameGuardianBody
        }
        
        stackView.addLabel(withText: StringsProvider.string(forKey: title),
                           fontStyle: .title,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 30.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: body),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 48.0)
        
        if consentRole == .guardian {
            stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserNameRelatedDescription),
                               fontStyle: .paragraph,
                               colorType: .secondaryText,
                               textAlignment: .left)
            stackView.addBlankSpace(space: 16.0)
            stackView.addArrangedSubview(self.relationFieldView)
        }
        stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserNameFirstNameDescription),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 16.0)
        stackView.addArrangedSubview(self.firstNameFieldView)
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .onboardingUserNameLastNameDescription),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 16.0)
        stackView.addArrangedSubview(self.lastNameFieldView)
        stackView.addBlankSpace(space: 16.0)
        
        // Bottom View
        let confirmButtonContainerView = UIView()
        confirmButtonContainerView.addSubview(self.confirmButton)
        self.confirmButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0),
                                                        excludingEdge: .leading)
        stackView.addArrangedSubview(confirmButtonContainerView)
        
        // Initialization
        self.firstNameFieldView.isValid
            .subscribe(onNext: { [weak self] _ in self?.updateUI() })
            .disposed(by: self.disposeBag)
        
        self.lastNameFieldView.isValid
            .subscribe(onNext: { [weak self] _ in self?.updateUI() })
            .disposed(by: self.disposeBag)
        
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.consentName.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)
        self.navigationItem.hidesBackButton = true
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        guard self.firstNameFieldView.isValid.value, self.lastNameFieldView.isValid.value else {
            assertionFailure("Invalid text field data")
            return
        }
        self.view.endEditing(true)
        self.coordinator.onUserNameConfirmPressed(firstName: self.firstNameFieldView.text,
                                                  lastName: self.lastNameFieldView.text,
                                                  relation: self.relationFieldView.text,
                                                  currentRole: self.consentRole)
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        switch consentRole {
        case .minor, .adult:
            self.confirmButton.isEnabled = self.firstNameFieldView.isValid.value && self.lastNameFieldView.isValid.value
        case .guardian:
            self.confirmButton.isEnabled = self.firstNameFieldView.isValid.value &&
            self.lastNameFieldView.isValid.value &&
            self.relationFieldView.isValid.value
            
        }
    }
}
