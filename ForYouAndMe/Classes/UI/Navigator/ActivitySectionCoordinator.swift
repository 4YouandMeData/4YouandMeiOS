//
//  ActivitySectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/10/2020.
//

import Foundation
import RxSwift

protocol ActivitySectionCoordinator: AnyObject, Coordinator {
    var repository: Repository { get }
    var navigator: AppNavigator { get }
    var taskIdentifier: String { get }
    var disposeBag: DisposeBag { get }
    var activityPresenter: UIViewController? { get }
    var completionCallback: NotificationCallback { get }
    
    func delayActivity()
}

extension ActivitySectionCoordinator {
    func delayActivity() {
        self.repository.delayTask(taskId: self.taskIdentifier)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.completionCallback()
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    if let presenter = self.activityPresenter {
                        self.navigator.handleError(error: error, presenter: presenter)
                    }
            }).disposed(by: self.disposeBag)
    }
}
