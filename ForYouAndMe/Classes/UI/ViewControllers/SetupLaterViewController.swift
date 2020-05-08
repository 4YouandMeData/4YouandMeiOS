//
//  SetupLaterViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 07/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

public class SetupLaterViewController: UIViewController {
    
    private let navigator: AppNavigator
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withStyle: GenericButtonStyles.darkBackgroundStyle, height: IntroViewController.bottomViewHeight)
        view.button.setTitle(StringsProvider.string(forKey: .setupLaterConfirmButton), for: .normal)
        view.button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        return view
    }()
    
    init() {
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addGradientView(GradientView(type: .defaultBackground))
        
        // ScrollView
        let scrollStackView = ScrollStackView(axis: .vertical)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0.0,
                                                                      left: Constants.Style.DefaultHorizontalMargins,
                                                                      bottom: 0.0,
                                                                      right: Constants.Style.DefaultHorizontalMargins),
                                                        excludingEdge: .bottom)
        scrollStackView.stackView.addBlankSpace(space: 16.0)
        
        scrollStackView.stackView.addHeaderImage(image: ImagePalette.image(withName: .fyamLogoGeneric))
        scrollStackView.stackView.addBlankSpace(space: 50.0)
        scrollStackView.stackView.addLabel(text: StringsProvider.string(forKey: .setupLaterBody),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left,
                           lineSpacing: 10.0)
        
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: self.confirmButtonView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.darkStyle)
        self.navigationItem.setHidesBackButton(true, animated: true)
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        self.navigator.goBackToWelcome(presenter: self)
    }
}
