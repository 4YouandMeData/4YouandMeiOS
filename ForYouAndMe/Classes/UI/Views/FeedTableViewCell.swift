//
//  FeedTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit

class FeedTableViewCell: UITableViewCell {

    private static let imageHeight: CGFloat = 56.0
    // FUAM-2932 compact pinned layout: hide the hero image (and its trailing
    // spacer) to shrink the card. UITableView.automaticDimension picks up the
    // change because the surrounding stack lays out vertically.
    private var imageBottomSpacer: UIView?

    private let gradientView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0))
    }()
    
    private lazy var feedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.height, toSize: Self.imageHeight)
        return imageView
    }()
    
    private lazy var feedTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var feedDescriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var buttonView: GenericButtonView = {
        let button = GenericButtonView(withTextStyleCategory: .feed,
                                       fillWidth: true,
                                       horizontalInset: 8.0,
                                       topInset: 30.0,
                                       bottomInset: 0.0)
        button.addTarget(target: self, action: #selector(self.buttonPressed))
        
        return button
    }()
    
    private lazy var skipButtonView: GenericButtonView = {
        let button = GenericButtonView(withTextStyleCategory: .feed,
                                       fillWidth: true,
                                       horizontalInset: 8.0,
                                       topInset: 30.0,
                                       bottomInset: 0.0)
        button.addTarget(target: self, action: #selector(self.skipButtonPressed))
        return button
    }()
    
    private lazy var horizontalStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8.0
        stack.alignment = .center
        stack.addArrangedSubview(self.buttonView)
        return stack
    }()
    
    private var buttonPressedCallback: NotificationCallback?
    private var skipButtonPressedCallback: NotificationCallback?

    // FUAM-3637: total horizontal inset around the title — 24pt background margins (both sides)
    // + 16pt stack insets (both sides). Used to derive the width the title must fit into.
    private static var titleHorizontalInset: CGFloat { 2 * Constants.Style.DefaultHorizontalMargins + 2 * 16.0 }

    // FUAM-3637: the untouched title, whether it must fit two lines, and the (title, width) pair
    // last fitted — so the systemLayoutSizeFitting refit is skipped when nothing changed and does
    // not loop (the attributedText setter invalidates layout unconditionally).
    private var feedTitleRawText: String?
    private var feedTitleLimitedToTwoLines: Bool = false
    private var feedTitleFittedText: String?
    private var feedTitleFittedWidth: CGFloat = 0.0
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .clear
        
        // Panel View
        let backgroundView = UIView()
        self.contentView.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24.0,
                                                                       left: Constants.Style.DefaultHorizontalMargins,
                                                                       bottom: 24.0,
                                                                       right: Constants.Style.DefaultHorizontalMargins))
        backgroundView.addShadowCell()
        
        let panelView = UIView()
        panelView.addGradientView(self.gradientView)
        self.gradientView.setContentHuggingPriority(UILayoutPriority(100), for: .vertical)
        self.gradientView.setContentCompressionResistancePriority(UILayoutPriority(100), for: .vertical)
        panelView.backgroundColor = ColorPalette.color(withType: .primary)
        panelView.layer.cornerRadius = 8.0
        panelView.layer.masksToBounds = true
        backgroundView.addSubview(panelView)
        panelView.autoPinEdgesToSuperviewEdges()
        
        // Stack View
        let stackView = UIStackView()
        stackView.axis = .vertical
        panelView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 30.0, left: 16.0, bottom: 30.0, right: 16.0))
        
        // Content
        stackView.addArrangedSubview(self.feedImageView)
        // Track the image-to-title spacer so compact pinned alerts can hide it
        // alongside the image (FUAM-2932).
        let imageSpacer = UIView()
        imageSpacer.backgroundColor = .clear
        imageSpacer.autoSetDimension(.height, toSize: 18.0)
        stackView.addArrangedSubview(imageSpacer)
        self.imageBottomSpacer = imageSpacer
        stackView.addArrangedSubview(self.feedTitleLabel)
        stackView.addBlankSpace(space: 12.0)
        stackView.addArrangedSubview(self.feedDescriptionLabel)
        
        self.horizontalStackView.axis = .horizontal
        self.horizontalStackView.distribution = .fillProportionally
        stackView.addArrangedSubview(horizontalStackView)
        self.horizontalStackView.addArrangedSubview(self.buttonView)
        self.horizontalStackView.addArrangedSubview(self.skipButtonView)
        
        self.buttonView.isHidden = true
        self.skipButtonView.isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Compact-pinned reuse safety: restore the hero image's spacer so a
        // recycled cell rendered as compact does not bleed into the next row.
        self.imageBottomSpacer?.isHidden = false
        // FUAM-3637: drop any fitted-title state so a recycled cell does not refit a stale title.
        self.feedTitleRawText = nil
        self.feedTitleLimitedToTwoLines = false
        self.feedTitleFittedText = nil
        self.feedTitleFittedWidth = 0.0
    }

    // FUAM-3637: the self-sizing measurement pass hands us the real content width — fit the
    // two-line title here, BEFORE super measures, so the committed cell height matches the shrunk
    // title instead of leaving permanent whitespace.
    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                          withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        self.fitFeedTitleIfNeeded(forContainerWidth: targetSize.width)
        return super.systemLayoutSizeFitting(targetSize,
                                             withHorizontalFittingPriority: horizontalFittingPriority,
                                             verticalFittingPriority: verticalFittingPriority)
    }

    /// FUAM-3637 rotation/width-change fallback: re-fit if the container width changed after the
    /// self-sizing pass. The (title, width) cache guard skips the no-op case so the attributedText
    /// setter cannot loop layout every frame.
    override func layoutSubviews() {
        super.layoutSubviews()
        self.fitFeedTitleIfNeeded(forContainerWidth: self.contentView.bounds.width)
    }

    private func fitFeedTitleIfNeeded(forContainerWidth containerWidth: CGFloat) {
        guard self.feedTitleLimitedToTwoLines, let title = self.feedTitleRawText else { return }
        let availableWidth = containerWidth - Self.titleHorizontalInset
        guard availableWidth > 0 else { return }
        guard self.feedTitleFittedText != title || self.feedTitleFittedWidth != availableWidth else { return }
        self.feedTitleFittedText = title
        self.feedTitleFittedWidth = availableWidth
        self.feedTitleLabel.attributedText = NSAttributedString.createFitted(withText: title,
                                                                             fontStyle: .header2,
                                                                             colorType: .secondaryText,
                                                                             availableWidth: availableWidth)
    }
    
    // MARK: - Public Methods
    
    public func display(data: Activity,
                        skippable: Bool = false,
                        buttonPressedCallback: @escaping NotificationCallback,
                        skipButtonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        self.skipButtonPressedCallback = skipButtonPressedCallback
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title, limitedToTwoLines: true)
        self.setFeedDescription(text: data.body)

        if nil != data.taskType {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .activityButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
            
            self.horizontalStackView.distribution = .fill

            if skippable {
                
                if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) == false {
                    self.horizontalStackView.addArrangedSubview(self.skipButtonView)
                }
                let skipText = StringsProvider.string(forKey: .skipActivityButtonDefault)
                self.skipButtonView.isHidden = false
                self.skipButtonView.setButtonText(skipText)
                
                self.horizontalStackView.distribution = .fillProportionally
                
            } else {
                
                if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) {
                    self.horizontalStackView.removeArrangedSubview(self.skipButtonView)
                    self.skipButtonView.removeFromSuperview()
                }
                
                self.horizontalStackView.distribution = .fill
            }
            
            self.horizontalStackView.isHidden = false
            
        } else {
            assert(data.buttonText == nil, "Existing button text for activity without activity type")
            self.buttonView.isHidden = true
        }
    }
    
    public func display(data: Survey,
                        skippable: Bool,
                        buttonPressedCallback: @escaping NotificationCallback,
                        skipButtonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        self.skipButtonPressedCallback = skipButtonPressedCallback
        
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title, limitedToTwoLines: true)
        self.setFeedDescription(text: data.body)

        let buttonText = data.buttonText ?? StringsProvider.string(forKey: .surveyButtonDefault)
        self.buttonView.isHidden = false
        self.buttonView.setButtonText(buttonText)
        
        self.horizontalStackView.distribution = .fill
        
        if skippable {
            
            if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) == false {
                self.horizontalStackView.addArrangedSubview(self.skipButtonView)
            }
            let skipText = StringsProvider.string(forKey: .skipActivityButtonDefault)
            self.skipButtonView.isHidden = false
            self.skipButtonView.setButtonText(skipText)
            
            self.horizontalStackView.distribution = .fillProportionally
            
        } else {
            
            if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) {
                self.horizontalStackView.removeArrangedSubview(self.skipButtonView)
                self.skipButtonView.removeFromSuperview()
            }
            
            self.horizontalStackView.distribution = .fill
        }
        
        self.horizontalStackView.isHidden = false
    }
    
    public func display(data: Educational, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        if nil != data.urlString {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .educationalButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            assert(data.buttonText == nil, "Existing button text for notifiable without urlString")
            self.buttonView.isHidden = true
        }
    }
    
    public func display(data: Alert, wehaveNoticed: Bool, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback

        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)

        if nil != data.urlString || wehaveNoticed {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .alertButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            assert(data.buttonText == nil, "Existing button text for notifiable without urlString")
            self.buttonView.removeFromSuperview()
        }
    }

    /// Display variant for pinned alerts (e.g. menstrual tracking feed card).
    /// Renders title/body, primary action ("Yes"), and an optional secondary action ("No")
    /// when `data.secondaryButtonText` is present. The BE-driven `layout` field
    /// switches between the standard hero card and the compact (image-less)
    /// variant — see FUAM-2932 / `AlertLayout`.
    public func display(pinnedAlert data: Alert,
                        onPrimary: @escaping NotificationCallback,
                        onSecondary: NotificationCallback?) {
        self.buttonPressedCallback = onPrimary
        self.skipButtonPressedCallback = onSecondary

        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        let isCompact = data.resolvedLayout == .compact
        if isCompact {
            // Compact card: skip the hero image and its 18pt spacer so the
            // card collapses to title + body + buttons height.
            self.feedImageView.isHidden = true
            self.imageBottomSpacer?.isHidden = true
        } else {
            self.setFeedImage(imageUrl: data.image)
            self.imageBottomSpacer?.isHidden = false
        }
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)

        let primaryText = data.buttonText ?? StringsProvider.string(forKey: .alertButtonDefault)
        self.buttonView.isHidden = false
        self.buttonView.setButtonText(primaryText)

        if let secondaryText = data.secondaryButtonText, onSecondary != nil {
            if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) == false {
                self.horizontalStackView.addArrangedSubview(self.skipButtonView)
            }
            self.skipButtonView.isHidden = false
            self.skipButtonView.setButtonText(secondaryText)
            self.horizontalStackView.distribution = .fillEqually
        } else {
            if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) {
                self.horizontalStackView.removeArrangedSubview(self.skipButtonView)
                self.skipButtonView.removeFromSuperview()
            }
            self.skipButtonView.isHidden = true
            self.horizontalStackView.distribution = .fill
        }

        self.horizontalStackView.isHidden = false
    }
    
    public func display(data: Reward, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        if nil != data.urlString {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .rewardButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            assert(data.buttonText == nil, "Existing button text for notifiable without urlString")
            self.buttonView.removeFromSuperview()
        }
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.buttonPressedCallback?()
    }
    
    @objc private func skipButtonPressed() {
        self.skipButtonPressedCallback?()
    }
    
    // MARK: - Private Methods
    
    /// Sets the card title. When `limitedToTwoLines` is true (activity and survey cards,
    /// FUAM-3637) the title is capped at two lines and the font is shrunk to fit them instead of
    /// growing the card or clipping — Dynamic Type included. The actual fit needs the content
    /// width, which only the self-sizing measurement pass knows, so the fitted string is applied in
    /// `fitFeedTitleIfNeeded`; here we just store the raw title and set an initial (unshrunk)
    /// truncating string. Since this cell class is shared across all feed card variants, the other
    /// branch restores the flexible multiline layout and clears the fit state on reuse.
    private func setFeedTitle(text: String?, limitedToTwoLines: Bool = false) {
        if let title = text {
            self.feedTitleLabel.isHidden = false
            // Invalidate the fit cache so the next measurement pass refits this title.
            self.feedTitleFittedText = nil
            self.feedTitleFittedWidth = 0.0
            let attributedTitle = NSAttributedString.create(withText: title,
                                                            fontStyle: .header2,
                                                            colorType: .secondaryText)
            if limitedToTwoLines {
                self.feedTitleRawText = title
                self.feedTitleLimitedToTwoLines = true
                self.feedTitleLabel.numberOfLines = 2
                self.feedTitleLabel.lineBreakMode = .byTruncatingTail
                self.feedTitleLabel.attributedText = attributedTitle.applyingLineBreakMode(.byTruncatingTail)
                self.setNeedsLayout()
            } else {
                // Non-limited variants (educational/alert/reward) keep the flexible multiline
                // layout; clear the fit state so a recycled cell does not refit a stale title.
                self.feedTitleRawText = nil
                self.feedTitleLimitedToTwoLines = false
                self.feedTitleLabel.numberOfLines = 0
                self.feedTitleLabel.attributedText = attributedTitle
            }
        } else {
            self.feedTitleLabel.isHidden = true
            self.feedTitleRawText = nil
            self.feedTitleLimitedToTwoLines = false
            self.feedTitleFittedText = nil
            self.feedTitleFittedWidth = 0.0
        }
    }
    
    private func setFeedDescription(text: String?) {
        if let body = text {
            self.feedDescriptionLabel.isHidden = false
            self.feedDescriptionLabel.attributedText = NSAttributedString.create(withText: body,
                                                                                 fontStyle: .paragraph,
                                                                                 colorType: .secondaryText)
        } else {
            self.feedDescriptionLabel.isHidden = true
        }
    }
    
    private func setFeedImage(imageUrl: URL?) {
        if let imageUrl = imageUrl {
            self.feedImageView.isHidden = false
            self.feedImageView.loadAsyncImage(withURL: imageUrl,
                                              placeHolderImage: Constants.Resources.AsyncImagePlaceholder,
                                              targetSize: CGSize(width: UIScreen.main.bounds.width, height: Self.imageHeight))
        } else {
            self.feedImageView.isHidden = true
        }
    }
    
    private func updateGradientView(startColor: UIColor?, endColor: UIColor?, singleColor: UIColor?) {
        if let startColor = startColor, let endColor = endColor {
            self.gradientView.updateParameters(colors: [startColor, endColor])
        } else {
            self.gradientView.updateParameters(colors: [singleColor ?? ColorPalette.color(withType: .primary),
                                                        singleColor ?? ColorPalette.color(withType: .gradientPrimaryEnd)])
        }
    }
}
