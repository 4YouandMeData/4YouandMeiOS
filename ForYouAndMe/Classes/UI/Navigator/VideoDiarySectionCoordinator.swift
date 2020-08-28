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
    
    deinit {
        self.deleteVideoResult()
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
        self.showRecordPage()
    }
    
    public func onRecordCompleted() {
        self.deleteVideoResult()
        self.showSuccessPage()
    }
    
    public func onSuccessCompleted() {
        self.completionCallback()
    }
    
    public func onCancelTask() {
        self.completionCallback()
    }
    
    // MARK: - Private Methods
    
    private func deleteVideoResult() {
       try? FileManager.default.removeItem(atPath: Constants.Task.videoResultURL.path)
    }
    
    private func cancelTask() {
        self.completionCallback()
    }
    
    private func showRecordPage() {
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing expected navigation controller")
            return
        }
        let recordViewController = VideoDiaryRecorderViewController(taskIdentifier: self.taskIdentifier,
                                                                     coordinator: self)
        navigationController.pushViewController(recordViewController, animated: true)
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
}
