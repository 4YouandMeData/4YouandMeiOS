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
        label.numberOfLines = 2
        return label
    }()
    
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
    
    // MARK: - Public Methods
    
    public func resetContent() {
        self.tapCallback = nil
        self.imageView.image = nil
        self.textLabel.text = nil
    }
    
    public func display(item: QuickActivityOption, isSelected: Bool, tapCallback: @escaping NotificationCallback) {
        self.option = item
            self.tapCallback = tapCallback
            self.setSelected(isSelected)
            self.textLabel.attributedText = NSAttributedString.create(
                withText: item.label ?? "",
                fontStyle: .header3,
                colorType: .secondaryText)
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
