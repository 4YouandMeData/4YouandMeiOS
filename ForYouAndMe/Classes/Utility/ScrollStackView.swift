//
//  ScrollStackView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 07/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

public class ScrollStackView: UIView {
    
    public let scrollView = UIScrollView()
    public let stackView = UIStackView()
    
    // MARK: - Initialization
    
    public init(axis: NSLayoutConstraint.Axis, horizontalInset: CGFloat) {
        super.init(frame: .zero)
        
        self.addSubview(self.scrollView)
        self.scrollView.addSubview(self.stackView)
        self.stackView.axis = axis
        
        self.scrollView.autoPinEdgesToSuperviewEdges()
        self.stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                       left: horizontalInset,
                                                                       bottom: 0.0,
                                                                       right: horizontalInset))
        
        switch axis {
        case .horizontal: self.stackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        case .vertical: self.stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        @unknown default:
            assertionFailure("Unexpected axis")
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
