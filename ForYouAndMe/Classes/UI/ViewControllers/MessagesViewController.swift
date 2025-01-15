//
//  MessagesViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 17/12/24.
//

import UIKit
import RxSwift

class MessagesViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    private let storage: CacheService
    
    private let disposeBag = DisposeBag()
    private let messages: [MessageInfo]
    private var currentIndex: Int = 0

    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var pageViewController: UIPageViewController = {
         let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
         pageVC.dataSource = self
         pageVC.delegate = self
         return pageVC
     }()
    
    private lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = messages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = .lightGray
        pageControl.currentPageIndicatorTintColor = .black
        pageControl.isUserInteractionEnabled = false
        pageControl.isHidden = (messages.count <= 1)
        return pageControl
    }()
    
    init(withLocation
         location: MessageInfoParameter) {
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        
        self.messages = self.storage.infoMessages?.messages(withLocation: location) ?? []
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
        
        let containerView = UIView()
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: self.messages.first?.title ?? "",
                           fontStyle: .title,
                           colorType: .primaryText)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 0, isVertical: false)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins/2,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins/2))
        
        // Header View
        self.view.addSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        // PageViewController
        self.addChild(self.pageViewController)
        self.view.addSubview(pageViewController.view)
        self.pageViewController.didMove(toParent: self)
        
        self.pageViewController.view.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                      left: Constants.Style.DefaultHorizontalMargins/2,
                                                                      bottom: 42,
                                                                      right: Constants.Style.DefaultHorizontalMargins/2),
                                                   excludingEdge: .top)
        self.pageViewController.view.autoPinEdge(.top, to: .bottom, of: containerView, withOffset: 0)
        
        // Set Initial ViewController
        if let firstMessage = messages.first {
            let initialVC = MessagePageViewController(message: firstMessage)
            pageViewController.setViewControllers([initialVC], direction: .forward, animated: true)
        }
        
        self.view.addSubview(self.pageControl)
        self.pageControl.autoAlignAxis(.vertical, toSameAxisOf: self.pageViewController.view)
        self.pageControl.autoPinEdge(.bottom, to: .bottom, of: self.pageViewController.view, withOffset: 10)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: Actions
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
    
    @objc private func confirmButtonPressed() {
        self.dismiss(animated: true)
    }
}

// MARK: - UIPageViewControllerDataSource, UIPageViewControllerDelegate
extension MessagesViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? MessagePageViewController,
              let currentIndex = messages.firstIndex(of: currentVC.message) else {
            return nil
        }
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return nil }
        return MessagePageViewController(message: messages[previousIndex])
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? MessagePageViewController,
              let currentIndex = messages.firstIndex(of: currentVC.message) else {
            return nil
        }
        let nextIndex = currentIndex + 1
        guard nextIndex < messages.count else { return nil }
        return MessagePageViewController(message: messages[nextIndex])
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        
        if completed, let visibleVC = pageViewController.viewControllers?.first as? MessagePageViewController,
            let newIndex = messages.firstIndex(of: visibleVC.message) {
            currentIndex = newIndex
            pageControl.currentPage = newIndex
        }
    }
}
