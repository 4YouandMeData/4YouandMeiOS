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
    
    public init(axis: NSLayoutConstraint.Axis) {
        super.init(frame: .zero)
        
        self.addSubview(self.scrollView)
        self.scrollView.addSubview(self.stackView)
        self.stackView.axis = axis
        
        self.scrollView.autoPinEdgesToSuperviewEdges()
        self.stackView.autoPinEdgesToSuperviewEdges()
        
        switch axis {
        case .horizontal: self.stackView.autoMatch(.height, to: .height, of: self.scrollView)
        case .vertical: self.stackView.autoMatch(.width, to: .width, of: self.scrollView)
        @unknown default:
            assertionFailure("Unexpected axis")
            break
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
