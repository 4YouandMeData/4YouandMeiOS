//
//  PhoneVerificationViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 08/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

public class PhoneVerificationViewController: UIViewController {
    
    static private let confirmButtonBottomInset: CGFloat = 16.0
    
    // KeyboardNotificationProvider
    var showNotification: NSObjectProtocol?
    var hideNotification: NSObjectProtocol?
    
    private let navigator: AppNavigator
    private let repository: Repository
    
    private lazy var confirmButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonLight), for: .normal)
        button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        return button
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
        let scrollStackView = ScrollStackView(axis: .vertical)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0.0,
                                                                      left: Constants.Style.DefaultHorizontalMargins,
                                                                      bottom: 0.0,
                                                                      right: Constants.Style.DefaultHorizontalMargins))
        scrollStackView.stackView.addBlankSpace(space: 16.0)
        scrollStackView.stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationTitle),
                           font: FontPalette.font(withSize: 30.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left)
        scrollStackView.stackView.addBlankSpace(space: 60.0)
        scrollStackView.stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationBody),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left,
                           lineSpacing: Constants.Style.DefaultBodyLineSpacing)
        scrollStackView.stackView.addBlankSpace(space: 48.0)
        scrollStackView.stackView.addLabel(text: StringsProvider.string(forKey: .phoneVerificationNumberDescription),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left)
        
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
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.darkStyle)
        self.addCustomBackButton(withImage: ImagePalette.image(withName: .backButton))
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        // TODO: Implement confirm button behaviour
        print("TODO: Implement confirm button behaviour")
    }
}

// MARK: - KeyboardNotificationProvider

extension PhoneVerificationViewController: KeyboardNotificationProvider {
    func keyboardWillShow(height: CGFloat, duration: TimeInterval, options: UIView.AnimationOptions) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.confirmButtonBottomConstraint?.constant = -Self.confirmButtonBottomInset - height
            self.view.layoutIfNeeded()
        })
    }
    
    func keyboardWillHide(duration: TimeInterval, options: UIView.AnimationOptions) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
            guard let self = self else { return }
            self.confirmButtonBottomConstraint?.constant = -Self.confirmButtonBottomInset
            self.view.layoutIfNeeded()
        })
    }
}
