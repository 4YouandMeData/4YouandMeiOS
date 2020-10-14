//
//  VideoDiarySectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 26/08/2020.
//

import Foundation
import RxSwift

class VideoDiarySectionCoordinator: NSObject, ActivitySectionCoordinator {
    
    var navigationController: UINavigationController {
        guard let navigationController = self.internalNavigationController else {
            assertionFailure("Missing navigation controller")
            return UINavigationController()
        }
        return navigationController
    }
    private weak var internalNavigationController: UINavigationController?
    
    // MARK: - ActivitySectionCoordinator
    var activityPresenter: UIViewController? { return self.navigationController }
    let taskIdentifier: String
    let completionCallback: NotificationCallback
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
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
                                                primaryButtonText: StringsProvider.string(forKey: .videoDiaryIntroButton),
                                                secondaryButtonText: StringsProvider.string(forKey: .taskRemindMeLater))
        let introViewController = VideoDiaryIntroViewController(withData: introPageData, coordinator: self)
        let navigationController = UINavigationController(rootViewController: introViewController)
        self.internalNavigationController = navigationController
        return navigationController
    }
    
    public func onIntroPagePrimaryButtonPressed() {
        self.showRecordPage()
    }
    
    public func onIntroPageSecondaryButtonPressed() {
        self.delayActivity()
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
        let recordViewController = VideoDiaryRecorderViewController(taskIdentifier: self.taskIdentifier,
                                                                     coordinator: self)
        self.navigationController.pushViewController(recordViewController, animated: true)
    }
    
    private func showSuccessPage() {
        let pageData = VideoDiaryCompleteData(image: ImagePalette.image(withName: .videoDiarySuccess),
                                                title: StringsProvider.string(forKey: .videoDiarySuccessTitle),
                                                buttonText: StringsProvider.string(forKey: .videoDiarySuccessButton))
        let successViewController = VideoDiaryCompleteViewController(withData: pageData, coordinator: self)
        self.navigationController.pushViewController(successViewController, animated: true)
    }
}
