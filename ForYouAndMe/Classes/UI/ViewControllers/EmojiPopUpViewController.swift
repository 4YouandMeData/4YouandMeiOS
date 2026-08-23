//
//  EmojiPopUpViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/07/25.
//

struct EmojiItem: Codable, Equatable {
    let id: String
    let type: String
    let tag: String
    let label: String?
}

enum EmojiTagCategory: String, CaseIterable {
    case myDoses = "my_doses"
    case reflections = "reflections"
    case iHaveEaten = "i_have_eaten"
    case iHaveNoticed = "i_have_noticed"
    case weHaveNoticed = "we_have_noticed"
    case hotFlash = "hot_flash"
    case menstrualPeriod = "menstrual_period"
    case none
}

final class EmojiPopupViewController: UIViewController {

    // FUAM-3857: the grid's only two shapes. `.none` is the affordance this controller adds —
    // the ONLY place "no emoji" exists as a value anywhere in this picker. Every `.emoji` case
    // is study-configured; there is no synthetic member of the emoji list any more.
    private enum Option {
        case none
        case emoji(EmojiItem)

        var item: EmojiItem? {
            switch self {
            case .none: return nil
            case .emoji(let item): return item
            }
        }
    }

    private let options: [Option]
    private let onSelectionConfirmed: (EmojiItem?) -> Void
    private let selected: EmojiItem?

    // FUAM-3857: true when at least one option — including "no emoji" — has a caption.
    // `options` never changes after init, so this is computed once here rather than per cell
    // in `sizeForItemAt:`.
    private let hasCaptions: Bool

    // FUAM-3857: fixed row height for a caption-less grid. `FontPalette` now caps the
    // caption's scaled point size (see `EmojiCell`), so this doesn't need to track a moving
    // target either — it only has to clear the same fixed-size icon floor the full 80pt row
    // does.
    private static let compactRowHeight: CGFloat = 64

    // FUAM-3495 — optional hook fired after the popup is dismissed, on BOTH save and
    // cancel (X). Lets a presenter restore its previous state (e.g. keyboard focus).
    // Set after init so existing callers are unaffected.
    var onDismiss: (() -> Void)?

    private var selectedIndexPath: IndexPath?

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 24
        layout.scrollDirection = .vertical
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    private let saveButton = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))

    init(emojis: [EmojiItem],
         selected: EmojiItem?,
         onSelectionConfirmed: @escaping (EmojiItem?) -> Void) {

        self.options = [.none] + emojis.map(Option.emoji)
        self.hasCaptions = self.options.contains { !EmojiCell.displayedCaption(for: $0.item).isEmpty }
        self.onSelectionConfirmed = onSelectionConfirmed
        self.selected = selected
        super.init(nibName: nil, bundle: nil)
        // An absent selection (no tag ever recorded) must not pre-highlight the "no emoji"
        // tile — nothing is selected, same as before this option existed.
        //
        // Match key stays (tag, label), not `id`: every catalog-sourced `EmojiItem` (the
        // `emojis` this controller receives) carries `id == ""` — `GlobalConfig+Mappable`
        // always maps it that way — while `selected` (a previously-recorded server tag) has a
        // real id. Matching on `id` would make every catalog entry collide on the same empty
        // id and resolve to the first one, breaking selection restore outright; it is not a
        // safe substitute here, unlike a true single-source list.
        self.selectedIndexPath = selected.flatMap { selectedItem in
            self.options.firstIndex { option in
                guard let item = option.item else { return false }
                return item.tag == selectedItem.tag && item.label == selectedItem.label
            }.map { IndexPath(item: $0, section: 0) }
        }
        modalPresentationStyle = .overCurrentContext
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        let cardView = UIView()
        cardView.backgroundColor = ColorPalette.color(withType: .secondary)
        cardView.layer.cornerRadius = 20
        cardView.clipsToBounds = true
        view.addSubview(cardView)
        cardView.autoCenterInSuperview()
        cardView.autoSetDimension(.width, toSize: 320)
        cardView.autoSetDimension(.height, toSize: 420, relation: .greaterThanOrEqual)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = StringsProvider.string(forKey: .emojiTitle)
        let baseFont = FontPalette.fontStyleData(forStyle: .header2).font
        if let boldDescriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) {
            titleLabel.font = UIFont(descriptor: boldDescriptor, size: baseFont.pointSize)
        } else {
            titleLabel.font = UIFont.boldSystemFont(ofSize: baseFont.pointSize)
        }
        titleLabel.textColor = ColorPalette.color(withType: .primaryText)
        titleLabel.textAlignment = .center

        // Close Button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .darkGray
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        cardView.addSubview(closeButton)
        cardView.addSubview(titleLabel)

        closeButton.autoPinEdge(toSuperviewEdge: .top, withInset: 16)
        closeButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        closeButton.autoSetDimensions(to: CGSize(width: 24, height: 24))

        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 56)
        titleLabel.autoAlignAxis(toSuperviewAxis: .vertical)

        // Save button
        self.saveButton.setButtonText(StringsProvider.string(forKey: .emojiButtonText))
        self.saveButton.setButtonEnabled(enabled: false)
        self.saveButton.addTarget(target: self, action: #selector(saveTapped))
        cardView.addSubview(saveButton)
        self.saveButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 0, bottom: -24, right: 0),
                                                excludingEdge: .top)

        // CollectionView setup
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.collectionView.backgroundColor = .clear
        self.collectionView.register(EmojiCell.self)
        cardView.addSubview(collectionView)
        self.collectionView.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 24)
        self.collectionView.autoPinEdge(.bottom, to: .top, of: self.saveButton, withOffset: 24)
        self.collectionView.autoPinEdge(toSuperviewEdge: .left, withInset: 20)
        self.collectionView.autoPinEdge(toSuperviewEdge: .right, withInset: 20)

    }

    @objc private func closeTapped() {
        dismiss(animated: true) {
            self.onDismiss?()
        }
    }

    @objc private func saveTapped() {
        guard let indexPath = selectedIndexPath else { return }
        let confirmed = options[indexPath.item].item
        dismiss(animated: true) {
            self.onSelectionConfirmed(confirmed)
            self.onDismiss?()
        }
    }
}

// MARK: - Collection View

extension EmojiPopupViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        options.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(ofType: EmojiCell.self, forIndexPath: indexPath) else {
            return UICollectionViewCell()
        }
        let isSelected = indexPath == selectedIndexPath
        cell.configure(with: options[indexPath.item].item, selected: isSelected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if indexPath == selectedIndexPath {
            return
        }

        let previous = selectedIndexPath
        selectedIndexPath = indexPath

        var toReload = [indexPath]
        if let previous = previous { toReload.append(previous) }
        collectionView.reloadItems(at: toReload)

        saveButton.setButtonEnabled(enabled: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemsPerRow: CGFloat = 4
        let interItemSpacing: CGFloat = 16
        let sectionInsets: CGFloat = 5
        let totalSpacing = (itemsPerRow - 1) * interItemSpacing + 2 * sectionInsets
        let width = (collectionView.bounds.width - totalSpacing) / itemsPerRow
        // FUAM-3857: when no option has a caption, drop the caption label's line height from
        // the row so the grid doesn't waste a blank line per row. `minimumLineSpacing` (24,
        // set on the layout in `setupUI`) is left unchanged — that's what still separates one
        // row from the next.
        let height: CGFloat = hasCaptions ? 80 : EmojiPopupViewController.compactRowHeight
        return CGSize(width: width, height: height)
    }
}
