//
//  FormSheetPage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/04/25.
//

import UIKit
import RxSwift

class FormSheetPage: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let titlePage: String
    private let bodyPage: String
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        
        let containerView = UIView()
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)
                
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins/2,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins/2))
        return containerView
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: true ))
        buttonView.setButtonText(StringsProvider.string(forKey: .reflectionLearnMoreClose))
        buttonView.addTarget(target: self, action: #selector(self.closeButtonPressed))
        return buttonView
    }()
    
    init(title: String, body: String) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.titlePage = title
        self.bodyPage = body
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("StudyInfoViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        self.view.addSubview(self.headerView)
        self.headerView.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        
        self.scrollStackView.stackView.addBlankSpace(space: 24.0)
        
        self.scrollStackView.stackView.addLabel(withText: self.titlePage,
                           fontStyle: .title,
                           colorType: .primaryText)
        
        self.scrollStackView.stackView.addBlankSpace(space: 24.0)
        
        self.scrollStackView.stackView.addHTMLTextView(withText: self.bodyPage,
                                  fontStyle: .paragraph,
                                  colorType: .primaryText)
        self.scrollStackView.scrollView.showsVerticalScrollIndicator = false
        self.scrollStackView.stackView.addBlankSpace(space: 12)
        
        // Footer View
        self.view.addSubview(self.footerView)
        self.footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        self.scrollStackView.autoPinEdge(.leading, to: .leading, of: self.view, withOffset: Constants.Style.DefaultHorizontalMargins)
        self.scrollStackView.autoPinEdge(.trailing, to: .trailing, of: self.view, withOffset: -Constants.Style.DefaultHorizontalMargins)
        self.scrollStackView.autoPinEdge(.bottom, to: .top, of: self.footerView)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: Actions
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
}
