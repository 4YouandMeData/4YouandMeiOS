//
//  UILabelInteractionManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 13/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

typealias UILabelInteractionCallback = ((String) -> Void)

public class UILabelInteractionManager {
    
    private let label: UILabel
    private let text: String
    private let lineSpacing: CGFloat
    private let normalTextFont: UIFont
    private let normalTextColor: UIColor
    private let interactableFont: UIFont
    private let interactableColor: UIColor
    private let interactableUnderline: Bool
    private let interactionCallback: UILabelInteractionCallback
    private let interactableStrings: [String]
    
    init(withLabel label: UILabel,
         text: String,
         lineSpacing: CGFloat,
         normalTextFont: UIFont,
         normalTextColor: UIColor,
         interactableFont: UIFont,
         interactableColor: UIColor,
         interactableUnderline: Bool,
         interactionCallback: @escaping UILabelInteractionCallback,
         interactableStrings: [String]) {
        self.label = label
        self.text = text
        self.lineSpacing = lineSpacing
        self.normalTextFont = normalTextFont
        self.normalTextColor = normalTextColor
        self.interactableFont = interactableFont
        self.interactableColor = interactableColor
        self.interactableUnderline = interactableUnderline
        self.interactionCallback = interactionCallback
        self.interactableStrings = interactableStrings
        
        // Refresh label
        self.refreshLabel()
        
        // Add tap gesture recognizer
        self.label.isUserInteractionEnabled = true
        self.label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapLabel(gesture:))))
    }
    
    public func refreshLabel() {
        
        // Force lineBreakMode to work wrapping to handle correct tap position
        if self.label.lineBreakMode != .byWordWrapping {
            assertionFailure("UILabelInteractionManager - Needed Word Wrapping Line Break Mode")
            self.label.lineBreakMode = .byWordWrapping
        }
        
        // Define attributed string
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = self.lineSpacing
        
        let attributedString = NSMutableAttributedString(string: self.text, attributes: [
            .font: self.normalTextFont,
            .foregroundColor: self.normalTextColor,
            .paragraphStyle: paragraphStyle
        ])
        
        self.interactableStrings.forEach { iteractableString in
            let range = (self.text as NSString).range(of: iteractableString)
            attributedString.addAttribute(.font, value: self.interactableFont, range: range)
            attributedString.addAttribute(.foregroundColor, value: self.interactableColor, range: range)
            if self.interactableUnderline {
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        self.label.attributedText = attributedString
    }
    
    // MARK: - Actions
    
    @objc private func tapLabel(gesture: UITapGestureRecognizer) {
        if let text = self.label.text {
            if let iteractableString = self.interactableStrings.first(where: { [weak self] iteractableString -> Bool in
                guard let self = self else { return false }
                let range = (text as NSString).range(of: iteractableString)
                return gesture.didTapAttributedTextInLabel(label: self.label, inRange: range)
            }) {
                self.interactionCallback(iteractableString)
            }
        }
    }
}

fileprivate extension UITapGestureRecognizer {
    func didTapAttributedTextInLabel(label: UILabel, inRange targetRange: NSRange) -> Bool {
        // Create instances of NSLayoutManager, NSTextContainer and NSTextStorage
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize.zero)
        let textStorage = NSTextStorage(attributedString: label.attributedText!)
        
        // Configure layoutManager and textStorage
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // Configure textContainer
        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        let labelSize = label.bounds.size
        textContainer.size = labelSize
        
        // Find the tapped character location and compare it to the specified range
        let locationOfTouchInLabel = self.location(in: label)
        let textBoundingBox = layoutManager.usedRect(for: textContainer)
        let textContainerOffset = CGPoint(x: (labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
                                          y: (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y)
        let locationOfTouchInTextContainer = CGPoint(x: locationOfTouchInLabel.x - textContainerOffset.x, y:
            locationOfTouchInLabel.y - textContainerOffset.y)
        let indexOfCharacter = layoutManager.characterIndex(for: locationOfTouchInTextContainer,
                                                            in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        return NSLocationInRange(indexOfCharacter, targetRange)
    }
}
