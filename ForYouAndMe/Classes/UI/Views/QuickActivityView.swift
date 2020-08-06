//
//  QuickActivityView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 06/08/2020.
//

import UIKit

typealias QuickActivityViewSelectionCallback = ((QuickActivityOption) -> Void)

class QuickActivityView: UIView {
    
    private static let headerViewHeight: CGFloat = 120.0
    
    private static let expectedOptions: Int = 6
    private static let optionColumns: Int = 3
    
    private let gradientView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0))
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let button = GenericButtonView(withTextStyleCategory: .feed, fillWidth: false, topInset: 30.0, bottomInset: 0.0)
        button.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return button
    }()
    
    private var optionsViews: [QuickActivityOptionView] = []
    private var confirmButtonCallback: NotificationCallback?
    private var selectionCallback: QuickActivityViewSelectionCallback?
    
    init() {
        super.init(frame: .zero)
        
        // Panel View
        let backgroundView = UIView()
        self.addSubview(backgroundView)
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
        
        // Options
        let optionStackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        optionStackView.distribution = .fillEqually
        
        // Row = Ceil (total / columns)
        let optionRows = (Self.expectedOptions - 1 + Self.optionColumns) / Self.optionColumns
        
        for _ in 0..<optionRows {
            let optionRowStackView = UIStackView.create(withAxis: .horizontal, spacing: 8.0)
            optionRowStackView.distribution = .fillEqually
            optionStackView.addArrangedSubview(optionRowStackView)
            for _ in 0..<Self.optionColumns {
                let optionView = QuickActivityOptionView()
                optionRowStackView.addArrangedSubview(optionView)
                self.optionsViews.append(optionView)
            }
        }
        
        // Stack View
        let stackView = UIStackView.create(withAxis: .vertical)
        panelView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24.0, left: 8.0, bottom: 20.0, right: 8.0))
        
        // Content
        let headerView = UIView()
        let headerStackView = UIStackView.create(withAxis: .vertical)
        headerView.addSubview(headerStackView)
        headerView.autoSetDimension(.height, toSize: Self.headerViewHeight)
        headerStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0),
                                                     excludingEdge: .bottom)
        headerStackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        headerStackView.addArrangedSubview(self.titleLabel)
        headerStackView.addBlankSpace(space: 16.0)
        headerStackView.addArrangedSubview(self.subtitleLabel)
        
        stackView.addArrangedSubview(headerView)
        stackView.addBlankSpace(space: 12.0)
        stackView.addArrangedSubview(optionStackView)
        stackView.addArrangedSubview(self.confirmButtonView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(item: QuickActivity,
                        selectedOption: QuickActivityOption?,
                        confirmButtonCallback: @escaping NotificationCallback,
                        selectionCallback: @escaping QuickActivityViewSelectionCallback) {
        self.confirmButtonCallback = confirmButtonCallback
        self.selectionCallback = selectionCallback
        
        self.gradientView.updateParameters(colors: [item.startColor ?? ColorPalette.color(withType: .primary),
                                                    item.endColor ?? ColorPalette.color(withType: .gradientPrimaryEnd)])
        
        self.titleLabel.attributedText = NSAttributedString.create(withText: item.title ?? "",
                                                                   fontStyle: .header2,
                                                                   color: ColorPalette.color(withType: .secondaryText).applyAlpha(0.5))
        
        self.subtitleLabel.attributedText = NSAttributedString.create(withText: item.body ?? "",
                                                                      fontStyle: .paragraph,
                                                                      colorType: .secondaryText)
        
        let buttonText = item.buttonText ?? StringsProvider.string(forKey: .quickActivityButtonDefault)
        self.confirmButtonView.setButtonText(buttonText)
        
        self.optionsViews.enumerated().forEach { (index, optionView) in
            optionView.resetContent()
            if index < item.options.count {
                let option = item.options[index]
                optionView.display(item: option,
                                   isSelected: selectedOption == option,
                                   tapCallback: { [weak self] in
                                    self?.selectionCallback?(option)
                })
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func confirmButtonPressed() {
        self.confirmButtonCallback?()
    }
}
