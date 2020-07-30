//
//  TaskSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 17/07/2020.
//

import Foundation
import ResearchKit
import RxSwift

class TaskSectionCoordinator: NSObject {
    
    private let taskIdentifier: String
    private let taskType: TaskType
    private let taskOptions: TaskOptions?
    private let completionCallback: NotificationCallback
    
    private let locationService: LocationService
    private let navigator: AppNavigator
    private let repository: Repository
    
    private let diposeBag = DisposeBag()
    
    init(withTaskIdentifier taskIdentifier: String,
         taskType: TaskType,
         taskOptions: TaskOptions?,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = taskIdentifier
        self.taskType = taskType
        self.taskOptions = taskOptions
        self.completionCallback = completionCallback
        self.locationService = Services.shared.locationService
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init()
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        let task = self.taskType.createTask(withIdentifier: self.taskIdentifier,
                                            options: self.taskOptions,
                                            locationAuthorised: self.locationService.locationAuthorized)
        let taskViewController = ORKTaskViewController(task: task, taskRun: nil)
        taskViewController.delegate = self
        taskViewController.outputDirectory = Constants.Task.taskResultURL
        return taskViewController
    }
    
    // MARK: - Private Methods
    
    private func cancelTask() {
        self.completionCallback()
    }
    
    private func handleError(error: Error?, presenter: UIViewController) {
        if let error = error {
            print("TaskSectionCoordinator - Error: \(error)")
        }
        self.navigator.handleError(error: nil, presenter: presenter, completion: { [weak self] in
            self?.cancelTask()
        })
    }
    
    private func sendResult(taskResult: ORKTaskResult, presenter: UIViewController) {
        guard let taskNetworkResult = self.taskType.getNetworkResultData(taskResult: taskResult) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            self.navigator.handleError(error: nil, presenter: presenter, completion: { [weak self] in
                self?.cancelTask()
            })
            return
        }
        self.navigator.pushProgressHUD()
        self.repository.sendTaskResult(taskId: self.taskIdentifier, taskResult: taskNetworkResult)
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                self.deleteTaskResult(path: Constants.Task.taskResultURL)
                self.completionCallback()
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                self.navigator.handleError(error: error, presenter: presenter)
            }).disposed(by: self.diposeBag)
    }
    
    private func delay(_ delay: Double, closure: @escaping () -> Void ) {
        let delayTime = DispatchTime.now() + delay
        let dispatchWorkItem = DispatchWorkItem(block: closure)
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: dispatchWorkItem)
    }
    
    private func deleteTaskResult(path: URL) {
        let outputDirectory = path
        do {
            try FileManager.default.removeItem(atPath: outputDirectory.path)
        } catch let error {
            debugPrint(error)
        }
    }
}

extension TaskSectionCoordinator: ORKTaskViewControllerDelegate {
    func taskViewController(_ taskViewController: ORKTaskViewController,
                            didFinishWith reason: ORKTaskViewControllerFinishReason,
                            error: Error?) {
//        print("TaskSectionCoordinator - Task Finished with reason: \(reason). Result: \(taskViewController.result)")
        switch reason {
        case .completed:
            print("TaskSectionCoordinator - Task Completed")
            self.sendResult(taskResult: taskViewController.result, presenter: taskViewController)
        case .discarded:
            print("TaskSectionCoordinator - Task Discarded")
            self.cancelTask()
        case .failed:
            print("TaskSectionCoordinator - Task Failed")
            self.handleError(error: error, presenter: taskViewController)
        case .saved:
            print("TaskSectionCoordinator - Task Saved")
            self.cancelTask()
        @unknown default:
            print("TaskSectionCoordinator - Unhandled case")
            self.handleError(error: error, presenter: taskViewController)
        }
    }
    
    func taskViewController(_ taskViewController: ORKTaskViewController,
                            stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        
        // TODO: Check this against all cases
        
        if stepViewController.step?.identifier == "WaitStepIndeterminate" ||
            stepViewController.step?.identifier == "WaitStep" ||
            stepViewController.step?.identifier == "LoginWaitStep" {
            delay(5.0, closure: { () -> Void in
                if let stepViewController = stepViewController as? ORKWaitStepViewController {
                    stepViewController.goForward()
                }
            })
        }
    }
}
