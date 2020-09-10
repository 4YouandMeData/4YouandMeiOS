//
//  StudyInfoViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import Foundation

import UIKit

class StudyInfoViewController: UIViewController {
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
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
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView)
        
        let contactInformation = GenericListItemView(withTopOffset: 20,
                                                     title: "Contact Information"/*StringsProvider.string(forKey: .studyInfoContactItem)*/,
                                                     templateImageName: .studyInfoContact,
                                                     colorType: .primary)
        self.scrollStackView.stackView.addArrangedSubview(contactInformation)
        
        let rewardsView = GenericListItemView(withTopOffset: 20,
                                                        title: "Rewards"/*StringsProvider.string(forKey: .studyInfoRewardsItem)*/,
                                                        templateImageName: .studyInfoRewards,
                                                        colorType: .primary)
        self.scrollStackView.stackView.addArrangedSubview(rewardsView)
        
        let faqView = GenericListItemView(withTopOffset: 20,
                                          title: "FAQ Page"/*StringsProvider.string(forKey: .studyInfoFaqItem)*/,
                                            templateImageName: .studyInfoFAQ,
                                            colorType: .primary)
        self.scrollStackView.stackView.addArrangedSubview(faqView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
}
