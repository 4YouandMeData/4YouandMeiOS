//
//  Slider.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

import UIKit

enum SliderType {
    case scale
    case range
}

typealias SliderPointTapped = (CGPoint) -> Void

class Slider: UISlider {
    
    var thickness: CGFloat = 10 {
        didSet {
            setup()
        }
    }
    
    var sliderThumbImage: UIImage? {
        didSet {
            setup()
        }
    }
    
    var sliderType: SliderType = .scale
    
    var sliderPointTapped: SliderPointTapped?

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var result = super.trackRect(forBounds: bounds)
        result.size.height = thickness //added height for desired effect
        return result
    }
    
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        return super.thumbRect(forBounds: bounds, trackRect: rect, value: value).offsetBy(dx: 0, dy: 0)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard sliderType == .scale, let touch = touch else { return }
        
        let pointTapped: CGPoint = touch.location(in: self)
        sliderPointTapped?(pointTapped)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        let minTrackStartColor = ColorPalette.color(withType: .primary)
        let maxTrackEndColor = ColorPalette.color(withType: .inactive)
        self.setThumbImage(sliderThumbImage, for: .normal)
        self.minimumTrackTintColor = minTrackStartColor
        self.maximumTrackTintColor = maxTrackEndColor
    }
}
