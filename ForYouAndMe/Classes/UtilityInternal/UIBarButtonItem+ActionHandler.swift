//
//  UIBarButtonItem+ActionHandler.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/12/24.
//

import UIKit
import ObjectiveC

// Helper class to hold the action closure
class BarButtonItemActionHandler {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func handleAction() {
        action()
    }
}

private var actionHandlerKey: UInt8 = 0

extension UIBarButtonItem {
    /// Initializes a UIBarButtonItem with a closure action
    ///
    /// - Parameters:
    ///   - image: The image to display on the button
    ///   - style: The style of the bar button item
    ///   - action: The closure to execute when the button is tapped
    convenience init(image: UIImage?, style: UIBarButtonItem.Style, action: @escaping () -> Void) {
        let handler = BarButtonItemActionHandler(action: action)
        self.init(image: image, style: style, target: handler, action: #selector(BarButtonItemActionHandler.handleAction))
        // Associate the handler with the bar button item to retain it
        objc_setAssociatedObject(self, &actionHandlerKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Initializes a UIBarButtonItem with a title and a closure action
    ///
    /// - Parameters:
    ///   - title: The title of the button
    ///   - style: The style of the bar button item
    ///   - action: The closure to execute when the button is tapped
    convenience init(title: String?, style: UIBarButtonItem.Style, action: @escaping () -> Void) {
        let handler = BarButtonItemActionHandler(action: action)
        self.init(title: title, style: style, target: handler, action: #selector(BarButtonItemActionHandler.handleAction))
        // Associate the handler with the bar button item to retain it
        objc_setAssociatedObject(self, &actionHandlerKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

