//
//  FeedTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit

class FeedTableViewCell: UITableViewCell {
    
    fileprivate static let optionWidth: CGFloat = 50.0
    
    private let gradientView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0))
    }()
    
    private lazy var taskImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.height, toSize: 56.0)
        return imageView
    }()
    
    private lazy var taskTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var taskDescriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var buttonView: GenericButtonView = {
        let button = GenericButtonView(withTextStyleCategory: .feed, fillWidth: false, topInset: 30.0, bottomInset: 0.0)
        button.addTarget(target: self, action: #selector(self.buttonPressed))
        return button
    }()
    
    private var buttonPressedCallback: NotificationCallback?
    
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
        stackView.addArrangedSubview(self.taskImageView)
        stackView.addBlankSpace(space: 18.0)
        stackView.addArrangedSubview(self.taskTitleLabel)
        stackView.addBlankSpace(space: 12.0)
        stackView.addArrangedSubview(self.taskDescriptionLabel)
        stackView.addArrangedSubview(self.buttonView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: Feed, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        self.gradientView.updateParameters(colors: [data.startColor, data.endColor])
        self.taskImageView.image = data.image
        self.taskTitleLabel.attributedText = NSAttributedString.create(withText: data.title,
                                                                       fontStyle: .header2,
                                                                       colorType: .secondaryText)
        self.taskDescriptionLabel.attributedText = NSAttributedString.create(withText: data.body,
                                                                             fontStyle: .paragraph,
                                                                             colorType: .secondaryText)
        if let buttonText = data.buttonText, nil != data.behavior {
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            self.buttonView.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.buttonPressedCallback?()
    }
}