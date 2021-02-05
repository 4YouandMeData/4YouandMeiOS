//
//  QuickActivityListTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 06/08/2020.
//

import UIKit

struct QuickActivityItem {
    let taskId: String
    let quickActivity: QuickActivity
}

extension QuickActivityItem: Hashable, Equatable {
    static func == (lhs: QuickActivityItem, rhs: QuickActivityItem) -> Bool {
        return lhs.taskId == rhs.taskId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.taskId)
    }
}

class QuickActivityCollectionViewCell: UICollectionViewCell {
    
    let quickActivityView = QuickActivityView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.addSubview(self.quickActivityView)
        self.quickActivityView.autoPinEdgesToSuperviewEdges()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

typealias QuickActivityListConfirmCallback = ((QuickActivityItem) -> Void)
typealias QuickActivityListSelectionCallback = ((QuickActivityItem, QuickActivityOption) -> Void)

class QuickActivityListTableViewCell: UITableViewCell {
    
    static let collectionViewHeight: CGFloat = 500.0
    static let pageControlHeight: CGFloat = 20.0
    
    private lazy var collectionView: UICollectionView = {
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.isPagingEnabled = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsSelection = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(QuickActivityCollectionViewCell.self)
        collectionView.autoSetDimension(.height, toSize: Self.collectionViewHeight)
        
        // Design change: quick activities must be performed in order.
        // We take advantage of the list refresh, triggered by the result submission, to show the next quick activity.
        // The collection view is kept to quickly switch back to the previous behaviour, if needed.
        collectionView.isScrollEnabled = false
        
        return collectionView
    }()
    
    private lazy var pageControlLabel: UILabel = {
        let label = UILabel()
        label.autoSetDimension(.height, toSize: Self.pageControlHeight)
        return label
    }()
    
    private var confirmCallback: QuickActivityListConfirmCallback?
    private var selectionCallback: QuickActivityListSelectionCallback?
    
    private var items: [QuickActivityItem] = []
    private var selections: [QuickActivityItem: QuickActivityOption] = [:]
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        
        // Panel View
        self.contentView.addSubview(self.collectionView)
        self.collectionView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        self.contentView.addSubview(self.pageControlLabel)
        self.pageControlLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                              left: Constants.Style.DefaultHorizontalMargins,
                                                                              bottom: 24.0,
                                                                              right: Constants.Style.DefaultHorizontalMargins),
                                                           excludingEdge: .top)
        self.pageControlLabel.autoPinEdge(.top, to: .bottom, of: self.collectionView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(items: [QuickActivityItem],
                        selections: [QuickActivityItem: QuickActivityOption],
                        confirmCallback: @escaping QuickActivityListConfirmCallback,
                        selectionCallback: @escaping QuickActivityListSelectionCallback) {
        self.confirmCallback = confirmCallback
        self.selectionCallback = selectionCallback
        
        self.items = items
        self.selections = selections
        self.collectionView.reloadData()
        self.updatePageControl()
    }
    
    // MARK: - Private Methods
    
    private func updatePageControl() {
        var totalPagesCount = 4 // Default quick activity total number
        if let dynamicTotalPageCount = Int(StringsProvider.string(forKey: .quickActivityTotalNumber)), dynamicTotalPageCount > 0 {
            totalPagesCount = dynamicTotalPageCount
        }
        let currentPage = totalPagesCount - ((self.items.count - 1) % totalPagesCount)

        let currentPageAttributedText = NSMutableAttributedString.create(withText: "\(currentPage)",
               fontStyle: .paragraph,
               colorType: .primaryText)
        let totalPageAttributedText =  NSAttributedString.create(withText: " / \(totalPagesCount)",
            fontStyle: .paragraph,
            color: ColorPalette.color(withType: .fourthText).applyAlpha(0.3))
        let pageControlAttributedText = NSMutableAttributedString(attributedString: currentPageAttributedText)
        pageControlAttributedText.append(totalPageAttributedText)
        self.pageControlLabel.attributedText = pageControlAttributedText
    }
}

extension QuickActivityListTableViewCell: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(ofType: QuickActivityCollectionViewCell.self, forIndexPath: indexPath) {
            let itemIndex = indexPath.row
            let item = self.items[itemIndex]
            
            // All quick activities are designed to be performed atomically. However a new CR require the user
            // to perform them in order. A different submit button text is shown for all quick activities except
            // for the last one, to give a sense of progression to the user.
            let defaultButtonText = (itemIndex < self.items.count - 1)
                ? StringsProvider.string(forKey: .quickActivityButtonNext)
                : StringsProvider.string(forKey: .quickActivityButtonDefault)
            
            cell.quickActivityView.display(item: item.quickActivity,
                                           selectedOption: self.selections[item],
                                           defaultButtonText: defaultButtonText,
                                           confirmButtonCallback: { [weak self] in
                self?.confirmCallback?(item)
            }, selectionCallback: { [weak self] selectedOption in
                self?.selections[item] = selectedOption
                self?.selectionCallback?(item, selectedOption)
                self?.collectionView.reloadItems(at: [indexPath])
            })
            return cell
        } else {
            assertionFailure("QuickActivityListTableViewCell - Unexpected Index Path")
            return UICollectionViewCell()
        }
    }
}

extension QuickActivityListTableViewCell: UICollectionViewDelegate {
    
    // MARK: UIScrollViewDelegate
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.updatePageControl()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.updatePageControl()
    }
}

extension QuickActivityListTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.size.width, height: Self.collectionViewHeight)
    }
}

extension UIScrollView {
    var currentPage: Int {
        let frameWidth = self.frame.width
        return (frameWidth > 0) ? Int((self.contentOffset.x + (0.5 * frameWidth)) / frameWidth) + 1 : 1
    }
}
