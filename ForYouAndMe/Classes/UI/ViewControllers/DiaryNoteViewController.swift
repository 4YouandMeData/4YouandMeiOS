//
//  DiaryNoteViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 30/11/24.
//

import UIKit
import RxSwift

class DiaryNoteViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    
    private lazy var diaryNoteEmptyView = DiaryNoteEmptyView(withTopOffset: 8.0)

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
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0 )
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: StringsProvider.string(forKey: .diaryNoteTitle),
                           fontStyle: .title,
                           colorType: .primaryText)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 8.0, isVertical: false)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
        return containerView
    }()
    
    private lazy var footerView: UIView = {
        
        let containerView = UIView()
                
        let buttonsView = DoubleButtonHorizontalView(styleCategory: .primaryBackground(firstButtonPrimary: true,
                                                                                        secondButtonPrimary: true))
        
        buttonsView.setFirstButtonText("Record")
        buttonsView.setFirstButtonImage(ImagePalette.image(withName: .audioNote))
//        buttonsView.addTargetToFirstButton(target: self, action: #selector(self.disagreeButtonPressed))
        
        buttonsView.setSecondButtonText("Write")
        buttonsView.setSecondButtonImage(ImagePalette.image(withName: .textNote))
//        buttonsView.addTargetToSecondButton(target: self, action: #selector(self.agreenButtonPressed))
        
        containerView.addSubview(buttonsView)
        buttonsView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        
        return containerView
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView()
        tableView.registerCellsWithClass(DiaryNoteItemTableViewCell.self)
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.backgroundView = self.diaryNoteEmptyView
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.backgroundColor = .green
        tableView.separatorStyle = .none
        return tableView
    }()
    
    private var storage: CacheService
    private var dataPointID: String
    private var diaryNoteItems: [DiaryNoteItem]
    
    init(withDataPointID dataPointID: String) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.dataPointID = dataPointID
        
        let diaryNoteItemsTestData: [[String: Any]] = [
            [
                "id": "1",
                "type": "text",
                "diaryNoteType": "text",
                "title": "A Day in the Park",
                "body": "I had a great day at the park today. The weather was beautiful and I enjoyed a long walk.",
                "image": "https://example.com/image1.jpg",
                "urlString": "https://example.com/more-info"
            ],
            [
                "id": "2",
                "type": "audio",
                "diaryNoteType": "audio",
                "title": "Morning Thoughts",
                "body": "Recorded my thoughts about today's plans.",
                "image": "https://example.com/image2.jpg",
                "urlString": ""
            ],
            [
                "id": "3",
                "type": "text",
                "diaryNoteType": "text",
                "title": "",
                "body": "This entry only has a body with no title.",
                "image": NSNull(),
                "urlString": NSNull()
            ]
        ]
        
        // Crea un array di oggetti DiaryNoteItem dai dati di test
        self.diaryNoteItems = diaryNoteItemsTestData.compactMap { DiaryNoteItem(from: $0) }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("AboutYouViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Main Stack View
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addArrangedSubview(self.headerView)
        stackView.addArrangedSubview(self.tableView)
        stackView.addArrangedSubview(self.footerView)
        
        tableView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0)
        tableView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0)
        tableView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        tableView.autoPinEdge(.bottom, to: .top, of: self.footerView)
        
        self.updateUI()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        self.tableView.backgroundView = diaryNoteItems.isEmpty ? self.diaryNoteEmptyView : nil
    }
}

extension DiaryNoteViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.diaryNoteItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let diaryNote = diaryNoteItems[indexPath.row]
        if let typeNote = diaryNote.diaryNoteType {
            switch typeNote {
            case .text:
                guard let cell = tableView.dequeueReusableCellOfType(type: DiaryNoteItemTableViewCell.self, forIndexPath: indexPath) else {
                    assertionFailure("DiaryNoteItem not registered")
                    return UITableViewCell()
                }
                cell.display(data: diaryNote, buttonPressedCallback: { () in
                    //                self.repository.getSurvey(surveyId: survey.id)
                    //                    .addProgress()
                    //                    .subscribe(onSuccess: { [weak self] surveyGroup in
                    //                        guard let self = self else { return }
                    //                        guard let delegate = self.delegate else { return }
                    //                        self.navigator.startSurveySection(withTask: feed,
                    //                                                          surveyGroup: surveyGroup,
                    //                                                          presenter: delegate.presenter)
                    //                    }, onError: { [weak self] error in
                    //                        guard let self = self else { return }
                    //                        guard let delegate = self.delegate else { return }
                    //                        self.navigator.handleError(error: error, presenter: delegate.presenter)
                    //                    }).disposed(by: self.disposeBag)
                })
                return cell
                
            case .audio:
                guard let cell = tableView.dequeueReusableCellOfType(type: DiaryNoteItemTableViewCell.self, forIndexPath: indexPath) else {
                    assertionFailure("DiaryNoteItemTableViewCell not registered")
                    return UITableViewCell()
                }
                cell.display(data: diaryNote, buttonPressedCallback: { () in
                    //                self.repository.getSurvey(surveyId: survey.id)
                    //                    .addProgress()
                    //                    .subscribe(onSuccess: { [weak self] surveyGroup in
                    //                        guard let self = self else { return }
                    //                        guard let delegate = self.delegate else { return }
                    //                        self.navigator.startSurveySection(withTask: feed,
                    //                                                          surveyGroup: surveyGroup,
                    //                                                          presenter: delegate.presenter)
                    //                    }, onError: { [weak self] error in
                    //                        guard let self = self else { return }
                    //                        guard let delegate = self.delegate else { return }
                    //                        self.navigator.handleError(error: error, presenter: delegate.presenter)
                    //                    }).disposed(by: self.disposeBag)
                })
                return cell
                
            }
        } else {
             assertionFailure("Unhandled Diary Note Item type: \(diaryNote.self)")
            return UITableViewCell()
        }
    }
}

extension DiaryNoteViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        return tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let diaryNote = diaryNoteItems[indexPath.row]
            switch diaryNote.diaryNoteType {
            case .text:
                return 80 // Altezza variabile per le note di testo
            case .audio:
                return 80 // Altezza fissa per le note audio
            case .none:
                return UITableView.automaticDimension
            }
    }
}
