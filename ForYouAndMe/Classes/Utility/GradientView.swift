//
//  GradientView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

public class GradientView: UIView {
    
    private let gradientMask: CAGradientLayer
    
    init(colors: [UIColor], locations: [Double], startPoint: CGPoint, endPoint: CGPoint) {
        self.gradientMask = CAGradientLayer()
        super.init(frame: .zero)
        
        self.gradientMask.startPoint = startPoint
        self.gradientMask.endPoint = endPoint
        self.gradientMask.colors = colors.map { $0.cgColor }
        self.gradientMask.locations = locations.map { NSNumber(value: $0)}
        
        self.layer.addSublayer(self.gradientMask)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.gradientMask.frame = CGRect(x: 0.0, y: 0.0, width: self.frame.size.width, height: self.frame.size.height)
    }
}

public extension UIView {
    func addGradientView(_ gradientView: GradientView) {
        self.insertSubview(gradientView, at: 0)
        gradientView.autoPinEdgesToSuperviewEdges()
    }
}
