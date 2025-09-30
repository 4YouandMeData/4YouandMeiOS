//
//  FoodEntrySuccessViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 05/08/25.
//

import UIKit
import RxSwift

final class FoodEntrySuccessViewController: UIViewController {

    // MARK: - UI Elements
    private lazy var emojiButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .emojiICon), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.layer.cornerRadius = 8
        button.backgroundColor = ColorPalette.color(withType: .inactive).applyAlpha(0.5)
        button.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        return button
    }()

    private let scrollStackView = ScrollStackView(
        axis: .vertical,
        spacing: 24,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )

    // MARK: - Data
    private var selectedEmoji: EmojiItem?
    private var diaryNote: DiaryNoteItem
    private let repository: Repository = Services.shared.repository
    private let navigator: AppNavigator = Services.shared.navigator
    private let completionCallback: () -> Void
    private let disposeBag = DisposeBag()
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .diaryNoteEatenEmojiCloseButton))
        buttonView.setButtonEnabled(enabled: true)
        buttonView.addTarget(target: self, action: #selector(self.closeButtonTapped))
        return buttonView
    }()

    // MARK: - Init
    init(diaryNote: DiaryNoteItem,
         completion: @escaping () -> Void) {
        self.diaryNote = diaryNote
        self.completionCallback = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: true).style
        )
        navigationController?.preventPopWithSwipe()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ColorPalette.color(withType: .secondary)

        // StackView
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 100,
                                                                           left: 0,
                                                                           bottom: 0,
                                                                           right: 0),
                                                        excludingEdge: .bottom)

        // Title label
        scrollStackView.stackView.addLabel(withText: StringsProvider.string(forKey: .diaryNoteEatenEmojiTitle),
                           fontStyle: .title,
                           color: ColorPalette.color(withType: .primaryText))

        // Description label
        scrollStackView.stackView.addLabel(withText: StringsProvider.string(forKey: .diaryNoteEatenEmojiSubtitle),
                           fontStyle: .paragraph,
                           colorType: .primaryText)

        // Emoji button
        if !getEmojis().isEmpty {
            let emojiContainer = UIView()
            emojiContainer.addSubview(emojiButton)
            emojiButton.autoPinEdge(.top, to: .top, of: emojiContainer)
            emojiButton.autoPinEdge(.bottom, to: .bottom, of: emojiContainer)
            emojiButton.autoAlignAxis(toSuperviewAxis: .vertical)
            emojiButton.autoSetDimensions(to: CGSize(width: 100, height: 100))
            scrollStackView.stackView.addArrangedSubview(emojiContainer)
            
            scrollStackView.stackView.addLabel(withText: StringsProvider.string(forKey: .diaryNoteEatenEmojiClickMessage),
                                               fontStyle: .menu,
                                               colorType: .primaryText)
        }

        // Close button
        view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    // MARK: - Actions
    @objc private func emojiButtonTapped() {
        let emojiVC = EmojiPopupViewController(
            emojis: getEmojis(),
            selected: selectedEmoji
        ) { [weak self] selected in
            guard let self = self else { return }
            self.selectedEmoji = selected
            self.updateEmojiButton()
        }

        emojiVC.modalPresentationStyle = .overCurrentContext
        emojiVC.modalTransitionStyle = .crossDissolve
        self.present(emojiVC, animated: true)
    }

    private func updateEmojiButton() {
        guard let emoji = selectedEmoji else { return }
        let tag = (emoji.label != "none") ? emoji.tag : nil
        self.emojiButton.setImage(nil, for: .normal)
        self.emojiButton.setTitle(tag, for: .normal)
        emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 32)
        emojiButton.setTitleColor(ColorPalette.color(withType: .primaryText), for: .normal)
        diaryNote.feedbackTags?.append(emoji)
        self.repository.updateDiaryNoteText(diaryNote: self.diaryNote)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.closeButtonTapped()
            },
                       onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
                
            }).disposed(by: self.disposeBag)
    }

    @objc private func closeButtonTapped() {
        completionCallback()
    }

    // MARK: - Emoji Data
    private func getEmojis() -> [EmojiItem] {
        return Services.shared.storageServices.feedbackList[EmojiTagCategory.iHaveEaten.rawValue] ?? []
    }
}
