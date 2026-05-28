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

/// FUAM-3364. Common surface for the two opt-in permission view controllers
/// (`OptInPermissionViewController` and `OptInPermissionInfoViewController`)
/// so that `OptInSectionCoordinator` can drive the in-progress overlay
/// uniformly regardless of which variant is currently on screen.
protocol OptInPermissionProcessingDriving: AnyObject {
    func setProcessing(_ isProcessing: Bool)
}

class OptInPermissionViewController: UIViewController, OptInPermissionProcessingDriving {

    let optInPermission: OptInPermission

    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let coordinator: OptInPermissionCoordinator
    private let disposeBag = DisposeBag()

    /// FUAM-3021 / FUAM-3116. Drives the in-progress overlay shown while the
    /// permission chain is running. Set by the coordinator via
    /// `setProcessing(_:)` immediately on Submit tap and cleared either when
    /// the chain advances or when the watchdog alert dismisses non-modally.
    private var isProcessing: Bool = false

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

    private lazy var processingOverlay: OptInPermissionProcessingOverlayView = {
        let view = OptInPermissionProcessingOverlayView()
        view.isHidden = true
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

        // FUAM-3021 / FUAM-3116. The processing overlay sits on top of the
        // entire card (including the Submit button) so the user gets clear
        // visual feedback that the chain is running and cannot accidentally
        // tap Submit twice during inter-step delays / OS prompt dismissals.
        self.view.addSubview(self.processingOverlay)
        self.processingOverlay.autoPinEdgesToSuperviewEdges()

        self.updateUI()
        self.setupBindings()
    }

    /// FUAM-3021 / FUAM-3116. Public entry point for `OptInSectionCoordinator`
    /// to drive the in-progress visual + interactive state. Idempotent.
    func setProcessing(_ isProcessing: Bool) {
        self.isProcessing = isProcessing
        self.grantRadio.isUserInteractionEnabled = !isProcessing
        self.denyRadio.isUserInteractionEnabled = !isProcessing
        self.processingOverlay.isHidden = !isProcessing
        if isProcessing {
            self.processingOverlay.startAnimating()
            self.view.bringSubviewToFront(self.processingOverlay)
        } else {
            self.processingOverlay.stopAnimating()
        }
        self.updateUI()
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
        // FUAM-3116. Defensive: if iOS somehow delivers a tap while we're
        // mid-chain (button is disabled, but defense-in-depth), no-op.
        guard self.isProcessing == false else { return }
        guard let granted = self.granted else {
            assertionFailure("Permission choice not made")
            return
        }
        self.coordinator.onOptInPermissionSet(optInPermission: self.optInPermission, granted: granted)
    }
    
    // MARK: Private Methods
    
    private func updateUI() {
        self.confirmButtonView.setButtonEnabled(enabled: !self.isProcessing && self.granted != nil)
    }
}

// MARK: - FUAM-3021 / FUAM-3116 — In-progress overlay

/// Dim, blocking overlay shown over the opt-in permission card while the
/// permission chain is running. Owned by `OptInPermissionViewController`;
/// driven by the coordinator via `setProcessing(_:)`.
private final class OptInPermissionProcessingOverlayView: UIView {

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = false
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = StringsProvider.string(forKey: .onboardingOptInProcessing)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init() {
        super.init(frame: .zero)
        // Semi-transparent black background blocks user interaction with
        // the card and provides clear visual cue that work is in progress.
        self.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        self.isUserInteractionEnabled = true

        let stack = UIStackView(arrangedSubviews: [self.activityIndicator, self.messageLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -32)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimating() {
        self.activityIndicator.startAnimating()
        // Refresh the label in case the user changed locale / strings were
        // re-fetched between the VC's first render and a subsequent Retry.
        self.messageLabel.text = StringsProvider.string(forKey: .onboardingOptInProcessing)
    }

    func stopAnimating() {
        self.activityIndicator.stopAnimating()
    }
}
