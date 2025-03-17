//
//  DiaryNoteViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 30/11/24.
//

import UIKit
import RxSwift
import JJFloatingActionButton

struct DiaryNoteSection {
    let date: Date
    var items: [DiaryNoteItem]
}

class DiaryNotesViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private let audioAssetManager: AudioAssetManager
    
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
                
        let buttonsView = TripleButtonHorizontalView(styleCategory: .primaryBackground(firstButtonPrimary: true,
                                                                                        secondButtonPrimary: true))
        
        buttonsView.setFirstButtonImage(ImagePalette.image(withName: .audioNote))
        buttonsView.addTargetToFirstButton(target: self, action: #selector(self.createAudioDiaryNote))
        
        buttonsView.setSecondButtonImage(ImagePalette.image(withName: .textNote))
        buttonsView.addTargetToSecondButton(target: self, action: #selector(self.createTextDiaryNote))
        
        let videoIcon = ImagePalette.templateImage(withName: .videoIcon)
        videoIcon?.withTintColor(ColorPalette.color(withType: .secondary), renderingMode: .alwaysOriginal)
        buttonsView.setThirdButtonImage(ImagePalette.templateImage(withName: .videoIcon))
        buttonsView.addTargetToThirdButton(target: self, action: #selector(self.createVideoNote))
        
        containerView.addSubview(buttonsView)
        buttonsView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        
        return containerView
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.tableFooterView = UIView()
        tableView.registerCellsWithClass(DiaryNoteItemTextTableViewCell.self)
        tableView.registerCellsWithClass(DiaryNoteItemAudioTableViewCell.self)
        tableView.registerCellsWithClass(DiaryNoteItemVideoTableViewCell.self)
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.backgroundView = self.diaryNoteEmptyView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 130.0
        return tableView
    }()
    
    private lazy var messages: [MessageInfo] = {
        let messages = self.storage.infoMessages?.messages(withLocation: .tabDiary)
        return messages ?? []
    }()
    
    private var storage: CacheService
    private var dataPointID: String?
    private var diaryNote: DiaryNoteItem?
    private var diaryNoteItems: [DiaryNoteItem]
    private var sections: [DiaryNoteSection] = []
    private let isFromChart: Bool
    
    init(withDataPoint dataPoint: DiaryNoteItem?, isFromChart: Bool) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.diaryNote = dataPoint
        self.dataPointID = dataPoint?.diaryNoteId.string(withFormat: dateTimeFormat)
        self.isFromChart = isFromChart
        self.diaryNoteItems = []
        self.audioAssetManager = AudioAssetManager()
        // Crea un array di oggetti DiaryNoteItem dai dati di test
        super.init(nibName: nil, bundle: nil)
        
        self.tableView.registerHeaderFooterViewWithClass(DiarySectionHeader.self)
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
        
        if self.dataPointID == nil {
            // Header View
            let headerView = SingleTextHeaderView()
            headerView.setTitleText(StringsProvider.string(forKey: .diaryNoteTitle))
            
            self.view.addSubview(headerView)
            headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
            
            self.view.addSubview(self.tableView)
            self.tableView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
            self.tableView.autoPinEdge(.top, to: .bottom, of: headerView)
            
            let comingSoonButton = UIButton()
            comingSoonButton.apply(style: ButtonTextStyleCategory.messages.style)
            comingSoonButton.setTitle(self.messages.first?.title, for: .normal)
            comingSoonButton.addTarget(self, action: #selector(self.comingSoonButtonPressed), for: .touchUpInside)
            comingSoonButton.autoSetDimension(.width, toSize: 110)
            comingSoonButton.isHidden = (self.messages.count < 1)
            
            headerView.addSubview(comingSoonButton)
            comingSoonButton.autoPinEdge(.bottom, to: .bottom, of: headerView, withOffset: -20.0)
            comingSoonButton.autoPinEdge(.trailing, to: .trailing, of: headerView, withOffset: -12.0)
            
            let actionButton = JJFloatingActionButton()
            let actionItemRiflection = actionButton.addItem()
            actionItemRiflection.titleLabel.text = StringsProvider.string(forKey: .diaryNoteFabReflection)
            actionItemRiflection.titleLabel.textColor = ColorPalette.color(withType: .fabTextColor)
            actionItemRiflection.imageView.image = ImagePalette.image(withName: .riflectionIcon)
            actionItemRiflection.buttonColor = ColorPalette.color(withType: .inactive)
            
            let actionNoticed = actionButton.addItem()
            actionNoticed.titleLabel.text = StringsProvider.string(forKey: .diaryNoteFabNoticed)
            actionNoticed.titleLabel.textColor = ColorPalette.color(withType: .fabTextColor)
            actionNoticed.imageView.image = ImagePalette.image(withName: .noteGeneric)
            actionNoticed.buttonColor = ColorPalette.color(withType: .secondary)
            actionNoticed.action = { [weak self] _ in
                guard let self = self else { return }
                self.navigator.openNoticedViewController(presenter: self)
            }
            
            view.addSubview(actionButton)
            actionButton.display(inViewController: self)
            actionButton.buttonColor = ColorPalette.color(withType: .fabColorDefault)
            actionButton.buttonImageColor = .black
            actionButton.layoutIfNeeded()
            let borderView = CircleBorderView(frame: actionButton.circleView.frame,
                                              color: ColorPalette.color(withType: .fabOutlineColor),
                                              borderWidth: 1.0)
            
            actionButton.addSubview(borderView)

        } else {
            
            let containerView = UIView()
            self.view.addSubview(containerView)
            containerView.autoPinEdgesToSuperviewEdges()
            
            containerView.addSubview(self.headerView)
            self.headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
            containerView.addSubview(self.tableView)
            containerView.addSubview(self.footerView)
            self.footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
            
            self.tableView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0)
            self.tableView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0)
            self.tableView.autoPinEdge(.top, to: .bottom, of: self.headerView)
            self.tableView.autoPinEdge(.bottom, to: .top, of: self.footerView)
            
            let comingSoonButton = UIButton()
            comingSoonButton.setImage(ImagePalette.templateImage(withName: .infoMessage), for: .normal)
            comingSoonButton.tintColor = ColorPalette.color(withType: .primary)
            comingSoonButton.addTarget(self, action: #selector(self.infoButtonPressed), for: .touchUpInside)
            comingSoonButton.autoSetDimension(.width, toSize: 24)
            comingSoonButton.isHidden = (self.messages.count < 1)
            
            self.headerView.addSubview(comingSoonButton)
            comingSoonButton.autoPinEdge(.bottom, to: .bottom, of: self.headerView, withOffset: -40.0)
            comingSoonButton.autoPinEdge(.trailing, to: .trailing, of: self.headerView, withOffset: -12.0)
        }
        self.tableView.reloadData()
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
    
    @objc private func comingSoonButtonPressed() {
        self.navigator.openMessagePage(withLocation: .tabDiary, presenter: self)
    }
    
    @objc private func infoButtonPressed() {
        self.navigator.openMessagePage(withLocation: .pageChartDiary, presenter: self)
    }
    
    // MARK: - Private Methods
    
    func createDiaryNoteSections(from diaryNotes: [DiaryNoteItem]) -> [DiaryNoteSection] {
        let calendar = Calendar.current
        
        let groupedDictionary = Dictionary(grouping: diaryNotes) { (item) -> Date in
            return calendar.startOfDay(for: item.diaryNoteId)
        }
        
        let sortedDates = groupedDictionary.keys.sorted(by: { $1 < $0 })
        
        let sections: [DiaryNoteSection] = sortedDates.map { date in
            let items = groupedDictionary[date]?.sorted(by: { $1.diaryNoteId < $0.diaryNoteId }) ?? []
            return DiaryNoteSection(date: date, items: items)
        }
        
        return sections
    }
    
    private func updateUI() {
        self.tableView.backgroundView = diaryNoteItems.isEmpty ? self.diaryNoteEmptyView : nil
        self.tableView.reloadData()
    }
    
    private func loadItems() {
        
        self.repository.getDiaryNotes(diaryNote: self.diaryNote,
                                      fromChart: self.isFromChart)
                        .addProgress()
                        .subscribe(onSuccess: { [weak self] diaryNote in
                            guard let self = self else { return }
                            self.diaryNoteItems = diaryNote
                            self.sections = createDiaryNoteSections(from: diaryNote)
                            self.updateUI()

                        }, onFailure: { [weak self] error in
                            guard let self = self else { return }
                            self.navigator.handleError(error: error, presenter: self)
                        }).disposed(by: self.disposeBag)
    }
    
    @objc private func createAudioDiaryNote() {
        self.navigator.openDiaryNoteAudio(diaryNote: diaryNote,
                                          presenter: self,
                                          isEditMode: false,
                                          isFromChart: self.isFromChart)
    }
    
    @objc private func createTextDiaryNote() {
        self.navigator.openDiaryNoteText(diaryNote: diaryNote,
                                         presenter: self,
                                         isEditMode: false,
                                         isFromChart: self.isFromChart)
    }
    
    @objc private func createVideoNote() {
        self.navigator.openDiaryNoteVideo(diaryNote: diaryNote,
                                          isEdit: false,
                                          presenter: self,
                                          isFromChart: self.isFromChart)
    }
}

extension DiaryNotesViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let diaryNote = sections[indexPath.section].items[indexPath.row]
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
                    self.navigator.openDiaryNoteText(diaryNote: diaryNote,
                                                     presenter: self,
                                                     isEditMode: true,
                                                     isFromChart: isFromChart)
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
                    self.navigator.openDiaryNoteAudio(diaryNote: diaryNote,
                                                      presenter: self,
                                                      isEditMode: true,
                                                      isFromChart: self.isFromChart)
                })
                
                if let audioUrl = diaryNote.urlString {
                    audioAssetManager.fetchAudioDuration(from: URL(string: audioUrl)!) { duration in
                                    if let duration = duration {
                                        cell.setTimeLabelFromDuration(duration)
                                    }
                                }
                }
                
                return cell
            case .video:
                guard let cell = tableView.dequeueReusableCellOfType(type: DiaryNoteItemVideoTableViewCell.self,
                                                                     forIndexPath: indexPath) else {
                    assertionFailure("DiaryNoteItemAudioTableViewCell not registered")
                    return UITableViewCell()
                }
                cell.display(data: diaryNote, buttonPressedCallback: { [weak self] in
                    guard let self = self else { return }
                    self.navigator.openDiaryNoteVideo(diaryNote: diaryNote,
                                                      isEdit: true,
                                                      presenter: self,
                                                      isFromChart: false)
                })
                
                if let audioUrl = diaryNote.urlString {
                    audioAssetManager.fetchAudioDuration(from: URL(string: audioUrl)!) { duration in
                                    if let duration = duration {
                                        cell.setTimeLabelFromDuration(duration)
                                    }
                                }
                }
                
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
                    self.sections[indexPath.section].items.remove(at: indexPath.row)
                    if sections[indexPath.section].items.isEmpty {
                        // Remove Section if not elements
                        sections.remove(at: indexPath.section)
                        tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
                    } else {
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                    }
                    diaryNoteItems.remove(at: indexPath.row)
                    self.updateUI()
                }, onFailure: { [weak self] error in
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
            case .audio, .video:
                return 100 // Altezza fissa per le note audio
            case .none:
                return UITableView.automaticDimension
            }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionText = self.sections[section].date.string(withFormat: literalDate)
        guard let cell = tableView.dequeueReusableHeaderFooterViewOfType(type: DiarySectionHeader.self) else {
            assertionFailure("DiarySectionHeader not registered")
            return UIView()
        }
        cell.display(text: sectionText)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Needed to remove the default blank footer under each section
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
}
