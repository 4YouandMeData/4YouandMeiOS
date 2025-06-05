//
//  WeHaveNoticedCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 05/06/25.
//

enum FlowVariant {
    case standalone
    case embeddedInNoticed
}

/// Coordinator for the “We Have Noticed” flow, embedding the existing
/// InsulinEntryCoordinator as the first step.
final class WeHaveNoticedCoordinator: Coordinator {

    // MARK: – Coordinator Conformance

    /// If true, hides the bottom bar when this coordinator's pages are pushed.
    var hidesBottomBarWhenPushed: Bool = false

    // MARK: – Properties

    /// Repository layer for API or data persistence.
    private let repository: Repository

    /// Shared AppNavigator instance.
    private let navigator: AppNavigator

    /// Unique identifier for this flow.
    private let taskIdentifier: String

    /// The view controller that initially presents this flow (used to dismiss modally).
    private weak var presentingViewController: UIViewController?

    /// Callback invoked when the entire flow finishes.
    private var completionCallback: NotificationCallback

    /// Child coordinator for insulin‐entry flow.
    private var insulinCoordinator: InsulinEntryCoordinator?
    private var foodCoordinator: FoodEntryCoordinator?

    /// The internally created UINavigationController that hosts all steps.
    private var navController: UINavigationController?

    // MARK: – Initialization

    /// Initializes the WeHaveNoticedCoordinator.
    ///
    /// - Parameters:
    ///   - repository: The repository layer for data/network operations.
    ///   - navigator: The AppNavigator for navigation actions.
    ///   - taskIdentifier: A unique identifier string for this flow.
    ///   - presenter: The UIViewController that will present the flow modally.
    ///   - completion: Callback called when the entire flow finishes.
    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         presenter: UIViewController,
         completion: @escaping NotificationCallback) {

        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
        self.presentingViewController = presenter
        self.completionCallback = completion
    }

    // MARK: – Coordinator

    /// Returns the root UIViewController for this flow. If the presenter is not a UINavigationController,
    /// this method creates one internally, embeds the insulin‐entry flow, and returns it.
    func getStartingPage() -> UIViewController {
        
        let introVC = NoticedIntroViewController(dynamicMessage: "")
        introVC.delegate = self

        let nav = UINavigationController(rootViewController: introVC)
        nav.modalPresentationStyle = .fullScreen
        nav.preventPopWithSwipe()
        self.navController = nav

        return nav
    }
    
    private func showInsulinEntry() {
        guard let nav = navController else {
            assertionFailure("Missing internal UINavigationController")
            finishFlow()
            return
        }

        let insulin = InsulinEntryCoordinator(
            repository: repository,
            navigator: navigator,
            variant: .embeddedInNoticed,
            taskIdentifier: "\(taskIdentifier)_InsulinEntry",
            externalNavigationController: nav,
            completion: { [weak self] in
                self?.insulinFlowDidFinish()
            }
        )
        self.insulinCoordinator = insulin
        _ = insulin.getStartingPage()
    }

    // MARK: – Private Methods

    /// Called when the InsulinEntryCoordinator finishes its flow.
    private func insulinFlowDidFinish() {
        // Release the child coordinator.
        insulinCoordinator = nil

        // Proceed to the next step after insulin data entry.
        showFoodEntry()
    }

    private func showFoodEntry() {
        guard let nav = navController else {
            assertionFailure("Missing internal UINavigationController for food")
            finishFlow()
            return
        }

        // 1) Crea il FoodEntryCoordinator usando la stessa nav
        let food = FoodEntryCoordinator(
            repository: repository,
            navigator: navigator,
            taskIdentifier: "\(taskIdentifier)_FoodEntry",
            variant: .embeddedInNoticed,
            externalNavigationController: nav,
            completion: { [weak self] in
                self?.finishFlow()
            }
        )

        self.foodCoordinator = food
        _ = food.getStartingPage()
    }

    /// Called to finish the flow or proceed to a final confirmation.
    private func finishFlow() {
        // Dismiss the modal presentation (the UINavigationController).
        presentingViewController?.dismiss(animated: true, completion: nil)

        // Invoke the completion callback to notify whoever started this flow.
        completionCallback()
    }
}

extension WeHaveNoticedCoordinator: NoticedIntroViewControllerDelegate {
    func noticedIntroViewControllerDidSelectYes(_ vc: NoticedIntroViewController) {
        showInsulinEntry()
    }
    func noticedIntroViewControllerDidSelectNo(_ vc: NoticedIntroViewController) {
        showFoodEntry()
    }
    func noticedIntroViewControllerDidCancel(_ vc: NoticedIntroViewController) {
        finishFlow()
    }
}

// MARK: – DidYouEatViewControllerDelegate

//extension WeHaveNoticedCoordinator: DidYouEatViewControllerDelegate {
//    func didYouEatViewController(_ vc: DidYouEatViewController, didSelect ate: Bool) {
//        // Handle the user's response (ate or not).
//        // Example: you could save `ate` or perform additional logic here.
//
//        // End the flow, since no further steps follow in this example.
//        finishFlow()
//
//        // If you need additional steps after “Did you eat?”, replace finishFlow()
//        // with the code to push the next view controller.
//    }
//
//    func didYouEatViewControllerDidCancel(_ vc: DidYouEatViewController) {
//        // If user cancels, end the flow immediately.
//        finishFlow()
//    }
//}
