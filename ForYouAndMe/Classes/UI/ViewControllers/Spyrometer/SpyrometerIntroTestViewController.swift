//
//  SpyrometerIntroTestViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 19/03/25.
//

import Foundation

public class SpyrometerIntroTestViewController: UIViewController {
    
    /// Called when the scanning is completed and the user taps "Continue".
    var onGetStarted: (() -> Void)?
    
    /// Button to trigger connection (demo).
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: true ))
        return buttonView
    }()
    
    init(withTopOffset topOffset: CGFloat) {
        
        super.init(nibName: nil, bundle: nil)

        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 20.0, bottom: 0.0, right: 20.0),
                                               excludingEdge: .bottom)
        
        stackView.addBlankSpace(space: 40)
        stackView.addImage(withImage: ImagePalette.image(withName: .spiroIntroTestImage),
                           color: .clear,
                           sizeDimension: 60)
        stackView.addBlankSpace(space: 66)
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .spiroIntroTestTitle)),
                           fontStyle: .header2,
                           colorType: .primaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 20.0)
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .spiroIntroTestBody)),
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .justified)
        self.view.addSubview(self.footerView)
        
        // Connect button constraints.
        self.footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroGetStarted))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        self.footerView.addTarget(target: self, action: #selector(self.getStartedButtonTapped))
    }
    
    @objc private func getStartedButtonTapped() {
        onGetStarted?()
    }
}
