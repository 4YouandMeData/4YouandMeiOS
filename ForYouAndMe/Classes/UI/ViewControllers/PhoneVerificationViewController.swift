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
    
    static private let confirmButtonBottomInset: CGFloat = 16.0
    
    // KeyboardNotificationProvider
    var showNotification: NSObjectProtocol?
    var hideNotification: NSObjectProtocol?
    
    private let navigator: AppNavigator
    private let repository: Repository
    
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
    
    private lazy var countryCodeButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
        button.titleLabel?.font = FontPalette.font(withSize: 20.0)
        button.contentEdgeInsets = UIEdgeInsets.zero
        button.addTarget(self, action: #selector(self.countryCodeButtonPressed), for: .touchUpInside)
        button.setContentHuggingPriority(UILayoutPriority(1000), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .horizontal)
        return button
    }()
    
    private lazy var phoneNumberTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = ColorPalette.color(withType: .secondaryText)
        textField.tintColor = ColorPalette.color(withType: .secondaryText)
        textField.keyboardType = .phonePad
        textField.font = FontPalette.font(withSize: 20.0)
        textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }()
    
    private lazy var textFieldEditButton: UIButton = {
        let button = UIButton()
        button.imageView?.contentMode = .scaleAspectFit
        button.setImage(ImagePalette.image(withName: .edit), for: .normal)
        button.addTarget(self, action: #selector(self.textFieldEditButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var textFieldCheckmarkButton: UIButton = {
        let button = UIButton()
        button.imageView?.contentMode = .scaleAspectFit
        button.setImage(ImagePalette.image(withName: .checkmark), for: .normal)
        button.addTarget(self, action: #selector(self.textFieldEditButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var textFieldView: UIView = {
        let containerView = UIView()
        containerView.autoSetDimension(.height, toSize: 48.0)
        containerView.addHorizontalBorderLine(position: .bottom,
                                              leftMargin: 0,
                                              rightMargin: 0,
                                              color: ColorPalette.color(withType: .secondary).applyAlpha(0.2))
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8.0
        stackView.addArrangedSubview(self.countryCodeButton)
        stackView.addArrangedSubview(self.phoneNumberTextField)
        let iconContainerView = UIView()
        iconContainerView.addSubview(self.textFieldEditButton)
        self.textFieldEditButton.autoPinEdgesToSuperviewEdges()
        iconContainerView.addSubview(self.textFieldCheckmarkButton)
        self.textFieldCheckmarkButton.autoPinEdgesToSuperviewEdges()
        iconContainerView.autoSetDimension(.width, toSize: 40.0)
        stackView.addArrangedSubview(iconContainerView)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        return containerView
    }()
    
    private var confirmButtonBottomConstraint: NSLayoutConstraint?
    
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
                                                                  bottom: 0.0,
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
        stackView.addArrangedSubview(self.textFieldView)
        
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
        self.confirmButton.isEnabled = false
        self.textFieldEditButton.setImage(ImagePalette.image(withName: .edit), for: .normal)
        self.countryCodeButton.setTitle("+1", for: .normal)
        self.updateCheckVisibility()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.darkStyle)
        self.addCustomBackButton(withImage: ImagePalette.image(withName: .backButton))

        self.registerKeyboardNotification()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.deRegisterKeyboardNotification()
    }
    
    // MARK: Actions
    
    @objc private func countryCodeButtonPressed() {
        // TODO: Country Code button behaviour
        print("TODO: Country Code button behaviour")
    }
    
    @objc private func textFieldEditButtonPressed() {
        self.phoneNumberTextField.becomeFirstResponder()
    }
    
    @objc private func confirmButtonPressed() {
        // TODO: Implement confirm button behaviour
        print("TODO: Implement confirm button behaviour")
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        self.updateCheckVisibility()
    }
    
    // MARK: Private Methods
    
    private func isPhoneNumberValid() -> Bool {
        // TODO: Apply correct rule
        return self.phoneNumberTextField.text?.count ?? 0 >= 5
    }
    
    private func updateCheckVisibility() {
        self.textFieldCheckmarkButton.isHidden = false == self.isPhoneNumberValid()
        self.textFieldEditButton.isHidden = self.isPhoneNumberValid()
    }
}

// MARK: - KeyboardNotificationProvider

extension PhoneVerificationViewController: KeyboardNotificationProvider {
    func keyboardWillShow(height: CGFloat, duration: TimeInterval, options: UIView.AnimationOptions) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.confirmButtonBottomConstraint?.constant = -Self.confirmButtonBottomInset - height
            self.textFieldEditButton.alpha = 0.0
            self.view.layoutIfNeeded()
        })
    }
    
    func keyboardWillHide(duration: TimeInterval, options: UIView.AnimationOptions) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.confirmButtonBottomConstraint?.constant = -Self.confirmButtonBottomInset
            self.textFieldEditButton.alpha = 1.0
            self.view.layoutIfNeeded()
        })
    }
}
