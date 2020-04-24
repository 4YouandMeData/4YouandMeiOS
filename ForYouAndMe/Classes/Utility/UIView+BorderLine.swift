//
//  UIView+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

enum UIViewBorderLineHorizontalPosition {
    case top, bottom
}

enum UIViewBorderLineVerticalPosition {
    case left, right
}

extension UIView {
    static func createHorizontalBorderLine(withColor color: UIColor, height: CGFloat = 1) -> UIView {
        let borderLineView = UIView()
        borderLineView.backgroundColor = color
        borderLineView.autoSetDimension(.height, toSize: height)
        return borderLineView
    }
    
    static func createVerticalBorderLine(withColor color: UIColor, width: CGFloat = 1) -> UIView {
        let borderLineView = UIView()
        borderLineView.backgroundColor = color
        borderLineView.autoSetDimension(.height, toSize: width)
        return borderLineView
    }
    
    func addHorizontalBorderLine(position: UIViewBorderLineHorizontalPosition,
                                 leftMargin: CGFloat,
                                 rightMargin: CGFloat,
                                 color: UIColor,
                                 height: CGFloat = 1) {
        let borderLineView = UIView.createHorizontalBorderLine(withColor: color, height: height)
        self.addSubview(borderLineView)
        let edges = UIEdgeInsets(top: 0, left: leftMargin, bottom: 0, right: rightMargin)
        switch position {
        case .top: borderLineView.autoPinEdgesToSuperviewEdges(with: edges, excludingEdge: .bottom)
        case .bottom: borderLineView.autoPinEdgesToSuperviewEdges(with: edges, excludingEdge: .top)
        }
    }
    
    func addVerticalBorderLine(position: UIViewBorderLineVerticalPosition,
                               topMargin: CGFloat,
                               bottomMargin: CGFloat,
                               color: UIColor,
                               width: CGFloat = 1) {
        let borderLineView = UIView.createVerticalBorderLine(withColor: color, width: width)
        self.addSubview(borderLineView)
        let edges = UIEdgeInsets(top: topMargin, left: 0, bottom: bottomMargin, right: 0)
        switch position {
        case .left: borderLineView.autoPinEdgesToSuperviewEdges(with: edges, excludingEdge: .trailing)
        case .right: borderLineView.autoPinEdgesToSuperviewEdges(with: edges, excludingEdge: .leading)
        }
    }
}
