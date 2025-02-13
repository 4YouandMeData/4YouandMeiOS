//
//  NoticedViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 14/12/24.
//

import UIKit
import RxSwift

class NoticedViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    private var storage: CacheService
    private var studyInfoSection: StudyInfoSection?
    
    private let disposeBag = DisposeBag()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        let containerView = UIView()
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: StringsProvider.string(forKey: .diaryNoteTitle),
                           fontStyle: .title,
                           colorType: .primaryText)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 0, isVertical: false)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins/2,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins/2))
        return containerView
    }()
    
    private lazy var messages: [MessageInfo] = {
        let messages = self.storage.infoMessages?.messages(withLocation: .tabDiary)
        return messages ?? []
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init() {
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
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
        
        let comingSoonButton = UIButton()
        comingSoonButton.setImage(ImagePalette.templateImage(withName: .infoMessage), for: .normal)
        comingSoonButton.tintColor = ColorPalette.color(withType: .primary)
        comingSoonButton.addTarget(self, action: #selector(self.infoButtonPressed), for: .touchUpInside)
        comingSoonButton.autoSetDimension(.width, toSize: 24)
        comingSoonButton.isHidden = (self.messages.count < 1)
        
        self.headerView.addSubview(comingSoonButton)
        comingSoonButton.autoPinEdge(.bottom, to: .bottom, of: self.headerView, withOffset: -40.0)
        comingSoonButton.autoPinEdge(.trailing, to: .trailing, of: self.headerView, withOffset: -12.0)
        
        self.refreshUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    private func refreshUI() {
        
        self.scrollStackView.stackView.subviews.forEach({ $0.removeFromSuperview() })
        
        var title = StringsProvider.string(forKey: .diaryNoteCreateText)
        var image = ImagePalette.image(withName: .textNote)

        let writePage = GenericListItemView(withTitle: title,
                                            image: image ?? UIImage(),
                                            colorType: .primary,
                                            style: .shadowStyle,
                                            gestureCallback: { [weak self] in
            guard let self = self else { return }
            self.navigator.openDiaryNoteText(diaryNote: nil, presenter: self, isEditMode: false, isFromChart: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(writePage)
        
        title = StringsProvider.string(forKey: .diaryNoteRecordAudio)
        image = ImagePalette.image(withName: .audioNote)
        let audioPage = GenericListItemView(withTitle: title,
                                            image: image ?? UIImage() ,
                                            colorType: .primary,
                                            style: .shadowStyle,
                                            gestureCallback: { [weak self] in
            guard let self = self else { return }
            self.navigator.openDiaryNoteAudio(diaryNote: nil, presenter: self, isEditMode: false, isFromChart: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(audioPage)
    
        title = StringsProvider.string(forKey: .diaryNoteRecordVideo)
        image = ImagePalette.templateImage(withName: .videoIcon) ?? UIImage()
        let videoPage = GenericListItemView(withTitle: title,
                                            image: image ?? UIImage(),
                                            colorType: .primary,
                                            style: .shadowStyle,
                                            gestureCallback: { [weak self] in
            guard let self = self else { return }
            self.navigator.openDiaryNoteVideo(diaryNote: nil,
                                              isEdit: false,
                                              presenter: self,
                                              isFromChart: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(videoPage)
    }
    
    // MARK: Actions
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
    
    @objc private func infoButtonPressed() {
        self.navigator.openMessagePage(withLocation: .pageChartDiary, presenter: self)
    }
}
