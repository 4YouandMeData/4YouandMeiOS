//
//  StudyInfoViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import UIKit
import RxSwift

class StudyInfoViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    private var studyInfoSection: StudyInfoSection?
    
    private let disposeBag = DisposeBag()
    
    private let headerView = StudyInfoHeaderView()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private lazy var comingSoonButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.messages.style)
        button.setTitle(MessageMap.getMessageContent(byKey: "settings")?.title, for: .normal)
        button.addTarget(self, action: #selector(self.comingSoonButtonPressed), for: .touchUpInside)
        button.autoSetDimension(.width, toSize: 110)
        return button
    }()
    
    init() {
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.repository = Services.shared.repository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("StudyInfoViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        self.view.addSubview(self.headerView)
        self.headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        
        headerView.addSubview(self.comingSoonButton)
        self.comingSoonButton.autoPinEdge(.bottom, to: .bottom, of: headerView, withOffset: -37.0)
        self.comingSoonButton.autoPinEdge(.trailing, to: .trailing, of: headerView, withOffset: -12.0)
        
        self.refreshUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.headerView.refreshUI()
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabStudyInfo)))
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.studyInfo.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.repository.getStudyInfoSection().subscribe(onSuccess: { [weak self] infoSection in
            guard let self = self else { return }
            self.studyInfoSection = infoSection
            self.refreshUI()
        }, onError: { [weak self] error in
            guard let self = self else { return }
            print("StudyInfo View Controller - Error retrieve studyInfo page: \(error.localizedDescription)")
            self.refreshUI()
            self.navigator.handleError(error: error, presenter: self)
        }).disposed(by: self.disposeBag)
    }
    
    private func showPage(page: Page, isModal: Bool) {
        self.navigator.showInfoDetailPage(presenter: self, page: page, isModal: isModal)
    }
    
    private func refreshUI() {
        
        self.scrollStackView.stackView.subviews.forEach({ $0.removeFromSuperview() })
        
        let title = StringsProvider.string(forKey: .studyInfoAboutYou)
        let aboutYou = GenericListItemView(withTitle: title,
                                           image: ImagePalette.templateImage(withName: .userInfoIcon) ?? UIImage(),
                                           colorType: .primary,
                                           style: .flatStyle,
                                           gestureCallback: { [weak self] in
                                            self?.navigator.showAboutYouPage(presenter: self!)
                                           })
        self.scrollStackView.stackView.addArrangedSubview(aboutYou)
        self.scrollStackView.stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .inactive),
                                                        inset: 21,
                                                        isVertical: false)
        
        let contactPage = self.studyInfoSection?.contactsPage
        if  contactPage != nil {
            
            let title = contactPage?.title ?? StringsProvider.string(forKey: .studyInfoContactTitle)
            let image = contactPage?.image ?? ImagePalette.templateImage(withName: .studyInfoContact) ?? UIImage()
            let contactInformation = GenericListItemView(withTitle: title,
                                                         image: image,
                                                         colorType: .primary,
                                                         style: .flatStyle,
                                                         gestureCallback: { [weak self] in
                                                            self?.showPage(page: contactPage!, isModal: false)
                                                         })
            self.scrollStackView.stackView.addArrangedSubview(contactInformation)
        }
        
        let rewardsPage = self.studyInfoSection?.rewardPage
        if  rewardsPage != nil {
            let title = rewardsPage?.title ?? StringsProvider.string(forKey: .studyInfoRewardsTitle)
            let image = rewardsPage?.image ?? ImagePalette.templateImage(withName: .studyInfoRewards) ?? UIImage()
            let rewards = GenericListItemView(withTitle: title,
                                              image: image,
                                              colorType: .primary,
                                              style: .flatStyle,
                                              gestureCallback: { [weak self] in
                                                self?.showPage(page: rewardsPage!, isModal: false)
                                              })
            self.scrollStackView.stackView.addArrangedSubview(rewards)
        }
        
        let faqPage = self.studyInfoSection?.faqPage
        if  faqPage != nil {
            let title = faqPage?.title ?? StringsProvider.string(forKey: .studyInfoFaqTitle)
            let image = faqPage?.image ?? ImagePalette.templateImage(withName: .studyInfoFAQ) ?? UIImage()
            let faq = GenericListItemView(withTitle: title,
                                          image: image,
                                          colorType: .primary,
                                          style: .flatStyle,
                                          gestureCallback: { [weak self] in
                                            self?.showPage(page: faqPage!, isModal: false)
                                          })
            self.scrollStackView.stackView.addArrangedSubview(faq)
        }
        
        self.scrollStackView.layoutIfNeeded()
        
        let footerHeight: CGFloat = 40.0
        let offset = self.scrollStackView.scrollView.frame.height - self.scrollStackView.stackView.frame.height - footerHeight
        let spacerView = UIView()
        self.scrollStackView.stackView.addArrangedSubview(spacerView)
        spacerView.autoSetDimension(.height, toSize: offset)
        
        let containerFooterView = UIView()
        self.scrollStackView.stackView.addArrangedSubview(containerFooterView)
        containerFooterView.autoSetDimension(.height, toSize: footerHeight)
        
        let versionLabel = UILabel()
        versionLabel.font = FontPalette.fontStyleData(forStyle: .header3).font
        versionLabel.textColor = ColorPalette.color(withType: .fourthText)
        versionLabel.text = Constants.Resources.AppVersion ?? ""
        versionLabel.numberOfLines = 0
        containerFooterView.addSubview(versionLabel)
        versionLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 16.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins),
                                                  excludingEdge: .top)
    }
    
    // MARK: Actions
    @objc private func comingSoonButtonPressed() {
        
    }
}
