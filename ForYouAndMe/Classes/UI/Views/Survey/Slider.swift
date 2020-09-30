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
        let minTrackEndColor = ColorPalette.color(withType: .inactive)
        let maxTrackEndColor = ColorPalette.color(withType: .primaryText)
        self.setThumbImage(sliderThumbImage, for: .normal)
        do {
            self.setMinimumTrackImage(try self.gradientImage(
                size: self.trackRect(forBounds: self.bounds).size,
                colorSet: [minTrackStartColor.cgColor, minTrackEndColor.cgColor]),
                                      for: .normal)
            self.maximumTrackTintColor = maxTrackEndColor
            
        } catch {
            self.minimumTrackTintColor = minTrackStartColor
            self.maximumTrackTintColor = maxTrackEndColor
        }
    }
    
    func gradientImage(size: CGSize, colorSet: [CGColor]) throws -> UIImage? {
        let layer = CAGradientLayer()
        layer.frame = CGRect(x:0, y:0, width:size.width, height: size.height)
        layer.cornerRadius = layer.frame.height / 2
        layer.masksToBounds = false
        layer.colors = colorSet
        layer.startPoint = CGPoint(x:0.0, y:0.5)
        layer.endPoint = CGPoint(x:1.0, y:0.5)
        UIGraphicsBeginImageContextWithOptions(size, layer.isOpaque, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets:
            UIEdgeInsets(top: 0, left: size.height, bottom: 0, right: size.height))
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
}
