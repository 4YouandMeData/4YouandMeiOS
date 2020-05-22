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
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonStyles.primaryStyle)
        button.setTitle(StringsProvider.string(forKey: .errorButtonRetry), for: .normal)
        button.addTarget(self, action: #selector(self.initialize), for: .touchUpInside)
        return button
    }()
    
    private lazy var errorView: UIView = {
        let view = UIView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.addHeaderImage(image: ImagePalette.image(withName: .setupFailure))
        stackView.addBlankSpace(space: 44.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .setupErrorTitle),
                           fontStyle: .title,
                           colorType: .primaryText)
        stackView.addBlankSpace(space: 44.0)
        stackView.addArrangedSubview(self.errorLabel)
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
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
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
        self.errorLabel.attributedText = NSAttributedString.create(withText: repositoryError.localizedDescription,
                                                                   fontStyle: .paragraph,
                                                                   colorType: .primaryText)
        self.errorView.isHidden = false
    }
    
    private func hideError() {
        self.errorView.isHidden = true
    }
}
