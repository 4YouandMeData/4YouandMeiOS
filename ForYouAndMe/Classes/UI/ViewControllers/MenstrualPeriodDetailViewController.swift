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

    /// Called when the user closes the screen.
    func menstrualPeriodDetailViewControllerDidClose(_ vc: MenstrualPeriodDetailViewController)
}

final class MenstrualPeriodDetailViewController: BaseViewController {

    weak var delegate: MenstrualPeriodDetailViewControllerDelegate?

    /// Entries currently displayed. The caller decides which entries form
    /// the period (typically consecutive bleeding dates).
    private(set) var entries: [DiaryNoteItem]

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
        return tableView
    }()

    private lazy var addButton: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        view.setButtonText(StringsProvider.string(forKey: .menstrualDetailAddButton))
        view.setButtonEnabled(enabled: true)
        view.addTarget(target: self, action: #selector(addTapped))
        return view
    }()

    private lazy var closeButton: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        view.setButtonText(StringsProvider.string(forKey: .menstrualDetailCloseButton))
        view.setButtonEnabled(enabled: true)
        view.addTarget(target: self, action: #selector(closeTapped))
        return view
    }()

    init(entries: [DiaryNoteItem]) {
        self.entries = entries
        super.init()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        addCustomBackButton()
    }

    func update(entries: [DiaryNoteItem]) {
        self.entries = entries
        tableView.reloadData()
    }

    private func setupLayout() {
        let header = UIStackView()
        header.axis = .vertical
        header.alignment = .leading
        header.spacing = 8

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.font = UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize)
        titleLabel.textColor = ColorPalette.color(withType: .primaryText)
        titleLabel.text = StringsProvider.string(forKey: .menstrualDetailTitle)

        let subtitleLabel = UILabel()
        subtitleLabel.numberOfLines = 0
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = ColorPalette.color(withType: .primaryText)
        subtitleLabel.text = StringsProvider.string(forKey: .menstrualDetailMessage)

        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(subtitleLabel)
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 16,
                                            left: Constants.Style.DefaultHorizontalMargins,
                                            bottom: 16,
                                            right: Constants.Style.DefaultHorizontalMargins)

        let outer = UIStackView()
        outer.axis = .vertical
        outer.alignment = .fill
        outer.distribution = .fill
        outer.addArrangedSubview(header)
        outer.addArrangedSubview(addButton)
        outer.addArrangedSubview(tableView)

        view.addSubview(outer)
        outer.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        view.addSubview(closeButton)
        closeButton.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        outer.autoPinEdge(.bottom, to: .top, of: closeButton)

        addButton.autoSetDimension(.height, toSize: 64)
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellOfType(type: MenstrualPeriodEntryCell.self,
                                                              forIndexPath: indexPath) else {
            assertionFailure("MenstrualPeriodEntryCell not registered")
            return UITableViewCell()
        }
        let entry = entries[indexPath.row]
        let note: String?
        if case let .menstrual(_, _, _, _, payloadNote) = entry.payload {
            note = payloadNote
        } else {
            note = entry.body
        }
        cell.display(date: entry.diaryNoteId, note: note)
        return cell
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            confirmDelete(at: indexPath)
        }
    }
}
