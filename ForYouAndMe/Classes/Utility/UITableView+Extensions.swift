//
//  UITableView+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 12/06/2020.
//

import UIKit

public extension UITableView {
    func sizeHeaderToFit() {
        if let headerView = self.tableHeaderView {
            headerView.setNeedsLayout()
            headerView.layoutIfNeeded()
            
            let height = headerView.systemLayoutSizeFitting(CGSize(width: self.frame.width, height: 0)).height
            var frame = headerView.frame
            frame.size.height = height
            headerView.frame = frame
            
            self.tableHeaderView = headerView
        }
    }
}
