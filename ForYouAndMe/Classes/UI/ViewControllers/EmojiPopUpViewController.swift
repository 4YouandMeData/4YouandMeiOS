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
    case none
}

final class EmojiPopupViewController: UIViewController {

    private let emojis: [EmojiItem]
    private let onSave: (EmojiItem?) -> Void
    private let selected: EmojiItem?

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
        
        self.emojis = emojis
        self.onSave = onSave
        self.selected = selected
        super.init(nibName: nil, bundle: nil)
        self.selectedIndexPath = selected.flatMap { selectedItem in
            return emojis.firstIndex(where: { $0.tag == selectedItem.tag && $0.label == selectedItem.label })
                    .map { IndexPath(item: $0, section: 0) }
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
        cardView.backgroundColor = .white
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
        dismiss(animated: true, completion: nil)
    }

    @objc private func saveTapped() {
        let selected = selectedIndexPath.map { emojis[$0.item] }
        dismiss(animated: true) {
            self.onSave(selected)
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
        cell.configure(with: emoji, selected: isSelected)
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
        let totalSpacing: CGFloat = 2 * 16 + 2 * 8 // padding + inter item
        let width = (collectionView.bounds.width - totalSpacing) / 3
        return CGSize(width: width, height: 80)
    }
}
