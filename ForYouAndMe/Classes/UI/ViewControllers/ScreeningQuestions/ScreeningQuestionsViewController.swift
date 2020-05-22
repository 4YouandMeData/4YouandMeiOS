//
//  ScreeningQuestionsViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

public class ScreeningQuestionsViewController: UIViewController {
    
    private let navigator: AppNavigator
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
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
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // TODO: Add screening questions
        
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.secondaryStyle)
        self.addCustomBackButton(withImage: ImagePalette.image(withName: .backButton))
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        // TODO: Navigate to result view
        print("TODO: Navigate to result view")
    }
}
