//
//  TaskSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 17/07/2020.
//

import Foundation
import ResearchKit

enum TaskType: String, CaseIterable {
    case reactionTime
    case trailMaking
    case walk
    case gait
    case tremor
    
    var identifier: String {
        return self.rawValue
    }
}

class TestTaskSheetViewController: UIViewController {
    
    var currentTaskCoordinator: TaskSectionCoordinator?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero)
        
        scrollStackView.stackView.addBlankSpace(space: 50.0)
        
        TaskType.allCases.forEach { taskType in
            self.addButton(forType: taskType, stackView: scrollStackView.stackView)
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: true).style)
    }
    
    // MARK: Actions
    
    @objc private func reactionTimeButtonPressed() {
        self.startTaskSection(taskType: .reactionTime)
    }
    
    @objc private func trailMakingButtonPressed() {
        self.startTaskSection(taskType: .trailMaking)
    }
    
    @objc private func walkButtonPressed() {
        self.startTaskSection(taskType: .walk)
    }
    
    @objc private func gaitButtonPressed() {
        self.startTaskSection(taskType: .gait)
    }
    
    @objc private func tremorButtonPressed() {
        self.startTaskSection(taskType: .tremor)
    }
    
    // MARK: Private Methods
    
    private func addButton(forType type: TaskType, stackView: UIStackView) {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        switch type {
        case .reactionTime:
            buttonView.setButtonText("Reaction Time")
            buttonView.addTarget(target: self, action: #selector(self.reactionTimeButtonPressed))
        case .trailMaking:
            buttonView.setButtonText("Trail Making")
            buttonView.addTarget(target: self, action: #selector(self.trailMakingButtonPressed))
        case .walk:
            buttonView.setButtonText("Walk")
            buttonView.addTarget(target: self, action: #selector(self.walkButtonPressed))
        case .gait:
            buttonView.setButtonText("Gait")
            buttonView.addTarget(target: self, action: #selector(self.gaitButtonPressed))
        case .tremor:
            buttonView.setButtonText("Tremor")
            buttonView.addTarget(target: self, action: #selector(self.tremorButtonPressed))
        }
        stackView.addArrangedSubview(buttonView)
    }
    
    private func startTaskSection(taskType: TaskType) {
        guard let navigationController = self.navigationController else { return }
        let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
            guard let self = self else { return }
            navigationController.dismiss(animated: true, completion: nil)
            self.currentTaskCoordinator = nil
        }
        let coordinator = TaskSectionCoordinator(withTaskType: taskType,
                                                 navigationController: navigationController,
                                                 completionCallback: completionCallback)
        let startingPage = coordinator.getStartingPage()
        navigationController.present(startingPage, animated: true, completion: nil)
        self.currentTaskCoordinator = coordinator
    }
}

class TaskSectionCoordinator: NSObject {
    
    public unowned var navigationController: UINavigationController
    
    private let taskType: TaskType
    private let completionCallback: NavigationControllerCallback
    
    init(withTaskType taskType: TaskType,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.navigationController = navigationController
        self.taskType = taskType
        self.completionCallback = completionCallback
        super.init()
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        let task: ORKTask = {
            switch self.taskType {
            case .reactionTime:
                return self.createReactionTimeTask()
            case .trailMaking:
                return self.createTrailMakingTask()
            case .walk:
                return self.createWalkTask()
            case .gait:
                return self.createGaitTask()
            case .tremor:
                return self.createTremorTask()
            }
        }()
        let taskViewController = ORKTaskViewController(task: task, taskRun: nil)
        taskViewController.delegate = self
        // It's mandatory for som tasks (e.g.: Reaction Time Task)
        taskViewController.outputDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        taskViewController.view.backgroundColor = ColorPalette.color(withType: .secondary)
//        taskViewController.isNavigationBarHidden = true
        return taskViewController
    }
    
    // MARK: - Private Methods
    
    private func createReactionTimeTask() -> ORKTask {
        return ORKOrderedTask.reactionTime(withIdentifier: self.taskType.identifier,
                                           intendedUseDescription: "aovoiv oon auvon",
                                           maximumStimulusInterval: 10,
                                           minimumStimulusInterval: 4,
                                           thresholdAcceleration: 0.5,
                                           numberOfAttempts: 3,
                                           timeout: 3,
                                           successSound: UInt32(kSystemSoundID_Vibrate),
                                           timeoutSound: 0,
                                           failureSound: UInt32(kSystemSoundID_Vibrate),
                                           options: [])
    }
    
    private func createTrailMakingTask() -> ORKTask {
        
        return ORKOrderedTask.trailmakingTask(withIdentifier: self.taskType.identifier,
                                              intendedUseDescription: "Trail making",
                                              trailmakingInstruction: "Trail making instructions",
                                              trailType: ORKTrailMakingTypeIdentifier.A,
                                              options: [])
    }
    
    private func createWalkTask() -> ORKTask {
        
        return ORKOrderedTask.timedWalk(withIdentifier: self.taskType.identifier,
                                        intendedUseDescription: "Walk Test",
                                        distanceInMeters: 100,
                                        timeLimit: 180.0,
                                        turnAroundTimeLimit: 60.0,
                                        includeAssistiveDeviceForm: true,
                                        options: [])
    }
    
    private func createGaitTask() -> ORKTask {
        
        return ORKOrderedTask.shortWalk(withIdentifier: self.taskType.identifier,
                                        intendedUseDescription: nil,
                                        numberOfStepsPerLeg: 20,
                                        restDuration: 20,
                                        options: [])
    }
    
    private func createTremorTask() -> ORKTask {
        
        return ORKOrderedTask.tremorTest(withIdentifier: self.taskType.identifier,
                                         intendedUseDescription: nil,
                                         activeStepDuration: 10,
                                         activeTaskOptions: [],
                                         handOptions: [.both],
                                         options: [])
    }
    
    private func cancelTask() {
        self.completionCallback(self.navigationController)
    }
    
    private func delay(_ delay: Double, closure: @escaping () -> Void ) {
        let delayTime = DispatchTime.now() + delay
        let dispatchWorkItem = DispatchWorkItem(block: closure)
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: dispatchWorkItem)
    }
}

extension TaskSectionCoordinator: ORKTaskViewControllerDelegate {
    func taskViewController(_ taskViewController: ORKTaskViewController,
                            didFinishWith reason: ORKTaskViewControllerFinishReason,
                            error: Error?) {
        print("TaskSectionCoordinator - Task Finished with reason: \(reason). Result: \(taskViewController.result)")
        switch reason {
        case .completed:
            self.completionCallback(self.navigationController)
        case .discarded:
            print("TaskSectionCoordinator - Task Discarded")
            self.cancelTask()
        case .failed:
            self.completionCallback(self.navigationController)
        case .saved:
            print("TaskSectionCoordinator - Task Saved")
            self.cancelTask()
        @unknown default:
            print("TaskSectionCoordinator - Unhandled case")
            self.cancelTask()
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
