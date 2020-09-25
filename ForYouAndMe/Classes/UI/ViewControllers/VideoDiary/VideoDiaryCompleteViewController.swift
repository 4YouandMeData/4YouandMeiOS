//
//  VideoDiaryCompleteViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import Foundation

struct VideoDiaryCompleteData {
    let image: UIImage?
    let title: String
    let buttonText: String
}

public class VideoDiaryCompleteViewController: UIViewController {
    
    private let data: VideoDiaryCompleteData
    
    private let coordinator: VideoDiarySectionCoordinator
    private let analytics: AnalyticsService
    
    init(withData data: VideoDiaryCompleteData, coordinator: VideoDiarySectionCoordinator) {
        self.data = data
        self.coordinator = coordinator
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        scrollStackView.stackView.addBlankSpace(space: 160.0)
        // Image
        scrollStackView.stackView.addHeaderImage(image: self.data.image, height: 120.0)
        scrollStackView.stackView.addBlankSpace(space: 30.0)
        // Title
        scrollStackView.stackView.addLabel(withText: self.data.title,
                                           fontStyle: .title,
                                           colorType: .primaryText)
        
        // Bottom View
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground())
        buttonView.setButtonText(self.data.buttonText)
        buttonView.addTarget(target: self, action: #selector(self.buttonPressed))
            
        self.view.addSubview(buttonView)
        buttonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: buttonView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.videoDiaryComplete.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.navigationItem.hidesBackButton = true
    }
    
    // MARK: Actions
    
    @objc private func buttonPressed() {
        self.coordinator.onSuccessCompleted()
    }
}
