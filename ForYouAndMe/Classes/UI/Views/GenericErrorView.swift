//
//  GenericErrorView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/10/2020.
//

import UIKit

class GenericErrorView: UIView {
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.genericErrorStyle.style)
        button.setTitle(StringsProvider.string(forKey: .errorButtonRetry), for: .normal)
        button.addTarget(self, action: #selector(self.retryButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private let retryButtonCallback: NotificationCallback
    
    init(retryButtonCallback: @escaping NotificationCallback) {
        self.retryButtonCallback = retryButtonCallback
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.errorSecondaryColor
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.addHeaderImage(image: ImagePalette.image(withName: .setupFailure))
        stackView.addBlankSpace(space: 44.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .setupErrorTitle),
                           fontStyle: .title,
                           color: ColorPalette.errorPrimaryColor)
        stackView.addBlankSpace(space: 44.0)
        stackView.addArrangedSubview(self.errorLabel)
        stackView.addBlankSpace(space: 160.0)
        stackView.addArrangedSubview(self.retryButton)
        self.addSubview(stackView)
        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoCenterInSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Actions
    
    @objc private func retryButtonPressed() {
        self.retryButtonCallback()
    }
    
    // MARK: - Public Methods
    
    public func hideView() {
        self.isHidden = true
    }
    
    public func showViewWithError(_ error: Error) {
        let repositoryError: RepositoryError = (error as? RepositoryError) ?? .genericError
        self.errorLabel.attributedText = NSAttributedString.create(withText: repositoryError.localizedDescription,
                                                                   fontStyle: .paragraph,
                                                                   color: ColorPalette.errorPrimaryColor)
        self.isHidden = false
    }
}
