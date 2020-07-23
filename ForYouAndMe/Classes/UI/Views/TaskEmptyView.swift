//
//  TaskEmptyView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit

class TaskEmptyView: UIView {
    
    private lazy var buttonView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false),
                                           horizontalInset: 0.0,
                                           topInset: 0.0,
                                           bottomInset: 0.0)
        buttonView.setButtonText(StringsProvider.string(forKey: .tabTaskEmptyButton))
        buttonView.addTarget(target: self, action: #selector(self.buttonPressed))
        return buttonView
    }()
    
    private let buttonCallback: NotificationCallback
    
    init(buttonCallback: @escaping NotificationCallback) {
        self.buttonCallback = buttonCallback
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 80.0, left: 30.0, bottom: 0.0, right: 30.0), excludingEdge: .bottom)
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabTaskEmptyTitle), fontStyle: .title, colorType: .primaryText)
        stackView.addBlankSpace(space: 20.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabTaskEmptySubtitle), fontStyle: .paragraph, colorType: .primaryText)
        stackView.addBlankSpace(space: 30.0)
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
