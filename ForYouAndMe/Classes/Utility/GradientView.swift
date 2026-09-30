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
    /// Kept so dynamic (light/dark) colors can be re-resolved on a trait change: a CAGradientLayer
    /// stores flat CGColors and, unlike a UIView's backgroundColor, never updates by itself.
    private var colors: [UIColor]

    init(colors: [UIColor], locations: [Double], startPoint: CGPoint, endPoint: CGPoint) {
        self.gradientMask = CAGradientLayer()
        self.colors = colors
        super.init(frame: .zero)

        self.gradientMask.startPoint = startPoint
        self.gradientMask.endPoint = endPoint
        self.gradientMask.locations = locations.map { NSNumber(value: $0)}
        self.applyColors()

        self.layer.addSublayer(self.gradientMask)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.gradientMask.frame = CGRect(x: 0.0, y: 0.0, width: self.frame.size.width, height: self.frame.size.height)
        CATransaction.commit()
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.applyColors()
        }
    }

    // MARK: - Public Methods
    
    func updateParameters(colors: [UIColor]? = nil, locations: [Double]? = nil, startPoint: CGPoint? = nil, endPoint: CGPoint? = nil) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let colors = colors {
            self.colors = colors
            self.gradientMask.colors = colors.map { $0.resolvedColor(with: self.traitCollection).cgColor }
        }
        if let locations = locations {
            self.gradientMask.locations = locations.map { NSNumber(value: $0)}
        }
        if let startPoint = startPoint {
            self.gradientMask.startPoint = startPoint
        }
        if let endPoint = endPoint {
            self.gradientMask.endPoint = endPoint
        }
        CATransaction.commit()
    }

    // MARK: - Private Methods

    private func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.gradientMask.colors = self.colors.map { $0.resolvedColor(with: self.traitCollection).cgColor }
        CATransaction.commit()
    }
}

public extension UIView {
    func addGradientView(_ gradientView: GradientView) {
        self.insertSubview(gradientView, at: 0)
        gradientView.autoPinEdgesToSuperviewEdges()
    }
}
