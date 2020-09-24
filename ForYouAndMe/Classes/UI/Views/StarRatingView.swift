//
//  StarRatingView.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 23/09/2020.
//

import UIKit

@objc public protocol StarRatingViewDelegate {
    /// Returns the rating value when touch events end
    @objc optional func floatRatingView(_ ratingView: StarRatingView, didUpdate rating: Double)
    
    /// Returns the rating value as the user pans
    @objc optional func floatRatingView(_ ratingView: StarRatingView, isUpdating rating: Double)
}

/// A simple rating view that can set whole, half or floating point ratings.
@objcMembers
open class StarRatingView: UIView {
    
    // MARK: Properties
    
    open weak var delegate: StarRatingViewDelegate?
    
    /// Array of empty image views
    private var emptyImageViews: [UIImageView] = []
    
    /// Array of full image views
    private var fullImageViews: [UIImageView] = []
    
    /// Sets the empty image (e.g. a star outline)
    open var emptyImage: UIImage? {
        didSet {
            // Update empty image views
            for imageView in emptyImageViews {
                imageView.image = emptyImage
            }
            refresh()
        }
    }
    
    /// Sets the full image that is overlayed on top of the empty image.
    /// Should be same size and shape as the empty image.
    open var fullImage: UIImage? {
        didSet {
            // Update full image views
            for imageView in fullImageViews {
                imageView.image = fullImage
            }
            refresh()
        }
    }
    
    /// Sets the empty and full image view content mode.
    open var imageContentMode: UIView.ContentMode = .scaleAspectFit
    
    /// Minimum rating.
    open var minRating: Int = 0 {
        didSet {
            // Update current rating if needed
            if rating < Double(minRating) {
                rating = Double(minRating)
                refresh()
            }
        }
    }
    
    /// Max rating value.
    open var maxRating: Int = 5 {
        didSet {
            if maxRating != oldValue {
                removeImageViews()
                initImageViews()
                
                // Relayout and refresh
                setNeedsLayout()
                refresh()
            }
        }
    }
    
    /// Minimum image size.
    open var minImageSize = CGSize(width: 5.0, height: 5.0)
    
    /// Set the current rating.
    open var rating: Double = 0 {
        didSet {
            if rating != oldValue {
                refresh()
            }
        }
    }
    
    /// Sets whether or not the rating view can be changed by panning.
    open var editable = true
    
    // MARK: Type
    @objc public enum StarRatingViewType: Int {
        /// Integer rating
        case wholeRatings
        /// Double rating in increments of 0.5
        case halfRatings
        /// Double rating
        case floatRatings
        
        /// Returns true if rating can contain decimal places
        func supportsFractions() -> Bool {
            return self == .halfRatings || self == .floatRatings
        }
    }
    
    /// Float rating view type
    open var type: StarRatingViewType = .wholeRatings
    
    // MARK: Initializations
    
    required override public init(frame: CGRect) {
        super.init(frame: frame)
        
        initImageViews()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Helper methods
    private func initImageViews() {
        guard emptyImageViews.isEmpty && fullImageViews.isEmpty else {
            return
        }
        
        // Add new image views
        for _ in 0..<maxRating {
            let emptyImageView = UIImageView()
            emptyImageView.contentMode = imageContentMode
            emptyImageView.image = emptyImage
            emptyImageViews.append(emptyImageView)
            addSubview(emptyImageView)
            
            let fullImageView = UIImageView()
            fullImageView.contentMode = imageContentMode
            fullImageView.image = fullImage
            fullImageViews.append(fullImageView)
            addSubview(fullImageView)
        }
    }
    
    private func removeImageViews() {
        // Remove old image views
        for idx in 0..<emptyImageViews.count {
            var imageView = emptyImageViews[idx]
            imageView.removeFromSuperview()
            imageView = fullImageViews[idx]
            imageView.removeFromSuperview()
        }
        emptyImageViews.removeAll(keepingCapacity: false)
        fullImageViews.removeAll(keepingCapacity: false)
    }
    
    // Refresh hides or shows full images
    private func refresh() {
        for idx in 0..<fullImageViews.count {
            let imageView = fullImageViews[idx]
            
            if rating >= Double(idx+1) {
                imageView.layer.mask = nil
                imageView.isHidden = false
            } else if rating > Double(idx) && rating < Double(idx+1) {
                // Set mask layer for full image
                let maskLayer = CALayer()
                maskLayer.frame = CGRect(x: 0,
                                         y: 0,
                                         width: CGFloat(rating-Double(idx))*imageView.frame.size.width,
                                         height: imageView.frame.size.height)
                maskLayer.backgroundColor = UIColor.black.cgColor
                imageView.layer.mask = maskLayer
                imageView.isHidden = false
            } else {
                imageView.layer.mask = nil
                imageView.isHidden = true
            }
        }
    }
    
    // Calculates the ideal ImageView size in a given CGSize
    private func sizeForImage(_ image: UIImage, inSize size: CGSize) -> CGSize {
        let imageRatio = image.size.width / image.size.height
        let viewRatio = size.width / size.height
        
        if imageRatio < viewRatio {
            let scale = size.height / image.size.height
            let width = scale * image.size.width
            
            return CGSize(width: width, height: size.height)
        } else {
            let scale = size.width / image.size.width
            let height = scale * image.size.height
            
            return CGSize(width: size.width, height: height)
        }
    }
    
    // Calculates new rating based on touch location in view
    private func updateLocation(_ touch: UITouch) {
        guard editable else {
            return
        }
        
        let touchLocation = touch.location(in: self)
        var newRating: Double = 0
        for idx in stride(from: (maxRating-1), through: 0, by: -1) {
            let imageView = emptyImageViews[idx]
            guard touchLocation.x > imageView.frame.origin.x else {
                continue
            }
            
            // Find touch point in image view
            let newLocation = imageView.convert(touchLocation, from: self)
            
            // Find decimal value for float or half rating
            if imageView.point(inside: newLocation, with: nil) && (type.supportsFractions()) {
                let decimalNum = Double(newLocation.x / imageView.frame.size.width)
                newRating = Double(idx) + decimalNum
                if type == .halfRatings {
                    newRating = Double(idx) + (decimalNum > 0.75 ? 1 : (decimalNum > 0.25 ? 0.5 : 0))
                }
            } else {
                // Whole rating
                newRating = Double(idx) + 1.0
            }
            break
        }
        
        // Check min rating
        rating = newRating < Double(minRating) ? Double(minRating) : newRating
        
        // Update delegate
        delegate?.floatRatingView?(self, isUpdating: rating)
    }
    
    // MARK: UIView
    
    // Override to calculate ImageView frames
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        guard let emptyImage = emptyImage else {
            return
        }
        
        let desiredImageWidth = frame.size.width / CGFloat(emptyImageViews.count)
        let maxImageWidth = max(minImageSize.width, desiredImageWidth)
        let maxImageHeight = max(minImageSize.height, frame.size.height)
        let imageViewSize = sizeForImage(emptyImage, inSize: CGSize(width: maxImageWidth, height: maxImageHeight))
        let imageXOffset = (frame.size.width/2 - (imageViewSize.width * CGFloat(emptyImageViews.count))) /
            CGFloat((emptyImageViews.count - 1))
        let halfImages = CGFloat(emptyImageViews.count)/2
        let totalOffset = CGFloat(imageXOffset) * (floor(halfImages))
        
        let xOffset = frame.size.width/2 - (imageViewSize.width * CGFloat(halfImages)) - totalOffset
        
        for idx in 0..<maxRating {
            let imageFrame = CGRect(x: idx == 0 ? xOffset : xOffset + CGFloat(idx)*(imageXOffset+imageViewSize.width),
                                    y: 0,
                                    width: imageViewSize.width,
                                    height: imageViewSize.height)
            
            var imageView = emptyImageViews[idx]
            imageView.frame = imageFrame
            
            imageView = fullImageViews[idx]
            imageView.frame = imageFrame
        }
        
        refresh()
    }
    
    // MARK: Touch events
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        updateLocation(touch)
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        updateLocation(touch)
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Update delegate
        delegate?.floatRatingView?(self, didUpdate: rating)
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Update delegate
        delegate?.floatRatingView?(self, didUpdate: rating)
    }
}
