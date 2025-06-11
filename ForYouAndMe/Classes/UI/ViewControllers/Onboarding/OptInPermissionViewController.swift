//
//  OptInPermissionViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/2020.
//

import Foundation
import PureLayout
import RxSwift

protocol OptInPermissionCoordinator {
    func onOptInPermissionSet(optInPermission: OptInPermission, granted: Bool)
}

class OptInPermissionViewController: UIViewController {
    
    let optInPermission: OptInPermission
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let coordinator: OptInPermissionCoordinator
    private let disposeBag = DisposeBag()
    
    private lazy var grantRadio: GenericTextRadioView = {
        let view = GenericTextRadioView(
            isDefaultSelected: false,
            radioStyle: .primary,
            fontStyle: .header3,
            colorType: .primaryText,
            textFirst: false,
            text: optInPermission.grantText
        )
        return view
    }()
    
    private lazy var denyRadio: GenericTextRadioView = {
        let view = GenericTextRadioView(
            isDefaultSelected: false,
            radioStyle: .primary,
            fontStyle: .header3,
            colorType: .primaryText,
            textFirst: false,
            text: optInPermission.denyText
        )
        return view
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground())
        view.setButtonText(StringsProvider.string(forKey: .onboardingOptInSubmitButton))
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    private var permission: SystemPermission? { self.optInPermission.systemPermissions.first }
    private var granted: Bool? {
        if grantRadio.isSelectedSubject.value { return true }
        if denyRadio.isSelectedSubject.value { return false }
        return nil
    }
    
    init(withOptInPermission optInPermission: OptInPermission, coordinator: OptInPermissionCoordinator) {
        self.optInPermission = optInPermission
        self.coordinator = coordinator
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        scrollStackView.stackView.addBlankSpace(space: 27.0)
        // Image
        scrollStackView.stackView.addHeaderImage(image: self.optInPermission.image, height: 82.0)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Title
        scrollStackView.stackView.addLabel(withText: self.optInPermission.title,
                                           fontStyle: .title,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        
        scrollStackView.stackView.addBlankSpace(space: 27.0)
        // Body
        scrollStackView.stackView.addHTMLTextView(withText: self.optInPermission.body,
                                                  fontStyle: .paragraph,
                                                  colorType: .primaryText,
                                                  textAlignment: .center)
        
        // Permissions
        scrollStackView.stackView.addArrangedSubview(self.grantRadio)
        scrollStackView.stackView.addBlankSpace(space: 8.0)
        scrollStackView.stackView.addArrangedSubview(self.denyRadio)
        
        scrollStackView.stackView.addBlankSpace(space: 27.0)
        
        // Bottom View
        self.view.addSubview(self.confirmButtonView)
        
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: self.confirmButtonView)
        
        self.updateUI()
        self.setupBindings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: self.optInPermission.type,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: true).style)
        self.navigationItem.hidesBackButton = true
    }
    
    private func setupBindings() {
        // Mutual‐exclusion of radios
        grantRadio.isSelectedSubject
            .subscribe(onNext: { [weak self] selected in
                if selected { self?.denyRadio.isSelectedSubject.accept(false) }
                self?.updateUI()
            })
            .disposed(by: disposeBag)
        
        denyRadio.isSelectedSubject
            .subscribe(onNext: { [weak self] selected in
                if selected { self?.grantRadio.isSelectedSubject.accept(false) }
                self?.updateUI()
            })
            .disposed(by: disposeBag)
        
        updateUI()
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        guard let granted = self.granted else {
            assertionFailure("Permission choice not made")
            return
        }
        self.coordinator.onOptInPermissionSet(optInPermission: self.optInPermission, granted: granted)
        
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        self.confirmButtonView.setButtonEnabled(enabled: self.granted != nil)
    }
}
