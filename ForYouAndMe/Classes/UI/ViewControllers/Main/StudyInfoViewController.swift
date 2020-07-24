//
//  StudyInfoViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import Foundation

import UIKit

class StudyInfoViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = StudyInfoHeaderView()
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        let comingSoonLabel = UILabel()
        self.view.addSubview(comingSoonLabel)
        comingSoonLabel.attributedText = NSAttributedString.create(withText: "Work in progress",
                                                                   fontStyle: .header2,
                                                                   colorType: .primaryText)
        comingSoonLabel.autoPinEdge(toSuperviewEdge: .leading)
        comingSoonLabel.autoPinEdge(toSuperviewEdge: .trailing)
        comingSoonLabel.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 80.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
}
