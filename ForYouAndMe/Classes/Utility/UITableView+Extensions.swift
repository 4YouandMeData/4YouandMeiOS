//
//  UITableView+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 12/06/2020.
//

import UIKit

public extension UITableView {
    func sizeHeaderToFit() {
        guard let headerView = self.tableHeaderView else { return }
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        let headerWidth = headerView.bounds.size.width
        let temporaryWidthConstraints = NSLayoutConstraint.constraints(withVisualFormat: "[headerView(width)]",
                                                                       options: NSLayoutConstraint.FormatOptions(rawValue: UInt(0)),
                                                                       metrics: ["width": headerWidth],
                                                                       views: ["headerView": headerView])
        
        headerView.addConstraints(temporaryWidthConstraints)
        
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        
        let headerSize = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let height = headerSize.height
        var frame = headerView.frame
        
        frame.size.height = height
        headerView.frame = frame
        
        self.tableHeaderView = headerView
        
        headerView.removeConstraints(temporaryWidthConstraints)
        headerView.translatesAutoresizingMaskIntoConstraints = true
    }
    
    func sizeFooterToFit() {
            guard let footerView = self.tableFooterView else { return }
            footerView.translatesAutoresizingMaskIntoConstraints = false

            let footerWidth = footerView.bounds.size.width
            let temporaryWidthConstraints = NSLayoutConstraint.constraints(
                withVisualFormat: "[footerView(width)]",
                options: NSLayoutConstraint.FormatOptions(rawValue: 0),
                metrics: ["width": footerWidth],
                views: ["footerView": footerView]
            )

            footerView.addConstraints(temporaryWidthConstraints)

            footerView.setNeedsLayout()
            footerView.layoutIfNeeded()

            let footerSize = footerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            var frame = footerView.frame
            frame.size.height = footerSize.height
            footerView.frame = frame

            self.tableFooterView = footerView

            footerView.removeConstraints(temporaryWidthConstraints)
            footerView.translatesAutoresizingMaskIntoConstraints = true
        }
}
