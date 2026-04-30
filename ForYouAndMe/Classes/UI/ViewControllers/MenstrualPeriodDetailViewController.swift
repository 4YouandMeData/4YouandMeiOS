//
//  MenstrualPeriodDetailViewController.swift
//  ForYouAndMe
//
//  FUAM-2934 — Detail screen for a single menstrual period: lists every
//  bleeding entry, lets the user add another date or swipe-delete an
//  existing one. Editing individual entries is out of scope for this
//  release.
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

    /// Entries currently displayed. The caller decides which entries form
    /// the period (typically consecutive bleeding dates).
    private(set) var entries: [DiaryNoteItem]

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

    init(entries: [DiaryNoteItem]) {
        self.entries = entries
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

    func update(entries: [DiaryNoteItem]) {
        self.entries = entries
        tableView.reloadData()
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
        self.repository.deleteDiaryNote(noteID: entry.id)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                guard indexPath.row < self.entries.count,
                      self.entries[indexPath.row].id == entry.id else {
                    self.tableView.reloadData()
                    return
                }
                self.entries.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.entries.isEmpty {
                    self.delegate?.menstrualPeriodDetailViewControllerDidClose(self)
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
