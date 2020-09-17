//
//  StudyInfoViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit

class StudyInfoViewController: UIViewController {
    
    private let navigator: AppNavigator

    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init() {
       self.navigator = Services.shared.navigator
       super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
           fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = StudyInfoHeaderView()
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        
        var title = StringsProvider.string(forKey: .studyInfoContactTitle)
        let contactInformation = GenericListItemView(withTitle: title,
            templateImageName: .studyInfoContact,
            colorType: .primary,
            gestureCallback: { [weak self] in
                let page = Page(id: "contact", title: "Contact", body: Constants.Test.LoremIpsum)
                self?.showPage(page: page, isModal: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(contactInformation)
        
        title = StringsProvider.string(forKey: .studyInfoRewardsTitle)
        let rewardsView = GenericListItemView(withTitle: title,
            templateImageName: .studyInfoRewards,
            colorType: .primary,
            gestureCallback: { [weak self] in
                let page = Page(id: "rewards", title: "Rewards", body: Constants.Test.LoremIpsum)
                self?.showPage(page: page, isModal: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(rewardsView)
        
        title = StringsProvider.string(forKey: .studyInfoFaqTitle)
        let faqView = GenericListItemView(withTitle: title,
            templateImageName: .studyInfoFAQ,
            colorType: .primary,
            gestureCallback: { [weak self] in
                let page = Page(id: "faq", title: "FAQ", body: Constants.Test.LoremIpsum)
                self?.showPage(page: page, isModal: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(faqView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    private func showPage(page: Page, isModal: Bool) {
        self.navigator.showInfoDetailPage(presenter: self, page: page, isModal: isModal)
    }
}
