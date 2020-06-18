//
//  LoadingViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

protocol LoadingPage {}

enum LoadingMode<T> {
    case initialSetup
    case genericLoad(loadingInfo: LoadingInfo<T>)
}

struct LoadingInfo<T> {
    typealias CompletionCallback = ((T) -> Void)
    
    let requestSingle: Single<T>
    let completionCallback: CompletionCallback
}

class LoadingViewController<T>: UIViewController, LoadingPage {
    
    private let loadingMode: LoadingMode<T>
    private let navigator: AppNavigator
    
    private let disposeBag = DisposeBag()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.loadingErrorStyle.style)
        button.setTitle(StringsProvider.string(forKey: .errorButtonRetry), for: .normal)
        button.addTarget(self, action: #selector(self.retryButtonPressed), for: .touchUpInside)
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
                           color: ColorPalette.loadingErrorPrimaryColor)
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
    
    init(loadingMode: LoadingMode<T>) {
        self.loadingMode = loadingMode
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.loadingErrorSecondaryColor
        
        self.view.addSubview(self.errorView)
        self.errorView.autoPinEdgesToSuperviewSafeArea()
        self.hideError()
        
        if let navigationController = navigationController {
            navigationController.navigationBar.apply(style: NavigationBarStyles.secondaryStyle)
            self.navigationItem.hidesBackButton = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.startLoading()
    }
    
    // MARK: - Actions
    
    @objc private func retryButtonPressed() {
        self.startLoading()
    }
    
    // MARK: - Private Methods
    
    private func startLoading() {
        self.hideError()
        self.navigator.pushProgressHUD()
        
        switch self.loadingMode {
        case .initialSetup:
            Services.shared.initializeServices().delaySubscription(.seconds(1), scheduler: MainScheduler.instance)
                .subscribe(onNext: { progress in
                    print("SetupViewController - Initialization Progress: \(progress)")
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.showError(error: error)
                    }, onCompleted: { [weak self] in
                        guard let self = self else { return }
                        self.navigator.popProgressHUD()
                        self.navigator.showSetupCompleted()
                }).disposed(by: self.disposeBag)
            
        case .genericLoad(let loadingInfo):
            loadingInfo.requestSingle.subscribe(onSuccess: { [weak self] loadedData in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                loadingInfo.completionCallback(loadedData)
                }, onError: { [weak self]  error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    if false == self.navigator.handleUserNotLoggedError(error: error) {
                        self.showError(error: error)
                    }
            }).disposed(by: self.disposeBag)
        }
    }
    
    private func showError(error: Error) {
        let repositoryError: RepositoryError = (error as? RepositoryError) ?? .genericError
        self.errorLabel.attributedText = NSAttributedString.create(withText: repositoryError.localizedDescription,
                                                                   fontStyle: .paragraph,
                                                                   color: ColorPalette.loadingErrorPrimaryColor)
        self.errorView.isHidden = false
    }
    
    private func hideError() {
        self.errorView.isHidden = true
    }
}
