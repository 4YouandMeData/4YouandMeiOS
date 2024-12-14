//
//  DiaryNoteViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 30/11/24.
//

import UIKit
import RxSwift

class DiaryNotesViewController: UIViewController {
    
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
    
    private lazy var footerView: UIView = {
        
        let containerView = UIView()
                
        let buttonsView = DoubleButtonHorizontalView(styleCategory: .primaryBackground(firstButtonPrimary: true,
                                                                                        secondButtonPrimary: true))
        
        buttonsView.setFirstButtonText("Record")
        buttonsView.setFirstButtonImage(ImagePalette.image(withName: .audioNote))
        buttonsView.addTargetToFirstButton(target: self, action: #selector(self.createAudioDiaryNote))
        
        buttonsView.setSecondButtonText("Write")
        buttonsView.setSecondButtonImage(ImagePalette.image(withName: .textNote))
        buttonsView.addTargetToSecondButton(target: self, action: #selector(self.createTextDiaryNote))
        
        containerView.addSubview(buttonsView)
        buttonsView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        
        return containerView
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.tableFooterView = UIView()
        tableView.registerCellsWithClass(DiaryNoteItemTextTableViewCell.self)
        tableView.registerCellsWithClass(DiaryNoteItemAudioTableViewCell.self)
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.backgroundView = self.diaryNoteEmptyView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 130.0
        return tableView
    }()
    
    private var storage: CacheService
    private var dataPointID: String?
    private var diaryNoteItems: [DiaryNoteItem]
    
    init(withDataPointID dataPointID: String?) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.dataPointID = dataPointID
        
        self.diaryNoteItems = []
        // Crea un array di oggetti DiaryNoteItem dai dati di test
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = SingleTextHeaderView()
        headerView.setTitleText(StringsProvider.string(forKey: .diaryNoteTitle))
        
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.tableView.autoPinEdge(.top, to: .bottom, of: headerView)
        
//
//        stackView.addArrangedSubview(self.tableView)
//        stackView.addArrangedSubview(self.footerView)
//        
//        self.tableView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0)
//        self.tableView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0)
//        self.tableView.autoPinEdge(.top, to: .bottom, of: headerView)
//        self.tableView.autoPinEdge(.bottom, to: .top, of: self.footerView)
//        
//        self.tableView.reloadData()
        self.updateUI()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.loadItems()
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        self.tableView.backgroundView = diaryNoteItems.isEmpty ? self.diaryNoteEmptyView : nil
        self.tableView.reloadData()
    }
    
    private func loadItems() {
        self.repository.getDiaryNotes()
                        .addProgress()
                        .subscribe(onSuccess: { [weak self] diaryNote in
                            guard let self = self else { return }
                            self.diaryNoteItems = diaryNote
                            self.updateUI()

                        }, onError: { [weak self] error in
                            guard let self = self else { return }
//                            guard let delegate = self.delegate else { return }
                            self.navigator.handleError(error: error, presenter: self)
                        }).disposed(by: self.disposeBag)
    }
    
    @objc private func createAudioDiaryNote() {
        self.navigator.openDiaryNoteAudio(diaryNote: nil, presenter: self)
    }
    
    @objc private func createTextDiaryNote() {
        self.navigator.openDiaryNoteText(diaryNoteId: nil, presenter: self)
    }
}

extension DiaryNotesViewController: UITableViewDataSource {
    
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
                guard let cell = tableView.dequeueReusableCellOfType(type: DiaryNoteItemTextTableViewCell.self,
                                                                     forIndexPath: indexPath) else {
                    assertionFailure("DiaryNoteItemTextTableViewCell not registered")
                    return UITableViewCell()
                }
                cell.display(data: diaryNote, buttonPressedCallback: { [weak self] in
                    guard let self = self else { return }
                    self.navigator.openDiaryNoteText(diaryNoteId: diaryNote.id,
                                                     presenter: self)
                })
                return cell
                
            case .audio:
                guard let cell = tableView.dequeueReusableCellOfType(type: DiaryNoteItemAudioTableViewCell.self,
                                                                     forIndexPath: indexPath) else {
                    assertionFailure("DiaryNoteItemAudioTableViewCell not registered")
                    return UITableViewCell()
                }
                cell.display(data: diaryNote, buttonPressedCallback: { [weak self] in
                    guard let self = self else { return }
                    self.navigator.openDiaryNoteAudio(diaryNote: diaryNote, presenter: self)
                })
                return cell
                
            }
        } else {
            assertionFailure("Unhandled Diary Note Item type: \(diaryNote.self)")
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let diaryNote = diaryNoteItems[indexPath.row]
            self.repository.deleteDiaryNote(noteID: diaryNote.id)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    diaryNoteItems.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    self.updateUI()
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        }
    }
}

extension DiaryNotesViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let diaryNote = diaryNoteItems[indexPath.row]
            switch diaryNote.diaryNoteType {
            case .text:
                return 80 // Altezza variabile per le note di testo
            case .audio:
                return 100 // Altezza fissa per le note audio
            case .none:
                return UITableView.automaticDimension
            }
    }
}
