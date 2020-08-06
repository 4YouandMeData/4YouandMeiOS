//
//  QuickActivityOptionView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 06/08/2020.
//

import UIKit

class QuickActivityOptionView: UIView {
    
    private static let imageHeight: CGFloat = 44.0
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.height, toSize: Self.imageHeight)
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
        stackView.addArrangedSubview(self.imageView)
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
        self.tapCallback = tapCallback
        self.imageView.image = isSelected ? item.selectedImage : item.image
        self.textLabel.attributedText = NSAttributedString.create(withText: item.label ?? "",
                                                                  fontStyle: .header3,
                                                                  colorType: .secondaryText)
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.tapCallback?()
    }
}
