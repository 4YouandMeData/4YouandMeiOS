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

    // FUAM-3857: the caption an `EmojiCell` displays for this item. Deliberately takes
    // `isNoneOption` from the caller rather than inspecting `label` itself — whether this is
    // the "no emoji" sentinel is a POSITIONAL fact owned by `EmojiPopUpViewController` (it's
    // the item it inserted at index 0), not something derived from the label. A real study
    // emoji labelled "none" must keep showing its own label, not the sentinel's icon or
    // caption. Shared by both `EmojiPopUpViewController` (row height) and `EmojiCell`
    // (rendering) so the two can't drift apart on what counts as "has a caption".
    func displayedCaption(isNoneOption: Bool) -> String {
        isNoneOption ? StringsProvider.string(forKey: .emojiNoneLabel) : (label ?? "")
    }
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

    private var emojis: [EmojiItem]
    private let onSave: (EmojiItem?) -> Void
    private let selected: EmojiItem?

    // FUAM-3857: true when the sentinel was inserted (i.e. the caller's `emojis` wasn't
    // empty). This, plus the item's index, is the ONLY thing that decides "is this the none
    // option" — see `isNoneOption(at:)`. Never re-derived from `label`.
    private let sentinelInserted: Bool

    // FUAM-3857: true when at least one item — including the sentinel — has a caption.
    // `emojis` never changes after init, so this is computed once here rather than per cell
    // in `sizeForItemAt:`.
    private let hasCaptions: Bool

    // FUAM-3857: fixed, deliberately NOT derived from `FontPalette.fontStyleData` at call
    // time. `FontPalette` scales via `UIFontMetrics.default.scaledFont(for:)` with no
    // `maximumPointSize` cap, so `80 - <that line height>` would SHRINK as the user's Dynamic
    // Type setting grows, while the cell's content (45pt icon, 4pt blank spacer, 8pt of stack
    // spacing = 57pt required floor) is fixed-size and doesn't shrink with it. At the first
    // accessibility text size the row would already be smaller than that 57pt floor, breaking
    // a required constraint and clipping the icon — the opposite of what a "reduce the row"
    // feature should do. 64 = 80 minus the header3 caption's line height at the default
    // (Large) content size, rounded up — comfortably above the 57pt floor and constant
    // regardless of text size, exactly as Dynamic-Type-safe as the unreduced 80.
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
         onSave: @escaping (EmojiItem?) -> Void) {
        
        let sentinelInserted = !emojis.isEmpty
        self.emojis = emojis
        if sentinelInserted {
            self.emojis.insert(EmojiItem(id: "", type: "", tag: "❌", label: "none"), at: 0)
        }
        self.sentinelInserted = sentinelInserted
        self.hasCaptions = self.emojis.enumerated().contains { index, item in
            !item.displayedCaption(isNoneOption: sentinelInserted && index == 0).isEmpty
        }
        self.onSave = onSave
        self.selected = selected
        super.init(nibName: nil, bundle: nil)
        self.selectedIndexPath = selected.flatMap { selectedItem in
            // Search self.emojis (which has the sentinel inserted at index 0), not the
            // `emojis` parameter: the collection view renders self.emojis, so an index found
            // against the parameter is off by one once the sentinel is present.
            return self.emojis.firstIndex(where: { $0.tag == selectedItem.tag && $0.label == selectedItem.label })
                    .map { IndexPath(item: $0, section: 0) }
            }
        modalPresentationStyle = .overCurrentContext
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // FUAM-3857: this controller is the only place that inserts the sentinel, so it's the
    // only place that can answer "is this the none option" — by position, not by label. Index
    // 0 is the none option exactly when the sentinel was inserted.
    private func isNoneOption(at index: Int) -> Bool {
        sentinelInserted && index == 0
    }

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
        let selected = selectedIndexPath.map { emojis[$0.item] }
        dismiss(animated: true) {
            self.onSave(selected)
            self.onDismiss?()
        }
    }
}

// MARK: - Collection View

extension EmojiPopupViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        emojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(ofType: EmojiCell.self, forIndexPath: indexPath) else {
            return UICollectionViewCell()
        }
        let emoji = emojis[indexPath.item]
        let isSelected = indexPath == selectedIndexPath
        cell.configure(with: emoji, isNoneOption: isNoneOption(at: indexPath.item), selected: isSelected)
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
        // FUAM-3857: when no item has a caption, drop the caption label's line height from
        // the row so the grid doesn't waste a blank line per row. `minimumLineSpacing` (24,
        // set on the layout in `setupUI`) is left unchanged — that's what still separates one
        // row from the next.
        let height: CGFloat = hasCaptions ? 80 : EmojiPopupViewController.compactRowHeight
        return CGSize(width: width, height: height)
    }
}
