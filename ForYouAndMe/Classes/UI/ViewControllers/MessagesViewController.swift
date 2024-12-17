//
//  MessagesViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 17/12/24.
//

import UIKit
import RxSwift

class MessagesViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    
    private let disposeBag = DisposeBag()
    private let titleString: String
    private let bodyString: String
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    init(withTitle
         title: String,
         body: String) {
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.repository = Services.shared.repository
        self.titleString = title
        self.bodyString = body
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
        
        let containerView = UIView()
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: titleString,
                           fontStyle: .title,
                           colorType: .primaryText)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 0, isVertical: false)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins/2,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins/2))
        
        // Header View
        self.view.addSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.stackView.addLabel(text: self.bodyString,
                                                font: FontPalette.fontStyleData(forStyle: .paragraph).font,
                                                textColor: ColorPalette.color(withType: .primaryText),
                                                textAlignment: .left)
        
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                      left: Constants.Style.DefaultHorizontalMargins/2,
                                                                      bottom: 0,
                                                                      right: Constants.Style.DefaultHorizontalMargins/2),
                                                   excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: containerView, withOffset: 30)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: Actions
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
    
    @objc private func confirmButtonPressed() {
        self.dismiss(animated: true)
    }
}
