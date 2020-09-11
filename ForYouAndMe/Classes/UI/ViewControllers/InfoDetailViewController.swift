//
//  InfoDetailViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/09/2020.
//

import Foundation
import PureLayout

struct InfoDetailPageData {
    let page: Page
    let isModal: Bool
}

public class InfoDetailPageViewController: UIViewController, PageProvider {
    
    var page: Page { return self.pageData.page }
    
    private let pageData: InfoDetailPageData
    
    private let navigator: AppNavigator
    
    init(withPageData pageData: InfoDetailPageData) {
        self.pageData = pageData
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        if self.pageData.isModal {
            self.loadModalPage()
        } else {
            self.loadPushPage()
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        if self.pageData.isModal {
            self.addCustomCloseButton()
        } else {
            self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        }
    }
    
    private func loadModalPage() {
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero)
        
        scrollStackView.stackView.addBlankSpace(space: 16.0)
        
        // Title
        scrollStackView.stackView.addLabel(withText: self.pageData.page.title,
                                           fontStyle: .title,
                                           colorType: .primaryText)
        
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Body
        scrollStackView.stackView.addLabel(withText: self.pageData.page.body,
                                           fontStyle: .paragraph,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
    }
    
    private func loadPushPage() {
        // Header View
        let headerView = InfoDetailHeaderView(withTitle: self.pageData.page.title)
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        headerView.backButton.addTarget(self, action: #selector(self.backButtonPressed), for: .touchUpInside)
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        
        // Body
        scrollStackView.stackView.addLabel(withText: self.pageData.page.body,
                                           fontStyle: .paragraph,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
    }
    
    // MARK: Actions
    
    @objc private func closeButtonPressed() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
}
