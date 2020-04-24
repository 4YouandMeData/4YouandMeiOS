//
//  UIStackView+Extension.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

public extension UIStackView {
    func addBlankSpace(space: CGFloat) {
        let view = UIView()
        view.backgroundColor = .clear
        let attribute = self.axis == .vertical ? NSLayoutConstraint.Attribute.height : NSLayoutConstraint.Attribute.width
        NSLayoutConstraint.activate([NSLayoutConstraint(item: view,
                                                        attribute: attribute,
                                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                                        toItem: nil,
                                                        attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                                                        multiplier: 1,
                                                        constant: space)])
        self.addArrangedSubview(view)
    }
    
    func addArrangedSubview(_ view: UIView, horizontalInset: CGFloat) {
        self.addArrangedSubview(view, leftInset: horizontalInset, rightInset: horizontalInset)
    }
    
    func addArrangedSubview(_ view: UIView, leftInset: CGFloat, rightInset: CGFloat) {
        if leftInset > 0.0 || rightInset > 0.0 {
            let containerView = view.embedInView(withInsets: UIEdgeInsets(top: 0.0,
                                                                          left: leftInset,
                                                                          bottom: 0.0,
                                                                          right: rightInset))
            self.addArrangedSubview(containerView)
        } else {
            self.addArrangedSubview(view)
        }
    }
    
    func addLabel(text: String,
                  font: UIFont,
                  textColor: UIColor,
                  textAlignment: NSTextAlignment = .center,
                  numberOfLines: Int = 0,
                  underlined: Bool = false,
                  horizontalInset: CGFloat = 0) {
        let label = self.getLabel(text: text,
                                  font: font,
                                  textColor: textColor,
                                  textAlignment: textAlignment,
                                  numberOfLines: numberOfLines,
                                  underlined: underlined)
        self.addArrangedSubview(label, horizontalInset: horizontalInset)
    }
    
    func addHeaderImage(image: UIImage?, height: CGFloat? = nil, horizontalInset: CGFloat = 0) {
        let imageContainerView = UIView()
        imageContainerView.backgroundColor = UIColor.clear
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageContainerView.addSubview(imageView)
        imageView.autoPinEdge(toSuperviewEdge: .top)
        imageView.autoPinEdge(toSuperviewEdge: .bottom)
        imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: horizontalInset, relation: .greaterThanOrEqual)
        imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: horizontalInset, relation: .greaterThanOrEqual)
        if let height = height {
            imageView.autoSetDimension(.height, toSize: height)
        }
        self.addArrangedSubview(imageContainerView)
    }
    
    func addTextualSeparator(lineColor: UIColor,
                             text: String,
                             font: UIFont,
                             textColor: UIColor,
                             textAlignment: NSTextAlignment = .center,
                             numberOfLines: Int = 0,
                             underlined: Bool = false,
                             horizontalSpacing: CGFloat = 16,
                             horizontalInset: CGFloat = 0) {
        let stackView = UIStackView()
        stackView.spacing = horizontalSpacing
        stackView.distribution = .fill
        stackView.axis = .horizontal
        
        let lineViewBuilder: (() -> UIView) = {
            let lineContainerView = UIView()
            lineContainerView.backgroundColor = UIColor.clear
            let lineView = UIView()
            lineView.backgroundColor = lineColor
            lineView.autoSetDimension(.height, toSize: 1.0)
            lineContainerView.addSubview(lineView)
            lineView.autoPinEdge(toSuperviewEdge: .leading)
            lineView.autoPinEdge(toSuperviewEdge: .trailing)
            lineView.autoAlignAxis(toSuperviewAxis: .horizontal)
            lineView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
            lineView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
            lineView.setContentCompressionResistancePriority(UILayoutPriority(200), for: .horizontal)
            lineView.setContentHuggingPriority(UILayoutPriority(200), for: .horizontal)
            return lineContainerView
        }
        
        stackView.addArrangedSubview(lineViewBuilder())
        
        let labelContainerView = UIView()
        labelContainerView.backgroundColor = UIColor.clear
        stackView.addArrangedSubview(labelContainerView)
        labelContainerView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        let label = self.getLabel(text: text,
                                  font: font,
                                  textColor: textColor,
                                  textAlignment: textAlignment,
                                  numberOfLines: numberOfLines,
                                  underlined: underlined)
        label.setContentCompressionResistancePriority(UILayoutPriority(300), for: .horizontal)
        label.setContentHuggingPriority(UILayoutPriority(300), for: .horizontal)
        labelContainerView.addSubview(label)
        label.autoPinEdgesToSuperviewEdges()
        
        stackView.addArrangedSubview(lineViewBuilder())
        
        self.addArrangedSubview(stackView, horizontalInset: horizontalInset)
    }
    
    private func getLabel(text: String,
                          font: UIFont,
                          textColor: UIColor,
                          textAlignment: NSTextAlignment = .center,
                          numberOfLines: Int = 0,
                          underlined: Bool = false) -> UILabel {
        let label = UILabel()
        if underlined {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = textAlignment
            let attributedText = NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
            label.attributedText = attributedText
            label.numberOfLines = numberOfLines
        } else {
            label.text = text
            label.font = font
            label.textColor = textColor
            label.textAlignment = textAlignment
            label.numberOfLines = numberOfLines
        }
        return label
    }
}

fileprivate extension UIView {
    func embedInView(withInsets insets: UIEdgeInsets) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.addSubview(self)
        self.autoPinEdgesToSuperviewEdges(with: insets)
        return containerView
    }
}
