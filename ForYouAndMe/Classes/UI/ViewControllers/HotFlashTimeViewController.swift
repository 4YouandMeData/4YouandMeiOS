//
//  HotFlashTimeViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 23/04/26.
//

import UIKit
import PureLayout

protocol HotFlashTimeViewControllerDelegate: AnyObject {
    func hotFlashTimeViewController(_ vc: HotFlashTimeViewController,
                                    didSelect relative: HotFlashTimeViewController.TimeRelative)
    func hotFlashTimeViewControllerDidDismiss(_ vc: HotFlashTimeViewController)
}

class HotFlashTimeViewController: UIViewController {

    enum TimeRelative: String {
        case justNow
        case inThePast
    }

    var alert: Alert?

    private let storage: CacheService
    private let navigator: AppNavigator
    private let variant: FlowVariant

    weak var delegate: HotFlashTimeViewControllerDelegate?

    private lazy var closeButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .closeButton),
            style: .plain,
            target: self,
            action: #selector(closeButtonPressed)
        )
        item.tintColor = ColorPalette.color(withType: .primaryText)
        return item
    }()

    private lazy var justNowButton: OptionButton = makeOptionButton(type: .justNow)
    private lazy var inThePastButton: OptionButton = makeOptionButton(type: .inThePast)

    private var selectedRelative: TimeRelative? {
        didSet {
            footerView.setButtonEnabled(enabled: selectedRelative != nil)
        }
    }

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .diaryNoteHotFlashNextButton))
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(self.nextTapped))
        return buttonView
    }()

    private lazy var messages: [MessageInfo] = {
        let location: MessageInfoParameter = .pageHotFlash
        let messages = self.storage.infoMessages?.messages(withLocation: location)
        return messages ?? []
    }()

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(variant: FlowVariant) {
        self.navigator = Services.shared.navigator
        self.storage = Services.shared.storageServices
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        switch variant {
        case .embeddedInNoticed:
            self.addCustomBackButton()
        case .standalone, .fromChart(_):
            self.navigationItem.leftBarButtonItem = self.closeButton
        }
    }

    private func setupLayout() {
        let infoItem = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .infoMessage),
            style: .plain,
            target: self,
            action: #selector(infoButtonPressed)
        )
        infoItem.tintColor = ColorPalette.color(withType: .primary)
        self.navigationItem.rightBarButtonItem = (self.messages.count < 1) ? nil : infoItem

        let scrollStackView = ScrollStackView(axis: .vertical,
                                              horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let titleKey = StringsProvider.string(forKey: .diaryNoteHotFlashStepOneTitle)
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let titleAttr = NSAttributedString(string: titleKey, attributes: boldAttrs)
        scrollStackView.stackView.addLabel(attributedString: titleAttr, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 36)

        if let alert = alert?.body {
            scrollStackView.stackView.addLabel(
                withText: alert,
                fontStyle: .paragraph,
                color: ColorPalette.color(withType: .primaryText)
            )
            scrollStackView.stackView.addBlankSpace(space: 40)
        }

        let messageText = StringsProvider.string(forKey: .diaryNoteHotFlashStepOneMessage)
        let messageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let messageAttr = NSAttributedString(string: messageText, attributes: messageAttrs)
        scrollStackView.stackView.addLabel(attributedString: messageAttr, numberOfLines: 0)

        scrollStackView.stackView.addBlankSpace(space: 44)

        scrollStackView.stackView.addArrangedSubview(self.justNowButton)
        scrollStackView.stackView.addBlankSpace(space: 16)
        scrollStackView.stackView.addArrangedSubview(self.inThePastButton)

        self.inThePastButton.autoSetDimension(.height, toSize: 54)
        self.justNowButton.autoMatch(.height, to: .height, of: inThePastButton)

        self.view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func makeOptionButton(type: TimeRelative) -> OptionButton {
        let btn = OptionButton()
        let titleKey: StringKey = (type == .justNow)
            ? .diaryNoteHotFlashStepOneFirstButton
            : .diaryNoteHotFlashStepOneSecondButton
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(StringsProvider.string(forKey: titleKey), for: .normal)
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func optionTapped(_ sender: OptionButton) {
        justNowButton.isSelected = (sender == justNowButton)
        inThePastButton.isSelected = (sender == inThePastButton)
        selectedRelative = (sender == justNowButton) ? .justNow : .inThePast
    }

    @objc private func nextTapped() {
        guard let rel = selectedRelative else { return }
        delegate?.hotFlashTimeViewController(self, didSelect: rel)
    }

    @objc private func closeButtonPressed() {
        delegate?.hotFlashTimeViewControllerDidDismiss(self)
    }

    @objc private func infoButtonPressed() {
        let location: MessageInfoParameter = .pageHotFlash
        self.navigator.openMessagePage(withLocation: location, presenter: self)
    }
}
