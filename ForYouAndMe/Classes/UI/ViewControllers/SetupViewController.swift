//
//  SetupViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

public class SetupViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let disposeBag = DisposeBag()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = ColorPalette.color(withType: .secondaryText)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = FontPalette.font(withSize: 20.0)
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let buttonHeight: CGFloat = 52.0
        let button = UIButton()
        button.autoSetDimension(.height, toSize: buttonHeight)
        button.layer.cornerRadius = buttonHeight / 2.0
        button.backgroundColor = ColorPalette.color(withType: .secondaryText)
        button.setTitle(StringsProvider.string(forKey: .errorButtonRetry), for: .normal)
        button.setTitleColor(ColorPalette.color(withType: .primary), for: .normal)
        button.titleLabel?.font = FontPalette.font(withSize: 20.0)
        button.addTarget(self, action: #selector(self.initialize), for: .touchUpInside)
        return button
    }()
    
    private lazy var errorView: UIView = {
        let view = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.addHeaderImage(image: ImagePalette.image(withName: .failure))
        stackView.addBlankSpace(space: 44.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .setupErrorTitle),
                           font: FontPalette.font(withSize: 24.0),
                           textColor: ColorPalette.color(withType: .secondaryText))
        stackView.addBlankSpace(space: 44.0)
        stackView.addArrangedSubview(errorLabel)
        stackView.addBlankSpace(space: 160.0)
        stackView.addArrangedSubview(self.retryButton)
        view.addSubview(stackView)
        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoCenterInSuperview()
        return view
    }()
    
    init() {
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addGradientView(GradientView(type: .defaultBackground))
        
        self.view.addSubview(self.errorView)
        self.errorView.autoPinEdgesToSuperviewSafeArea()
        
        self.initialize()
    }
    
    // MARK: - Private Methods
    
    @objc private func initialize() {
        self.hideError()
        self.navigator.pushProgressHUD()
        Services.shared.initializeServices().delaySubscription(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { progress in
            print("SetupViewController - Initialization Progress: \(progress)")
        }, onError: { error in
            self.navigator.popProgressHUD()
            self.showError(error: error)
        }, onCompleted: {
            self.navigator.popProgressHUD()
            self.navigator.showSetupCompleted()
        }).disposed(by: self.disposeBag)
    }
    
    private func showError(error: Error) {
        let repositoryError: RepositoryError = (error as? RepositoryError) ?? .genericError
        self.errorLabel.text = repositoryError.localizedDescription
        self.errorView.isHidden = false
    }
    
    private func hideError() {
        self.errorView.isHidden = true
    }
}
