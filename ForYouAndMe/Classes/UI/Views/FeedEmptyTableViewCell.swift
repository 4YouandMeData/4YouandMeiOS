//
//  FeedEmptyTableViewCell.swift
//  ForYouAndMe
//
//  FUAM-4315 (D16): the empty-feed text as a list row, shown below the KPI widget when the feed
//  has no items. `FeedEmptyView` is a background view (opaque, top offset, unpinned bottom) and
//  does not self-size in a cell, so this builds the same texts in its own pinned stack.
//

import UIKit
import PureLayout

final class FeedEmptyTableViewCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear

        let stackView = UIStackView()
        stackView.axis = .vertical
        self.contentView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24.0, left: 20.0, bottom: 24.0, right: 20.0))

        stackView.addLabel(withText: StringsProvider.string(forKey: .tabFeedEmptyTitle), fontStyle: .title, colorType: .primaryText)
        stackView.addBlankSpace(space: 20.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabFeedEmptySubtitle), fontStyle: .paragraph, colorType: .primaryText)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
