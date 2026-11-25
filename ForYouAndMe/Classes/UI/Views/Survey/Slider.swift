//
//  Slider.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

import UIKit

class Slider: UISlider, UIGestureRecognizerDelegate {
    
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
    
    /// Distance moved by a VoiceOver increment or decrement. UISlider's default (about 10% of the range)
    /// can round back to the same scale value on short scales.
    var accessibilityStep: Float = 1
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var result = super.trackRect(forBounds: bounds)
        result.size.height = thickness // Added height for desired effect
        return result
    }
    
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        return super.thumbRect(forBounds: bounds, trackRect: rect, value: value).offsetBy(dx: 0, dy: 0)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        addGestureRecognizer(self.trackPan)
        addGestureRecognizer(self.trackTap)
    }
    
    /// Slider value under a horizontal position. The thumb centre travels from
    /// trackRect.minX + thumbWidth / 2 to trackRect.maxX - thumbWidth / 2; positions outside are clamped.
    static func trackValue(atX positionX: CGFloat, trackRect: CGRect, thumbWidth: CGFloat, minimum: Float, maximum: Float) -> Float {
        let usableWidth = max(trackRect.width - thumbWidth, 1)
        let fraction = min(max((positionX - trackRect.minX - thumbWidth / 2) / usableWidth, 0), 1)
        return minimum + Float(fraction) * (maximum - minimum)
    }
    
    /// True when a pan is more horizontal than vertical, so vertical swipes are left to the enclosing scroll view.
    static func isHorizontalPan(velocity: CGPoint) -> Bool {
        return abs(velocity.x) > abs(velocity.y)
    }
    
    // UISlider ignores touches off the thumb, and on iOS 27 a tracking session started there never ends.
    // These recognizers handle them (horizontal drag, tap); touches on the thumb keep native tracking.
    // iOS 27 skips the view's gestureRecognizerShouldBegin for them but asks their delegate.
    private lazy var trackPan: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(self.trackGesture(_:)))
        recognizer.delegate = self
        return recognizer
    }()
    
    private lazy var trackTap: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.trackGesture(_:)))
        recognizer.delegate = self
        return recognizer
    }()
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === self.trackPan || gestureRecognizer === self.trackTap else { return true }
        let thumbRect = self.thumbRect(forBounds: self.bounds, trackRect: self.trackRect(forBounds: self.bounds), value: self.value)
        let touchX = touch.location(in: self).x
        return touchX < thumbRect.minX || touchX > thumbRect.maxX
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === self.trackPan || gestureRecognizer === self.trackTap else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        // UISlider's thumb hit area is larger than thumbRect: a touch beside the thumb may already be tracked natively.
        guard !self.isTracking else { return false }
        return gestureRecognizer === self.trackTap || Self.isHorizontalPan(velocity: self.trackPan.velocity(in: self))
    }
    
    @objc func trackGesture(_ gestureRecognizer: UIGestureRecognizer) {
        let trackRect = self.trackRect(forBounds: self.bounds)
        let thumbWidth = self.thumbRect(forBounds: self.bounds, trackRect: trackRect, value: self.value).width
        self.value = Self.trackValue(atX: gestureRecognizer.location(in: self).x, trackRect: trackRect, thumbWidth: thumbWidth,
                                     minimum: self.minimumValue, maximum: self.maximumValue)
        self.sendActions(for: .valueChanged)
    }
    
    override func accessibilityIncrement() {
        self.value += self.accessibilityStep // UISlider clamps to the range
        self.sendActions(for: .valueChanged)
    }
    
    override func accessibilityDecrement() {
        self.value -= self.accessibilityStep
        self.sendActions(for: .valueChanged)
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
