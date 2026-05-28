//
//  OptInPermissionInfoViewController.swift
//  ForYouAndMe
//
//  Created for FUAM-3364 — info-only opt-in permission screen.
//
//  Sibling of `OptInPermissionViewController`. Renders when the BE marks the
//  permission with `agreement_display == "disabled"`: no agree/disagree
//  radios, no recorded user choice, single forward CTA. The coordinator
//  treats the tap as an implicit "acknowledged" and proceeds to the next
//  step in the opt-in section.
//

import Foundation
import PureLayout
import RxSwift

class OptInPermissionInfoViewController: UIViewController, OptInPermissionProcessingDriving {

    let optInPermission: OptInPermission

    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let coordinator: OptInPermissionCoordinator
    private let disposeBag = DisposeBag()

    /// FUAM-3364. Mirrors `OptInPermissionViewController.isProcessing` —
    /// the coordinator runs the same submit machinery for info-only
    /// permissions and drives the overlay through `setProcessing(_:)`.
    private var isProcessing: Bool = false

    private lazy var continueButtonView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground())
        view.setButtonText(StringsProvider.string(forKey: .onboardingOptInSubmitButton))
        view.addTarget(target: self, action: #selector(self.continueButtonPressed))
        return view
    }()

    private lazy var processingOverlay: OptInPermissionInfoProcessingOverlayView = {
        let view = OptInPermissionInfoProcessingOverlayView()
        view.isHidden = true
        return view
    }()

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

        // ScrollStackView — same layout as the standard opt-in card without
        // the radio pair, so the info-only screen feels native to the flow.
        let scrollStackView = ScrollStackView(axis: .vertical,
                                              horizontalInset: Constants.Style.DefaultHorizontalMargins)
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
        scrollStackView.stackView.addBlankSpace(space: 27.0)

        // Bottom view — single forward CTA, enabled by default (no
        // user choice gating it).
        self.view.addSubview(self.continueButtonView)
        self.continueButtonView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: self.continueButtonView)

        // Processing overlay (mirrors the standard opt-in screen so the
        // coordinator can drive the same submit progress UI uniformly).
        self.view.addSubview(self.processingOverlay)
        self.processingOverlay.autoPinEdgesToSuperviewEdges()

        self.updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: self.optInPermission.type,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: true).style)
        self.navigationItem.hidesBackButton = true
    }

    /// FUAM-3364. Matches the signature on `OptInPermissionViewController`
    /// so the coordinator can drive both VCs through a common
    /// `setProcessing(_:)` callsite.
    func setProcessing(_ isProcessing: Bool) {
        self.isProcessing = isProcessing
        self.processingOverlay.isHidden = !isProcessing
        if isProcessing {
            self.processingOverlay.startAnimating()
            self.view.bringSubviewToFront(self.processingOverlay)
        } else {
            self.processingOverlay.stopAnimating()
        }
        self.updateUI()
    }

    // MARK: Actions

    @objc private func continueButtonPressed() {
        // Defensive: ignore taps while a submit is mid-flight (button is
        // disabled by `setProcessing`, but defense-in-depth).
        guard self.isProcessing == false else { return }
        // Open question (FUAM-3364): the BE submit shape currently requires
        // `agree: bool`. We synthesise `granted: true` to model the user's
        // implicit acknowledgement of the info screen. Jules to confirm
        // the desired BE semantics for `agreement_display == "disabled"`.
        self.coordinator.onOptInPermissionSet(optInPermission: self.optInPermission, granted: true)
    }

    // MARK: Private Methods

    private func updateUI() {
        self.continueButtonView.setButtonEnabled(enabled: !self.isProcessing)
    }
}

// MARK: - In-progress overlay (mirrors OptInPermissionViewController's)

/// Sibling of `OptInPermissionProcessingOverlayView` in the agree/disagree
/// VC. Kept as a separate type (rather than refactored into a shared one)
/// to keep this ticket's diff small; consolidate later if a third opt-in
/// variant lands.
private final class OptInPermissionInfoProcessingOverlayView: UIView {

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
        self.messageLabel.text = StringsProvider.string(forKey: .onboardingOptInProcessing)
    }

    func stopAnimating() {
        self.activityIndicator.stopAnimating()
    }
}
