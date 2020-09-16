//
//  UserInfoViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/09/2020.
//

import UIKit
import RxSwift
import RxCocoa

class UserInfoViewController: UIViewController {
    
    private enum PageState { case read, edit }
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private let pageTitle: String
    private let userInfoParameters: [UserInfoParameter]
    
    private let pageState: BehaviorRelay<PageState> = BehaviorRelay<PageState>(value: .read)
    private let navigator: AppNavigator
    
    private let diposeBag = DisposeBag()
    
    init(withTitle title: String, userInfoParameters: [UserInfoParameter]) {
        self.navigator = Services.shared.navigator
        self.pageTitle = title
        self.userInfoParameters = userInfoParameters
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewSafeArea()
        
        // Header View
        let headerView = UserInfoHeaderView()
        headerView.setTitle(self.pageTitle)
        self.scrollStackView.stackView.addArrangedSubview(headerView)
        
        self.pageState.subscribe(onNext: { [weak self] newPageState in
            self?.updateEditButton(pageState: newPageState)
        }).disposed(by: self.diposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)
        self.addCustomBackButton()
    }
    
    private func updateEditButton(pageState: PageState) {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.edit.style)
        switch pageState {
        case .edit:
            button.contentEdgeInsets = UIEdgeInsets(top: 2.0, left: 12.0, bottom: 2.0, right: 12.0)
            button.setTitle(StringsProvider.string(forKey: .userInfoButtonSubmit), for: .normal)
            button.addTarget(self, action: #selector(self.submitButtonPressed), for: .touchUpInside)
        case .read:
            button.setInsets(forContentPadding: UIEdgeInsets(top: 2.0, left: 12.0, bottom: 2.0, right: 16.0),
                             imageTitlePadding: 12.0)
            button.swapImageAndTitle()
            button.setTitle(StringsProvider.string(forKey: .userInfoButtonEdit), for: .normal)
            button.setImage(ImagePalette.templateImage(withName: .editSmall), for: .normal)
            button.imageView?.tintColor = ColorPalette.color(withType: .secondaryText)
            button.imageView?.contentMode = .scaleAspectFit
            button.addTarget(self, action: #selector(self.editButtonPressed), for: .touchUpInside)
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }
    
    private func showPage(page: Page, isModal: Bool) {
        self.navigator.showInfoDetailPage(presenter: self, page: page, isModal: isModal)
    }
    
    // MARK: - Actions
    
    @objc private func editButtonPressed() {
        self.pageState.accept(.edit)
    }
    
    @objc private func submitButtonPressed() {
        // TODO: Submit new data to server before changing state
        self.pageState.accept(.read)
    }
}
