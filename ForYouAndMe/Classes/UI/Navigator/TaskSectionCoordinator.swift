//
//  TaskSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 17/07/2020.
//

import Foundation
import ResearchKit
import RxSwift

class TaskSectionCoordinator: NSObject, PagedActivitySectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = false
    
    // MARK: - ActivitySectionCoordinator
    let taskIdentifier: String
    let navigator: AppNavigator
    let repository: Repository
    let completionCallback: NotificationCallback
    let disposeBag = DisposeBag()
    
    // MARK: - PagedActivitySectionCoordinator
    weak var activitySectionViewController: ActivitySectionViewController?
    let pagedSectionData: PagedSectionData
    var currentlyRescheduledTimes: Int
    var maxRescheduleTimes: Int
    var coreViewController: UIViewController? { self.getTaskViewController() }
    
    private let taskType: TaskType
    private let taskOptions: TaskOptions?
    
    init(withTask task: Feed,
         activity: Activity,
         taskType: TaskType,
         taskOptions: TaskOptions?,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = task.id
        self.pagedSectionData = activity.pagedSectionData
        self.currentlyRescheduledTimes = task.rescheduledTimes ?? 0
        self.maxRescheduleTimes = activity.rescheduleTimes ?? 0
        self.taskType = taskType
        self.taskOptions = taskOptions
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init()
    }
    
    deinit {
        print("TaskSectionCoordinator - deinit")
        self.deleteTaskResult(path: Constants.Task.TaskResultURL)
    }
    
    // MARK: - Private Methods
    
    private func getTaskViewController() -> UIViewController? {
        self.customizeTaskTexts()
        guard let task = self.taskType.createTask(withIdentifier: self.taskIdentifier,
                                                  options: self.taskOptions,
                                                  showIstructions: true,
                                                  showConclusion: true) else {
            assertionFailure("Couldn't find ORKTask for given task")
            return nil
        }
        
        self.customizeTaskUI()
        
        // Create and setup task controller
        let taskViewController = ORKTaskViewController(task: task, taskRun: nil)
        taskViewController.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: true).style)
        taskViewController.delegate = self
        taskViewController.view.tintColor = ColorPalette.color(withType: .primary)
        taskViewController.outputDirectory = Constants.Task.TaskResultURL
        taskViewController.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        return taskViewController
    }
    
    private func customizeTaskUI() {
        
        self.navigationController.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: true).style)
        
        // Setup Colors
        ORKColorSetColorForKey(ORKCheckMarkTintColorKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKAlertActionTintColorKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKBlueHighlightColorKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKToolBarTintColorKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKBackgroundColorKey, ColorPalette.color(withType: .secondary))
        ORKColorSetColorForKey(ORKResetDoneButtonKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKDoneButtonPressedKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKBulletItemTextColorKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKAuxiliaryImageTintColorKey, ColorPalette.color(withType: .primary))
        ORKColorSetColorForKey(ORKTopContentImageViewBackgroundColorKey, ColorPalette.color(withType: .secondary))
        
        // Setup Layout
        ORKBorderedButtonCornerRadius = 25.0
        ORKBorderedButtonShouldApplyDefaultShadow = true
    }
    
    private func customizeTaskTexts() {
        // TODO: when backend will support localization,
        // set this so that ResearchKit language and the study language are the same
        ORKCustomLanguageCodeSetLanguageCode("en")
        
        StringsProvider.taskStrings.forEach { pair in
            ORKCustomTextSetCustomForKey(pair.0, pair.1)
        }
    }
    
    private func cancelTask() {
        self.completionCallback()
    }
    
    private func handleError(error: Error?, presenter: UIViewController) {
        if let error = error {
            print("TaskSectionCoordinator - Error: \(error)")
        }
        self.navigator.handleError(error: nil, presenter: presenter, onDismiss: { [weak self] in
            self?.cancelTask()
        })
    }
    
    private func sendResult(taskResult: ORKTaskResult, presenter: UIViewController) {
        guard let taskNetworkResult = self.taskType.getNetworkResultData(taskResult: taskResult) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            self.navigator.handleError(error: nil, presenter: presenter, onDismiss: { [weak self] in
                self?.cancelTask()
            })
            return
        }
        self.repository.sendTaskResult(taskId: self.taskIdentifier, taskResult: taskNetworkResult)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.deleteTaskResult(path: Constants.Task.TaskResultURL)
                self.showSuccessPage()
            }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error,
                                               presenter: presenter,
                                               onDismiss: { [weak self] in
                                                self?.cancelTask()
                        },
                                               onRetry: { [weak self] in
                                                self?.sendResult(taskResult: taskResult, presenter: presenter)
                    }, dismissStyle: .destructive)
            }).disposed(by: self.disposeBag)
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
        // TODO: Check if this is really needed (taken from ORKCatalog)
        if stepViewController.step?.identifier == "WaitStepIndeterminate" ||
            stepViewController.step?.identifier == "WaitStep" ||
            stepViewController.step?.identifier == "LoginWaitStep" {
            print("TaskSectionCoordinator - A delay was needed")
            delay(5.0, closure: { () -> Void in
                if let stepViewController = stepViewController as? ORKWaitStepViewController {
                    stepViewController.goForward()
                }
            })
        }
    }
}

fileprivate extension StringsProvider {
    
    static let taskPrefix = "RK_"
    
    static var taskStrings: [String: String] {
        return self.fullStringMap.filter { $0.key.hasPrefix(self.taskPrefix) }.reduce([:]) { (taskStrings, pair) -> [String: String] in
            var taskStrings = taskStrings
            taskStrings[String(pair.0.dropFirst(self.taskPrefix.count))] = pair.1
            return taskStrings
        }
    }
}
