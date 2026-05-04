//
//  MenstrualOnboardingPeriod3MoViewController.swift
//  ForYouAndMe
//
//  FUAM-2937 — Inline onboarding step 1: "Have you had a menstrual period in
//  the past 3 months?" with Yes/No/Unsure options. Drives whether step 2
//  (last period date) is shown.
//

import UIKit
import PureLayout

protocol MenstrualOnboardingPeriod3MoViewControllerDelegate: AnyObject {
    func menstrualOnboardingPeriod3MoViewController(_ vc: MenstrualOnboardingPeriod3MoViewController,
                                                    didSelect value: MenstrualHadPeriod3Mo)
    func menstrualOnboardingPeriod3MoViewControllerDidCancel(_ vc: MenstrualOnboardingPeriod3MoViewController)
}

final class MenstrualOnboardingPeriod3MoViewController: UIViewController {

    weak var delegate: MenstrualOnboardingPeriod3MoViewControllerDelegate?

    private let navigator: AppNavigator

    private var optionButtons: [MenstrualHadPeriod3Mo: OptionButton] = [:]
    private var selectedOption: MenstrualHadPeriod3Mo? {
        didSet { footerView.setButtonEnabled(enabled: selectedOption != nil) }
    }

    private lazy var footerView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        view.setButtonText(StringsProvider.string(forKey: .menstrualNextButton))
        view.setButtonEnabled(enabled: false)
        view.addTarget(target: self, action: #selector(nextTapped))
        return view
    }()

    init() {
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        // Step 1 is the modal root: back has nothing to pop to, so the chevron
        // dismisses the onboarding via the delegate.
        addCustomBackButton(withImage: ImagePalette.templateImage(withName: .backButtonNavigation),
                            action: { [weak self] in
            guard let self = self else { return }
            self.delegate?.menstrualOnboardingPeriod3MoViewControllerDidCancel(self)
        })
    }

    private func setupLayout() {
        let scrollStackView = ScrollStackView(axis: .vertical,
                                              horizontalInset: Constants.Style.DefaultHorizontalMargins)
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        // Mirror MenstrualWhenViewController.setupLayout: Title (header2 bold)
        // + 36pt + Message (17pt) + 44pt + options + footer.
        // Title reuses `menstrualDetailTitle` ("Menstrual Flow Tracking") so
        // the screen wears the same brand as the rest of the diary flow.
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        scrollStackView.stackView.addLabel(
            attributedString: NSAttributedString(
                string: StringsProvider.string(forKey: .menstrualDetailTitle),
                attributes: titleAttrs),
            numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 36)

        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        scrollStackView.stackView.addLabel(
            attributedString: NSAttributedString(
                string: StringsProvider.string(forKey: .menstrualOnboardingPeriod3MoTitle),
                attributes: messageAttrs),
            numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 44)

        let order: [(MenstrualHadPeriod3Mo, StringKey)] = [
            (.yes, .menstrualOnboardingPeriod3MoYes),
            (.no, .menstrualOnboardingPeriod3MoNo),
            (.unsure, .menstrualOnboardingPeriod3MoUnsure)
        ]
        for (idx, item) in order.enumerated() {
            let btn = makeOptionButton(title: StringsProvider.string(forKey: item.1), value: item.0)
            optionButtons[item.0] = btn
            scrollStackView.stackView.addArrangedSubview(btn)
            btn.autoSetDimension(.height, toSize: 54)
            if idx < order.count - 1 {
                scrollStackView.stackView.addBlankSpace(space: 16)
            }
        }

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func makeOptionButton(title: String, value: MenstrualHadPeriod3Mo) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(title, for: .normal)
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func optionTapped(_ sender: OptionButton) {
        for (value, btn) in optionButtons {
            btn.isSelected = (btn == sender)
            if btn == sender { selectedOption = value }
        }
    }

    @objc private func nextTapped() {
        guard let value = selectedOption else { return }
        delegate?.menstrualOnboardingPeriod3MoViewController(self, didSelect: value)
    }
}
