//
//  VideoDiaryIntroViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import Foundation

struct VideoDiaryIntroData {
    
    struct Paragraph {
        let title: String
        let body: String
    }
    
    let image: UIImage?
    let title: String
    let paragraphs: [Paragraph]
    let buttonText: String
}

public class VideoDiaryIntroViewController: UIViewController {
    
    private let data: VideoDiaryIntroData
    
    private let coordinator: VideoDiarySectionCoordinator
    
    init(withData data: VideoDiaryIntroData, coordinator: VideoDiarySectionCoordinator) {
        self.data = data
        self.coordinator = coordinator
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
        
        scrollStackView.stackView.addBlankSpace(space: 50.0)
        // Image
        scrollStackView.stackView.addHeaderImage(image: self.data.image, height: 54.0)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Title
        scrollStackView.stackView.addLabel(withText: self.data.title,
                                           fontStyle: .title,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        
        self.data.paragraphs.forEach { paragraph in
            scrollStackView.stackView.addBlankSpace(space: 40.0)
            // Title
            scrollStackView.stackView.addLabel(withText: paragraph.title,
                                               fontStyle: .paragraph,
                                               colorType: .fourthText,
                                               textAlignment: .left)
            scrollStackView.stackView.addBlankSpace(space: 16.0)
            // Body
            scrollStackView.stackView.addLabel(withText: paragraph.body,
                                               fontStyle: .paragraph,
                                               colorType: .primaryText,
                                               textAlignment: .left)
        }
        
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        
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
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomCloseButton()
    }
    
    // MARK: Actions
    
    @objc private func buttonPressed() {
        self.coordinator.onIntroPageCompleted()
    }
}
