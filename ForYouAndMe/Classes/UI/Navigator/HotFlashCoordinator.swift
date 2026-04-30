//
//  HotFlashCoordinator.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 23/04/26.
//

import UIKit
import RxSwift

final class HotFlashCoordinator {

    private let repository: Repository
    private let navigator: AppNavigator
    private let variant: FlowVariant
    private let completionCallback: NotificationCallback
    private let disposeBag = DisposeBag()

    private var eventDate: Date?
    private var rootNavigationController: UINavigationController?

    init(repository: Repository,
         navigator: AppNavigator,
         variant: FlowVariant,
         completion: @escaping NotificationCallback) {
        self.repository = repository
        self.navigator = navigator
        self.variant = variant
        self.completionCallback = completion
    }

    func getStartingPage() -> UIViewController {
        let timeVC = HotFlashTimeViewController(variant: variant)
        timeVC.delegate = self
        let nav = UINavigationController(rootViewController: timeVC)
        self.rootNavigationController = nav
        return nav
    }

    private func submit() {
        guard let date = self.eventDate else { return }
        let data = DiaryNoteHotFlashData(
            date: date,
            fromChart: variant.isFromChart,
            diaryNote: variant.chartDiaryNote
        )
        self.repository.sendDiaryNoteHotFlash(data: data)
            .addProgress()
            .subscribe(onSuccess: { [weak self] note in
                self?.showSuccessPage(diaryNote: note)
            }, onFailure: { [weak self] error in
                guard let self = self, let presenter = self.rootNavigationController else { return }
                self.navigator.handleError(error: error, presenter: presenter)
            }).disposed(by: self.disposeBag)
    }

    private func showSuccessPage(diaryNote: DiaryNoteItem) {
        let vc = HotFlashSuccessViewController(diaryNote: diaryNote,
                                               completion: self.completionCallback)
        vc.modalPresentationStyle = .fullScreen
        self.rootNavigationController?.pushViewController(vc, animated: true)
    }
}

extension HotFlashCoordinator: HotFlashTimeViewControllerDelegate {
    func hotFlashTimeViewController(_ vc: HotFlashTimeViewController,
                                    didSelect relative: HotFlashTimeViewController.TimeRelative) {
        switch relative {
        case .justNow:
            self.eventDate = Date()
            self.submit()
        case .inThePast:
            let dateVC = HotFlashDateTimeViewController(variant: variant)
            dateVC.delegate = self
            self.rootNavigationController?.pushViewController(dateVC, animated: true)
        }
    }

    func hotFlashTimeViewControllerDidDismiss(_ vc: HotFlashTimeViewController) {
        self.completionCallback()
    }
}

extension HotFlashCoordinator: HotFlashDateTimeViewControllerDelegate {
    func hotFlashDateTimeViewController(_ vc: HotFlashDateTimeViewController, didSelect date: Date) {
        self.eventDate = date
        self.submit()
    }

    func hotFlashDateTimeViewControllerDidCancel(_ vc: HotFlashDateTimeViewController) {
        self.completionCallback()
    }
}
