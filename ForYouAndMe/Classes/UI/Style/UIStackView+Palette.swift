//
//  UIStackView+Palette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 21/05/2020.
//

import Foundation

extension UIStackView {
    func addLabel(withText text: String,
                  fontStyle: FontStyle,
                  colorType: ColorType,
                  textAlignment: NSTextAlignment = .center,
                  underlined: Bool = false,
                  numberOfLines: Int = 0,
                  horizontalInset: CGFloat = 0) {
        let attributedString = NSAttributedString.create(withText: text,
                                                         fontStyle: fontStyle,
                                                         colorType: colorType,
                                                         textAlignment: textAlignment,
                                                         underlined: underlined)
        self.addLabel(attributedString: attributedString,
                      numberOfLines: numberOfLines,
                      horizontalInset: horizontalInset)
    }
    
    func addLabel(withText text: String,
                  fontStyle: FontStyle,
                  color: UIColor,
                  textAlignment: NSTextAlignment = .center,
                  underlined: Bool = false,
                  numberOfLines: Int = 0,
                  horizontalInset: CGFloat = 0) {
        let attributedString = NSAttributedString.create(withText: text,
                                                         fontStyle: fontStyle,
                                                         color: color,
                                                         textAlignment: textAlignment,
                                                         underlined: underlined)
        self.addLabel(attributedString: attributedString,
                      numberOfLines: numberOfLines,
                      horizontalInset: horizontalInset)
    }
    
    func addImage(withImage image: UIImage?,
                  color: UIColor,
                  sizeDimension: CGFloat,
                  horizontalInset: CGFloat = 0) {
        let imageView = UIImageView(image: image)
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.width, toSize: sizeDimension)
        self.addArrangedSubview(imageView, horizontalInset: horizontalInset)
    }
    
    func addImage(withImage image: UIImage?,
                  color: UIColor,
                  sizeDimension: CGFloat,
                  verticalDimension: CGFloat,
                  horizontalInset: CGFloat = 0) {
        let imageView = UIImageView(image: image)
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.width, toSize: sizeDimension)
        imageView.autoSetDimension(.height, toSize: verticalDimension)
        self.addArrangedSubview(imageView, horizontalInset: horizontalInset)
    }
    
    func addImage(withImage image: UIImage?,
                  color: UIColor,
                  imageDimension: CGFloat,
                  circleColor: UIColor,
                  circleDiameter: CGFloat,
                  horizontalInset: CGFloat = 0) {
        
        // Create a container view for the circular background and the image
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.autoSetDimension(.width, toSize: circleDiameter)
        containerView.autoSetDimension(.height, toSize: circleDiameter)
        
        // Create the circular background view
        let circleView = UIView()
        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.backgroundColor = circleColor
        circleView.layer.cornerRadius = circleDiameter / 2
        circleView.layer.masksToBounds = true
        
        containerView.addSubview(circleView)
        circleView.autoAlignAxis(toSuperviewAxis: .horizontal)
        circleView.autoAlignAxis(toSuperviewAxis: .vertical)
        circleView.autoSetDimension(.width, toSize: circleDiameter)
        circleView.autoSetDimension(.height, toSize: circleDiameter)
        
        // Add the imageView on top of the circular background
        let imageView = UIImageView(image: image)
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(imageView)
        imageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        imageView.autoSetDimensions(to: CGSize(width: imageDimension, height: imageDimension))
        
        // Add the container view to the stack view
        self.addArrangedSubview(containerView, horizontalInset: horizontalInset)
    }
    
}
