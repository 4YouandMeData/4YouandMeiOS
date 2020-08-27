//
//  VideoDiarySectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 26/08/2020.
//

import Foundation
import RxSwift

class VideoDiarySectionCoordinator: NSObject, ActivitySectionCoordinator {
    
    private weak var navigationController: UINavigationController?
    
    private let taskIdentifier: String
    private let completionCallback: NotificationCallback
    
    private let navigator: AppNavigator
    private let repository: Repository
    
    private let diposeBag = DisposeBag()
    
    init(withTaskIdentifier taskIdentifier: String,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = taskIdentifier
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init()
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController? {
        let paragraphs: [VideoDiaryIntroData.Paragraph] = [
            VideoDiaryIntroData.Paragraph(title: StringsProvider.string(forKey: .videoDiaryIntroParagraphTitleA),
                                          body: StringsProvider.string(forKey: .videoDiaryIntroParagraphBodyA)),
            VideoDiaryIntroData.Paragraph(title: StringsProvider.string(forKey: .videoDiaryIntroParagraphTitleB),
                                          body: StringsProvider.string(forKey: .videoDiaryIntroParagraphBodyB)),
            VideoDiaryIntroData.Paragraph(title: StringsProvider.string(forKey: .videoDiaryIntroParagraphTitleC),
                                          body: StringsProvider.string(forKey: .videoDiaryIntroParagraphBodyC))
        ]
        let introPageData = VideoDiaryIntroData(image: ImagePalette.image(withName: .videoDiaryIntro),
                                                title: StringsProvider.string(forKey: .videoDiaryIntroTitle),
                                                paragraphs: paragraphs,
                                                buttonText: StringsProvider.string(forKey: .videoDiaryIntroButton))
        let introViewController = VideoDiaryIntroViewController(withData: introPageData, coordinator: self)
        let navigationController = UINavigationController(rootViewController: introViewController)
        self.navigationController = navigationController
        return navigationController
    }
    
    public func onIntroPageCompleted() {
        self.showSuccessPage() // Test purpose
        // TODO: Show Record page
//        guard let navigationController = self.navigationController else {
//            assertionFailure("Missing expected navigation controller")
//            return
//        }
    }
    
    public func onRecordCompleted() {
        // TODO: Show Review page
//        guard let navigationController = self.navigationController else {
//            assertionFailure("Missing expected navigation controller")
//            return
//        }
    }
    
    public func onReviewCompleted(presenter: UIViewController) {
        self.sendResult(presenter: presenter)
    }
    
    public func onSuccessCompleted() {
        self.completionCallback()
    }
    
    // MARK: - Private Methods
    
    private func cancelTask() {
        try? FileManager.default.removeItem(atPath: Constants.Task.videoResultURL.path)
        self.completionCallback()
    }
    
    private func showSuccessPage() {
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing expected navigation controller")
            return
        }
        let pageData = VideoDiaryCompleteData(image: ImagePalette.image(withName: .videoDiarySuccess),
                                                title: StringsProvider.string(forKey: .videoDiarySuccessTitle),
                                                buttonText: StringsProvider.string(forKey: .videoDiarySuccessButton))
        let successViewController = VideoDiaryCompleteViewController(withData: pageData, coordinator: self)
        navigationController.pushViewController(successViewController, animated: true)
    }
    
    private func sendResult(presenter: UIViewController) {
        self.navigator.pushProgressHUD()
        guard let videoData = try? Data.init(contentsOf: Constants.Task.videoResultURL) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            self.navigator.handleError(error: nil, presenter: presenter, onDismiss: { [weak self] in
                self?.cancelTask()
            })
            return
        }
        let videoDataStream: String = videoData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        let taskNetworkResult = TaskNetworkResult(data: [:], attachedFile: videoDataStream)
        self.repository.sendTaskResult(taskId: self.taskIdentifier, taskResult: taskNetworkResult)
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                try? FileManager.default.removeItem(atPath: Constants.Task.videoResultURL.path)
                self.showSuccessPage()
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.navigator.handleError(error: error,
                                               presenter: presenter,
                                               onDismiss: { [weak self] in
                                                self?.cancelTask()
                        },
                                               onRetry: { [weak self] in
                                                self?.sendResult(presenter: presenter)
                        }, dismissStyle: .destructive)
            }).disposed(by: self.diposeBag)
    }
}
