//
//  SpyroBars.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 24/03/25.
//

import UIKit
import PureLayout

class SpyroBar: UIView {
    
    // MARK: - Constants
        
    private let totalBarHeight: CGFloat = 300   // total bar height
    private let barWidth: CGFloat = 69          // bar width
    
    // MARK: - Subviews
    
    private let topView = UIView()       // lighter portion
    private let bottomView = UIView()    // darker portion
    private let verticalLabel = UILabel()// vertical text label
    
    // We'll keep a reference to the bottomView's height constraint
    private var bottomHeightConstraint: NSLayoutConstraint!
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // add subviews
        addSubview(topView)
        addSubview(bottomView)
        addSubview(verticalLabel)
        
        // set background colors (example)
        topView.backgroundColor = UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)   // light green
        bottomView.backgroundColor = UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)// dark green
        
        // label: vertical text
        verticalLabel.text = "BAR"
        verticalLabel.textAlignment = .center
        verticalLabel.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        
        // layout
        layoutBar()
    }
    
    private func layoutBar() {
        // Fix the container's size
        autoSetDimensions(to: CGSize(width: barWidth, height: totalBarHeight))
        
        // Pin topView in alto, left e right
        topView.autoPinEdge(toSuperviewEdge: .top)
        topView.autoPinEdge(toSuperviewEdge: .left)
        topView.autoPinEdge(toSuperviewEdge: .right)
        
        // Pin bottomView in basso, left e right
        bottomView.autoPinEdge(toSuperviewEdge: .bottom)
        bottomView.autoPinEdge(toSuperviewEdge: .left)
        bottomView.autoPinEdge(toSuperviewEdge: .right)
        
        // La bottomView avrà un'altezza variabile.
        // Partiamo con 0 (la barra scura non visibile).
        bottomHeightConstraint = bottomView.autoSetDimension(.height, toSize: 0)
        
        // Per far sì che topView occupi il resto, pin il BORDO inferiore
        // di topView al BORDO superiore di bottomView. Così la topView si adatta dinamicamente.
        topView.autoPinEdge(.bottom, to: .top, of: bottomView)
        
        // La label al centro
        verticalLabel.autoCenterInSuperview()
    }
    
    // MARK: - Public
    
    /// Updates the bar based on a percentage (0..100),
    /// animating the darker bottom portion's height.
    func updatePercentage(_ percent: CGFloat) {
        let clamped = max(min(percent, 100), 0)
        // bottom portion: (clamped/100) * totalBarHeight
        let bottomHeight = (clamped / 100.0) * totalBarHeight
        
        UIView.animate(withDuration: 0.25) {
            self.bottomHeightConstraint.constant = bottomHeight
            self.layoutIfNeeded()
        }
    }
    
    /// (Optional) set text and top/bottom colors if needed
    func configureBar(text: String,
                      topColor: UIColor,
                      bottomColor: UIColor) {
        verticalLabel.text = text
        topView.backgroundColor = topColor
        bottomView.backgroundColor = bottomColor
    }
}
