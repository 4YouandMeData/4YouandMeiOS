//
//  OptionButton.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/05/25.
//

import UIKit

/// A UIButton subclass with configurable image/text layout and alignment using UIButton.Configuration
final class OptionButton: UIButton {

    /// Layout variants for the button, allowing control of alignment
    enum LayoutStyle {
        case vertical(spacing: CGFloat,
                      verticalAlignment: UIControl.ContentVerticalAlignment = .center)
        case horizontal(spacing: CGFloat,
                        horizontalAlignment: UIControl.ContentHorizontalAlignment = .center)
        case textOnly
        case textLeft(padding: CGFloat)
        case textRight(padding: CGFloat)
    }

    /// Default content insets
    private static let defaultInsets = NSDirectionalEdgeInsets(
        top: 12, leading: 16, bottom: 12, trailing: 16
    )

    // MARK: - Public API

    /// The current layout style; applyConfiguration called on change
    var layoutStyle: LayoutStyle = .vertical(spacing: 16) {
        didSet { applyConfiguration() }
    }

    override var isSelected: Bool {
        didSet { applyConfiguration() }
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    /// Initial setup for configuration
    private func commonInit() {
        // Use a filled configuration to support background and insets
        var baseConfig = UIButton.Configuration.filled()
        baseConfig.background.cornerRadius = 12
        baseConfig.contentInsets = Self.defaultInsets
        self.configuration = baseConfig

        // Apply initial state and layout
        applyConfiguration()
    }

    // MARK: - Apply Config

    /// Applies colors and layout to the configuration; safe to call from didSet
    private func applyConfiguration() {
        guard var config = self.configuration else { return }

        // Appearance: background and foreground colors
        if isSelected {
            config.baseBackgroundColor = ColorPalette.color(withType: .primary)
            config.baseForegroundColor = ColorPalette.color(withType: .secondary)
        } else {
            config.baseBackgroundColor = ColorPalette.color(withType: .secondary)
            config.baseForegroundColor = ColorPalette.color(withType: .primary)
        }
        // Title text color transformer
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.foregroundColor = config.baseForegroundColor
            return outgoing
        }

        // Reset layout defaults
        config.imagePlacement = .leading
        config.imagePadding = 0
        config.contentInsets = Self.defaultInsets
        self.contentHorizontalAlignment = .center
        self.contentVerticalAlignment = .center

        // Apply layoutStyle specifics
        switch layoutStyle {
        case .vertical(let spacing, let vAlign):
            config.imagePlacement = .top
            config.imagePadding = spacing
            self.contentVerticalAlignment = vAlign
            self.contentHorizontalAlignment = .center

        case .horizontal(let spacing, let hAlign):
            config.imagePlacement = .leading
            config.imagePadding = spacing
            self.contentHorizontalAlignment = hAlign
            self.contentVerticalAlignment = .center

        case .textOnly:
            config.image = nil
            config.imagePadding = 0
            self.contentHorizontalAlignment = .center
            self.contentVerticalAlignment = .center

        case .textLeft(let padding):
            config.image = nil
            config.imagePadding = 0
            config.contentInsets = NSDirectionalEdgeInsets(
                top: Self.defaultInsets.top,
                leading: padding,
                bottom: Self.defaultInsets.bottom,
                trailing: Self.defaultInsets.trailing
            )
            self.contentHorizontalAlignment = .leading
            self.contentVerticalAlignment = .center

        case .textRight(let padding):
            config.image = nil
            config.imagePadding = 0
            config.contentInsets = NSDirectionalEdgeInsets(
                top: Self.defaultInsets.top,
                leading: Self.defaultInsets.leading,
                bottom: Self.defaultInsets.bottom,
                trailing: padding
            )
            self.contentHorizontalAlignment = .trailing
            self.contentVerticalAlignment = .center
        }

        // Assign updated configuration once
        self.configuration = config
    }

    // MARK: - Shadow Handling

    override func layoutSubviews() {
        super.layoutSubviews()
        // Apply shadow to the background view internally
        if let bg = subviews.first(where: { String(describing: type(of: $0)).contains("BackgroundView") }) {
            bg.layer.masksToBounds = false
            bg.layer.shadowColor = UIColor.black.cgColor
            bg.layer.shadowOpacity = 0.1
            bg.layer.shadowOffset = CGSize(width: 0, height: 2)
            bg.layer.shadowRadius = 4
        }
    }
}
