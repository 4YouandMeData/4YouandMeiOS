//
//  MenstrualPeriodDetailViewController.swift
//  ForYouAndMe
//
//  FUAM-2934 — Detail screen for a single menstrual period. The screen is
//  opened with the id of the series anchor (the last `yes` day, i.e. the
//  compressed row shown on the Compass Log) and fetches the full member list
//  from `GET /v1/diary_notes/:id` (BE v0.12.5 `series_entries`). The user can
//  add another bleeding date or swipe-delete an existing one; editing
//  individual entries is out of scope for this release.
//

import UIKit
import PureLayout
import RxSwift

protocol MenstrualPeriodDetailViewControllerDelegate: AnyObject {
    /// Called when the user requests adding a new bleeding date.
    func menstrualPeriodDetailViewControllerDidRequestAdd(_ vc: MenstrualPeriodDetailViewController)

    /// Called when the user taps a row to inspect a single entry.
    func menstrualPeriodDetailViewController(_ vc: MenstrualPeriodDetailViewController,
                                              didSelect entry: DiaryNoteItem)

    /// Called when the user closes the screen.
    func menstrualPeriodDetailViewControllerDidClose(_ vc: MenstrualPeriodDetailViewController)
}

final class MenstrualPeriodDetailViewController: BaseViewController {

    weak var delegate: MenstrualPeriodDetailViewControllerDelegate?

    /// Id of the series anchor (last `yes` day) — the row tapped on the
    /// Compass Log. The member list is (re)fetched from this id.
    private let seriesAnchorId: String

    /// Members of the period, chronological — populated from the show response.
    private var entries: [DiaryNoteItem] = []

    /// Two sections: section 0 is the add row, section 1 is the entries.
    /// Both scroll together — the add row sits in the table, not the header.
    private static let addSectionIndex = 0
    private static let entriesSectionIndex = 1

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.estimatedRowHeight = 64
        tableView.rowHeight = UITableView.automaticDimension
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerCellsWithClass(MenstrualPeriodEntryCell.self)
        tableView.registerCellsWithClass(MenstrualPeriodAddCell.self)
        return tableView
    }()

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .menstrualDetailCloseButton))
        buttonView.setButtonEnabled(enabled: true)
        buttonView.addTarget(target: self, action: #selector(closeTapped))
        return buttonView
    }()

    init(diaryNoteId: String) {
        self.seriesAnchorId = diaryNoteId
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        // Detail screen has its own "Add another bleeding date" button — the
        // generic FAB would be redundant and overlap the close button.
        setFabHidden(true)
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The in-page header doubles as the title — hide the nav chrome so
        // the title isn't pushed below the bar and the footer close button
        // stays the sole dismiss affordance. The screen is still wrapped in
        // a nav controller so child screens can be pushed on top.
        self.navigationController?.navigationBar
            .apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        // Re-fetch on every appearance so the list reflects adds/edits made in
        // the wizard / entry form presented on top of this screen.
        reloadEntries()
    }

    /// Fetch the series members from the show endpoint. A flat response
    /// (`seriesEntries` empty) means the anchor no longer fronts a series —
    /// bail back to the Compass Log, which will re-derive the rows.
    ///
    /// BE limitation (FUAM-2934): `/v1/diary_notes/<anchor>` sideloads the
    /// `series_entries` but **not** their nested `feedback_tags` — the
    /// relationship ids are present in the payload, the records are not,
    /// so after Japx each child arrives with `feedbackTags = nil`. Without
    /// it, neither the cell's emoji nor the edit form's pre-selection can
    /// render. We refetch each child individually (its own GET does
    /// sideload feedback_tags) in parallel and use those as the entries
    /// list. Drop this round-trip when the BE includes nested feedback_tags.
    private func reloadEntries() {
        self.repository.getMenstrualDiaryNote(noteID: self.seriesAnchorId)
            .flatMap { [weak self] anchor -> Single<[DiaryNoteItem]> in
                guard let self = self else { return .just([]) }
                let entryIDs = (anchor.seriesEntries ?? []).map { $0.id }
                guard !entryIDs.isEmpty else { return .just([]) }
                let fetches = entryIDs.map { self.repository.getMenstrualDiaryNote(noteID: $0) }
                return Single.zip(fetches)
            }
            .addProgress()
            .subscribe(onSuccess: { [weak self] entries in
                guard let self = self else { return }
                self.entries = entries
                if entries.isEmpty {
                    self.delegate?.menstrualPeriodDetailViewControllerDidClose(self)
                } else {
                    self.tableView.reloadData()
                }
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            })
            .disposed(by: self.disposeBag)
    }

    private func setupLayout() {
        // Header: title (24 above) → 16 → separator → 24 → subtitle (24 below)
        // → 24 spacer → "+ Add another bleeding date" row → list → footer.
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textColor = ColorPalette.color(withType: .primaryText)
        titleLabel.text = StringsProvider.string(forKey: .menstrualDetailTitle)

        let titleSeparator = UIView()
        titleSeparator.backgroundColor = ColorPalette.color(withType: .secondaryMenu)
        titleSeparator.autoSetDimension(.height, toSize: 1)

        let subtitleLabel = UILabel()
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = ColorPalette.color(withType: .primaryText)
        subtitleLabel.text = StringsProvider.string(forKey: .menstrualDetailMessage)

        let header = UIStackView()
        header.axis = .vertical
        header.alignment = .fill
        header.spacing = 24
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 32,
                                            left: Constants.Style.DefaultHorizontalMargins,
                                            bottom: 24,
                                            right: Constants.Style.DefaultHorizontalMargins)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(titleSeparator)
        header.addArrangedSubview(subtitleLabel)

        view.addSubview(header)
        header.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)

        view.addSubview(tableView)
        tableView.autoPinEdge(.top, to: .bottom, of: header)
        tableView.autoPinEdge(toSuperviewEdge: .leading)
        tableView.autoPinEdge(toSuperviewEdge: .trailing)
        tableView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    @objc func addTapped() {
        delegate?.menstrualPeriodDetailViewControllerDidRequestAdd(self)
    }

    @objc func closeTapped() {
        delegate?.menstrualPeriodDetailViewControllerDidClose(self)
    }

    private func confirmDelete(at indexPath: IndexPath) {
        guard indexPath.row < entries.count else { return }
        let alert = UIAlertController(
            title: StringsProvider.string(forKey: .menstrualDetailDeleteTitle),
            message: StringsProvider.string(forKey: .menstrualDetailDeleteMessage),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: StringsProvider.string(forKey: .menstrualDetailDeleteCancel),
            style: .cancel,
            handler: nil))
        alert.addAction(UIAlertAction(
            title: StringsProvider.string(forKey: .menstrualDetailDeleteConfirm),
            style: .destructive,
            handler: { [weak self] _ in
                self?.deleteEntry(at: indexPath)
            }))
        present(alert, animated: true)
    }

    private func deleteEntry(at indexPath: IndexPath) {
        guard indexPath.row < entries.count else { return }
        let entry = entries[indexPath.row]
        // Deleting the anchor (last `yes`) collapses or re-fronts the series —
        // there's no stable id to re-fetch, so hand back to the Compass Log.
        let deletingAnchor = entry.id == self.seriesAnchorId
        self.repository.deleteDiaryNote(noteID: entry.id)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                if deletingAnchor {
                    self.delegate?.menstrualPeriodDetailViewControllerDidClose(self)
                } else {
                    self.reloadEntries()
                }
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            })
            .disposed(by: self.disposeBag)
    }
}

// MARK: - UITableViewDataSource / UITableViewDelegate

extension MenstrualPeriodDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == Self.addSectionIndex ? 1 : entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Self.addSectionIndex {
            guard let cell = tableView.dequeueReusableCellOfType(type: MenstrualPeriodAddCell.self,
                                                                  forIndexPath: indexPath) else {
                assertionFailure("MenstrualPeriodAddCell not registered")
                return UITableViewCell()
            }
            return cell
        }
        guard let cell = tableView.dequeueReusableCellOfType(type: MenstrualPeriodEntryCell.self,
                                                              forIndexPath: indexPath) else {
            assertionFailure("MenstrualPeriodEntryCell not registered")
            return UITableViewCell()
        }
        cell.display(entry: entries[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Only entry rows are swipe-deletable; the add row is action-only.
        indexPath.section == Self.entriesSectionIndex
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard indexPath.section == Self.entriesSectionIndex else { return }
        if editingStyle == .delete {
            confirmDelete(at: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == Self.addSectionIndex {
            addTapped()
            return
        }
        guard indexPath.row < entries.count else { return }
        delegate?.menstrualPeriodDetailViewController(self, didSelect: entries[indexPath.row])
    }
}
