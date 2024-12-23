//
//  UILabel+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import UIKit

extension UILabel {
    func setTime(currentTime: Int,
                 totalTime: Int,
                 attributedTextStyle: AttributedTextStyle,
                 currentTimeAttributedTextStyle: AttributedTextStyle? = nil) {
        let currentSeconds = currentTime % 60
        let currentMinutes = (currentTime / 60) % 60
        let currentHours = (currentTime / 3600)
        
        let totalSeconds = totalTime % 60
        let totalMinutes = (totalTime / 60) % 60
        let totalHours = (totalTime / 3600)
        
        var currentTimeText = String(format: "%0.2d:%0.2d", currentMinutes, currentSeconds)
        var totalTimeText = String(format: "%0.1d:%0.2d", totalMinutes, totalSeconds)
        if totalHours > 0 {
            currentTimeText = String(format: "%0.1d:", currentHours) + currentTimeText
            totalTimeText = String(format: "%0.1d:", totalHours) + totalTimeText
        }
        
        let currentTimeAttributedTextStyle = currentTimeAttributedTextStyle ?? attributedTextStyle
        let currentTimeAttributedString = NSAttributedString.create(withText: currentTimeText,
                                                                    attributedTextStyle: currentTimeAttributedTextStyle)
        let totalTimeAttributedString = NSAttributedString.create(withText: " / \(totalTimeText)",
            attributedTextStyle: attributedTextStyle)
        
        let attributedText = NSMutableAttributedString(attributedString: currentTimeAttributedString)
        attributedText.append(totalTimeAttributedString)
        
        self.attributedText = attributedText
    }
    
    func setShortTime(duration: Int,
                      attributedTextStyle: AttributedTextStyle) {
        
        let currentSeconds = duration % 60
        let currentMinutes = (duration / 60) % 60
        let currentHours = (duration / 3600)
        
        var currentTimeText = String(format: "%0.2d:%0.2d", currentMinutes, currentSeconds)
        
        if currentHours > 0 {
            currentTimeText = String(format: "%0.1d:", currentHours) + currentTimeText
        }
        
        let currentTimeAttributedTextStyle = attributedTextStyle
        let currentTimeAttributedString = NSAttributedString.create(withText: currentTimeText,
                                                                    attributedTextStyle: currentTimeAttributedTextStyle)
        
        self.attributedText = currentTimeAttributedString
    }
    
    func setRecordTime(currentTime: Int,
                       attributedTextStyle: AttributedTextStyle,
                       currentTimeAttributedTextStyle: AttributedTextStyle? = nil) {
        let currentSeconds = currentTime % 60
        let currentMinutes = (currentTime / 60) % 60
        
        let currentTimeText = String(format: "%0.2d:%0.2d", currentMinutes, currentSeconds)
        
        let currentTimeAttributedTextStyle = currentTimeAttributedTextStyle ?? attributedTextStyle
        let currentTimeAttributedString = NSAttributedString.create(withText: currentTimeText,
                                                                    attributedTextStyle: currentTimeAttributedTextStyle)
        
        let attributedText = NSMutableAttributedString(attributedString: currentTimeAttributedString)
        
        self.attributedText = attributedText
    }
}
