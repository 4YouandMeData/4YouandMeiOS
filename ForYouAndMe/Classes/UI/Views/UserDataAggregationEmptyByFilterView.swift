//
//  UserDataAggregationEmptyByFilterView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/06/21.
//

import UIKit

class UserDataAggregationEmptyByFilterView: UIView {
    
    private lazy var buttonView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .transparentBackground(shadow: false),
                                           horizontalInset: 0.0,
                                           topInset: 10.0,
                                           bottomInset: 10.0)
        buttonView.setButtonText(StringsProvider.string(forKey: .tabUserDataEmptyFilterButton))
        buttonView.addTarget(target: self, action: #selector(self.buttonPressed))
        return buttonView
    }()
    
    private let buttonCallback: NotificationCallback
    
    init(buttonCallback: @escaping NotificationCallback) {
        self.buttonCallback = buttonCallback
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.color(withType: .fourth)
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        self.addSubview(stackView)
        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 8.0, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 8.0, relation: .greaterThanOrEqual)
        stackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabUserDataEmptyFilterMessage),
                           fontStyle: .header3,
                           colorType: .primaryText)
        stackView.addArrangedSubview(self.buttonView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Actions
    
    @objc private func buttonPressed() {
        self.buttonCallback()
    }
}
