//
//  QuickActivityOptionView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 06/08/2020.
//

import UIKit

class QuickActivityOptionView: UIView {
    
    private var option: QuickActivityOption?
    private var isSelected: Bool = false
    
    private static let maxImageHeight: CGFloat = 44.0
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let textLabel: UILabel = {
        let label = UILabel()
        // FUAM-3637: 2 lines, font shrunk to fit in layoutSubviews (same pattern as the
        // quick-activity card title), `.byTruncatingTail` as the below-floor fallback.
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    // FUAM-3637: raw label text + (text, width) fit cache — the fit needs the laid-out width
    // and must not re-run (and re-set attributedText) on every layout pass.
    private var rawLabelText: String?
    private var fittedLabelText: String?
    private var fittedLabelWidth: CGFloat = 0.0

    private var tapCallback: NotificationCallback?
    
    init() {
        super.init(frame: .zero)
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        stackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        
        let imageContainerView = UIView()
        imageContainerView.autoSetDimension(.height, toSize: Self.maxImageHeight)
        imageContainerView.addSubview(self.imageView)
        self.imageView.autoCenterInSuperview()
        self.imageView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        self.imageView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        self.imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0.0, relation: .greaterThanOrEqual)
        self.imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0.0, relation: .greaterThanOrEqual)
        stackView.addArrangedSubview(imageContainerView)
        
        stackView.addArrangedSubview(self.textLabel)
        
        let button = UIButton()
        self.addSubview(button)
        button.autoPinEdgesToSuperviewEdges()
        button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // FUAM-3637: fit the answer label to its two lines now that the width is known.
        // The stack view is pinned to the view edges, so the view width is the label budget.
        guard let text = self.rawLabelText else { return }
        let availableWidth = self.bounds.width
        guard availableWidth > 0 else { return }
        guard self.fittedLabelText != text || self.fittedLabelWidth != availableWidth else { return }
        self.fittedLabelText = text
        self.fittedLabelWidth = availableWidth
        self.textLabel.attributedText = NSAttributedString.createFitted(withText: text,
                                                                        fontStyle: .header3,
                                                                        colorType: .secondaryText,
                                                                        availableWidth: availableWidth)
    }

    // MARK: - Public Methods

    public func resetContent() {
        self.tapCallback = nil
        self.imageView.image = nil
        self.textLabel.text = nil
        self.rawLabelText = nil
        self.fittedLabelText = nil
        self.fittedLabelWidth = 0.0
    }

    public func display(item: QuickActivityOption, isSelected: Bool, tapCallback: @escaping NotificationCallback) {
        self.option = item
        self.tapCallback = tapCallback
        self.setSelected(isSelected)
        // FUAM-3637: store the raw label and set an initial (unshrunk) truncating string;
        // the real fit happens in layoutSubviews once the width is known.
        let rawLabel = item.label ?? ""
        self.rawLabelText = rawLabel
        self.fittedLabelText = nil
        self.fittedLabelWidth = 0.0
        self.textLabel.attributedText = NSAttributedString.create(
            withText: rawLabel,
            fontStyle: .header3,
            colorType: .secondaryText)
            .applyingLineBreakMode(.byTruncatingTail)
        self.setNeedsLayout()
    }
    
    // MARK: - Public Function
    public func setSelected(_ selected: Bool) {
        self.isSelected = selected
        guard let option = self.option else { return }
        self.imageView.loadAsyncImage(
            withURL: selected ? option.selectedImage : option.image,
            placeHolderImage: Constants.Resources.AsyncImagePlaceholder,
            targetSize: CGSize(width: UIScreen.main.bounds.width, height: Self.maxImageHeight)
        )
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.tapCallback?()
    }
}
