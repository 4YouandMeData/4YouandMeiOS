//
//  UserDataAggregationErrorView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/10/2020.
//

import UIKit

class UserDataAggregationErrorView: UIView {
    
    private lazy var buttonView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .transparentBackground(shadow: false),
                                           horizontalInset: 0.0,
                                           topInset: 10.0,
                                           bottomInset: 10.0)
        buttonView.setButtonText(StringsProvider.string(forKey: .tabUserDataAggregationErrorButton))
        buttonView.addTarget(target: self, action: #selector(self.buttonPressed))
        return buttonView
    }()
    
    private let buttonCallback: NotificationCallback
    
    init(buttonCallback: @escaping NotificationCallback) {
        self.buttonCallback = buttonCallback
        super.init(frame: .zero)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabUserDataAggregationErrorTitle),
                           fontStyle: .header2,
                           colorType: .primaryText)
        stackView.addBlankSpace(space: 10.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabUserDataAggregationErrorBody),
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
