//
//  AppNavigator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import SVProgressHUD
import RxSwift
import SafariServices
import WebKit

enum InternalDeeplinkKey: String {
    case feed
    case task
    case diary
    case userData = "your_data"
    case studyInfo = "study_info"
    case aboutYou = "about_you"
    case faq
    case rewards
    case contacts
    case consent = "new_consent_version_available"
}

enum MainTab: Int, CaseIterable { case feed = 0, task = 1, diary = 2, userData = 3, studyInfo = 4 }

class AppNavigator {
    
    enum StudyInfoPage { case faq, reward, contacts }
    
    static let defaultStartingTab: MainTab = .feed
    
    private static var progressHudCount = 0
    
    private var setupCompleted = false
    private var pushPermissionCompleted: Bool = false
    private var currentCoordinator: Coordinator?
    private weak var currentActivityCoordinator: ActivitySectionCoordinator?
    
    private var isTaskInProgress: Bool {
        return nil != self.currentActivityCoordinator
    }
    
    private let repository: Repository
    private let analytics: AnalyticsService
    private let deeplinkService: DeeplinkService
    private let window: UIWindow
    
    private let disposeBag = DisposeBag()
    
    init(withRepository repository: Repository, analytics: AnalyticsService, deeplinkService: DeeplinkService, window: UIWindow) {
        self.repository = repository
        self.analytics = analytics
        self.deeplinkService = deeplinkService
        self.window = window
        
        // Needed to block user interaction!! :S
        SVProgressHUD.setDefaultMaskType(.black)
    }
    
    // MARK: - Initialization
    
    func showSetupScreen() {
        self.window.rootViewController = LoadingViewController<()>(loadingMode: .initialSetup)
    }
    
    func showSetupCompleted() {
        self.onStartup()
    }
    
    // MARK: - Top level
    
    func onStartup() {
        
        // Convenient entry point to test each app module atomically,
        // without going through all the official flow
        #if DEBUG
        if let testSection = Constants.Test.StartingOnboardingSection,
           let sectionDriver = OnboardingSectionProvider.onboardingSectionDriver {
            let testNavigationViewController = UINavigationController(rootViewController: UIViewController())
            
            testNavigationViewController.preventPopWithSwipe()
            self.window.rootViewController = testNavigationViewController
            
            self.startOnboardingSection(section: testSection,
                                        sectionDriver: sectionDriver,
                                        navigationController: testNavigationViewController,
                                        hidesBottomBarWhenPushed: false,
                                        addAbortOnboardingButton: true)
            return
        }
        #endif
        
        self.setupCompleted = true
        if self.repository.isLoggedIn {
            if self.repository.currentUser?.isOnboardingCompleted ?? false {
                self.goHome()
            } else {
                self.deeplinkService.clearCurrentDeeplinkedData()
                // If onboarding is not completed, log out (restart from the very beginning)
                self.logOut()
            }
        } else {
            self.deeplinkService.clearCurrentDeeplinkedData()
            self.goToWelcome()
        }
    }
    
    public func abortOnboardingWithWarning(presenter: UIViewController) {
        let cancelAction = UIAlertAction(title: StringsProvider.string(forKey: .onboardingAbortCancel),
                                         style: .cancel,
                                         handler: nil)
        let confirmAction = UIAlertAction(title: StringsProvider.string(forKey: .onboardingAbortConfirm),
                                          style: .destructive,
                                          handler: { [weak self] _ in self?.abortOnboarding() })
        presenter.showAlert(withTitle: StringsProvider.string(forKey: .onboardingAbortTitle),
                            message: StringsProvider.string(forKey: .onboardingAbortMessage),
                            actions: [cancelAction, confirmAction],
                            tintColor: ColorPalette.color(withType: .primary))
    }
    
    public func abortOnboarding() {
        
        if (self.currentCoordinator as? ScreeningSectionCoordinator) != nil {
            self.analytics.track(event: .cancelDuringScreeningQuestion(""))
        } else if let coordinator = self.currentCoordinator as? InformedConsentSectionCoordinator {
            if coordinator.currentPage != nil {
                self.analytics.track(event: .cancelDuringInformedConsent(coordinator.currentPage?.id ?? ""))
            } else if coordinator.currentQuestion != nil {
                self.analytics.track(event: .cancelDuringComprehensionQuiz(coordinator.currentQuestion?.id ?? ""))
            }
        } else if (self.currentCoordinator as? ConsentSectionCoordinator) != nil {
            self.analytics.track(event: .consentDisagreed)
        }
        self.goToWelcome()
    }
    
    // MARK: - Welcome
    
    public func goToWelcome() {
        let navigationViewController = UINavigationController(rootViewController: WelcomeViewController())
        navigationViewController.preventPopWithSwipe()
        self.window.rootViewController = navigationViewController
    }
    
    public func showIntro(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(IntroViewController(), animated: true)
    }
    
    public func showSetupLater(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(SetupLaterViewController(), animated: true)
    }
    
    public func goBackToWelcome(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.popToExpectedViewController(ofClass: WelcomeViewController.self, animated: true)
    }
    
    public func showWalkThrough(presenter: UIViewController, studyInfoSection: StudyInfoSection) {
        guard let walkthroughPage = studyInfoSection.walkThroughPage else {
            return
        }
        let walkthrough = WalkthroughViewController(walkThroughPage: walkthroughPage)
        walkthrough.modalPresentationStyle = .fullScreen
        walkthrough.pages = studyInfoSection.pages
        presenter.present(walkthrough, animated: true)
    }
    
    // MARK: - Login
    
    public func showLogin(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(PhoneVerificationViewController(), animated: true)
    }
    
    public func showCodeValidation(countryCode: String, phoneNumber: String, presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        let codeValidationViewController = CodeValidationViewController(countryCode: countryCode, phoneNumber: phoneNumber)
        navigationController.pushViewController(codeValidationViewController, animated: true)
    }
    
    public func showPrivacyPolicy(presenter: UIViewController) {
        guard let url = URL(string: StringsProvider.string(forKey: .urlPrivacyPolicy)) else {
            assertionFailure("Invalid Url for privacy policy")
            return
        }
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.privacyPolicy.rawValue,
                                                  screenClass: String(describing: type(of: presenter))))
        self.openWebView(withTitle: "", url: url, presenter: presenter, configuration: nil)
    }
    
    public func showTermsOfService(presenter: UIViewController) {
        guard let url = URL(string: StringsProvider.string(forKey: .urlTermsOfService)) else {
            assertionFailure("Invalid Url for terms of service")
            return
        }
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.termsOfService.rawValue,
                                                  screenClass: String(describing: type(of: presenter))))
        self.openWebView(withTitle: "", url: url, presenter: presenter, configuration: nil)
    }
    
    public func onLoginCompleted(presenter: UIViewController) {
        guard let currentUser = self.repository.currentUser else {
            assertionFailure("Missing current user right after login")
            return
        }
        if currentUser.isOnboardingCompleted {
            self.goHome()
        } else {
            self.startOnboarding(presenter: presenter)
        }
    }
    
    // MARK: Onboarding
    
    private func startOnboarding(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        if let sectionDriver = OnboardingSectionProvider.onboardingSectionDriver,
           let firstSection = sectionDriver.firstOnboardingSection {
            self.startOnboardingSection(section: firstSection,
                                        sectionDriver: sectionDriver,
                                        navigationController: navigationController,
                                        hidesBottomBarWhenPushed: false,
                                        addAbortOnboardingButton: true)
        } else {
            self.goHome()
        }
    }
    
    private func startOnboardingSection(section: OnboardingSection,
                                        sectionDriver: OnboardingSectionDriver,
                                        navigationController: UINavigationController,
                                        hidesBottomBarWhenPushed: Bool,
                                        addAbortOnboardingButton: Bool) {
        let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
            guard let self = self else { return }
            if let nextSection = sectionDriver.getNextOnboardingSection(forOnboardingSection: section) {
                self.startOnboardingSection(section: nextSection,
                                            sectionDriver: sectionDriver,
                                            navigationController: navigationController,
                                            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                            addAbortOnboardingButton: addAbortOnboardingButton)
            } else {
                self.repository.notifyOnboardingCompleted()
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] in
                        guard let self = self else { return }
                        self.currentCoordinator = nil
                        self.goHome()
                    }, onFailure: { [weak self] error in
                        self?.handleError(error: error, presenter: navigationController)
                    })
                    .disposed(by: self.disposeBag)
            }
        }
        if let syncCoordinator = section.getSyncCoordinator(withNavigationController: navigationController,
                                                            completionCallback: completionCallback) {
            self.setCurrentCoordinator(syncCoordinator,
                                       hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                       addAbortOnboardingButton: addAbortOnboardingButton)
            navigationController.pushViewController(syncCoordinator.getStartingPage(),
                                                    hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                    animated: true)
        } else if let asyncCoordinatorRequest = section.getAsyncCoordinatorRequest(withNavigationController: navigationController,
                                                                                   completionCallback: completionCallback,
                                                                                   repository: self.repository) {
            navigationController.loadViewForRequest(asyncCoordinatorRequest,
                                                    hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                    allowBackwardNavigation: false,
                                                    viewForData: { coordinator -> UIViewController in
                self.setCurrentCoordinator(coordinator,
                                           hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                           addAbortOnboardingButton: addAbortOnboardingButton)
                return coordinator.getStartingPage()
            })
        } else {
            assertionFailure("Section has neither a syncCoorindator nor an asyncCoordinator")
            self.currentCoordinator = nil
            self.goHome()
        }
    }
    
    private func setCurrentCoordinator(_ coordinator: Coordinator, hidesBottomBarWhenPushed: Bool, addAbortOnboardingButton: Bool) {
        var coordinator = coordinator
        coordinator.hidesBottomBarWhenPushed = hidesBottomBarWhenPushed
        if var pagedSectionCoordinator = coordinator as? PagedSectionCoordinator {
            pagedSectionCoordinator.addAbortOnboardingButton = addAbortOnboardingButton
        }
        self.currentCoordinator = coordinator
    }
    
    // MARK: Consent
    
    public func showReviewConsent(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getConsentSection(),
                                                hidesBottomBarWhenPushed: true,
                                                allowBackwardNavigation: true) { section -> UIViewController in
            let data = InfoPageListData(title: section.title,
                                        subtitle: section.subtitle,
                                        body: section.body,
                                        startingPage: section.welcomePage,
                                        pages: section.pages,
                                        mode: .view)
            return InfoPageListViewController(withData: data)
        }
    }
    
    // MARK: Integration
    
    public func showIntegrationLogin(loginUrl: URL, navigationController: UINavigationController) {
        let viewController = ReactiveAuthWebViewController(withTitle: "",
                                                           url: loginUrl,
                                                           allowBackwardNavigation: true,
                                                           onSuccessCallback: { _ in
                                                            navigationController.popViewController(animated: true)
                                                           },
                                                           onFailureCallback: { _ in
                                                            navigationController.popViewController(animated: true)
                                                           })
        navigationController.pushViewController(viewController,
                                                hidesBottomBarWhenPushed: true,
                                                animated: true)
    }
    
    // MARK: Home
    
    public func goHome() {
        let tabBarController = UITabBarController()
        
        // Basically, we want the content not to fall behind the tab bar
        tabBarController.tabBar.isTranslucent = false
        
        // Colors
        tabBarController.tabBar.setBackgroundColor(ColorPalette.color(withType: .secondary))
        tabBarController.tabBar.tintColor = ColorPalette.color(withType: .primaryText)
        tabBarController.tabBar.unselectedItemTintColor = ColorPalette.color(withType: .secondaryMenu)
        
        // Remove top line
        tabBarController.tabBar.barStyle = .black
        
        // Add shadow
        tabBarController.tabBar.addShadowLinear(goingDown: false)
        
        // Get tabs from configuration (or fallback to allCases)
        let tabs = StringsProvider.configuredMainTabs()
        
        var viewControllers: [UIViewController] = []
        
        let titleFont = FontPalette.fontStyleData(forStyle: .menu).font
        
        tabs.forEach { mainTab in
            let navController: UINavigationController

            switch mainTab {
            case .feed:
                let feedViewController = FeedViewController()
                navController = UINavigationController(rootViewController: feedViewController)
                navController.tabBarItem.image = ImagePalette.templateImage(withName: .tabFeed)
                navController.tabBarItem.title = StringsProvider.string(forKey: .tabFeed)
            case .task:
                let taskViewController = TaskViewController()
                navController = UINavigationController(rootViewController: taskViewController)
                navController.tabBarItem.image = ImagePalette.templateImage(withName: .tabTask)
                navController.tabBarItem.title = StringsProvider.string(forKey: .tabTask)
            case .diary:
                let diaryNoteViewController = DiaryNotesViewController(withDataPoint: nil, isFromChart: false)
                navController = UINavigationController(rootViewController: diaryNoteViewController)
                navController.tabBarItem.image = ImagePalette.templateImage(withName: .tabDiary)
                navController.tabBarItem.title = StringsProvider.string(forKey: .tabDiary)
            case .userData:
                let userDataViewController = UserDataViewController()
                navController = UINavigationController(rootViewController: userDataViewController)
                navController.tabBarItem.image = ImagePalette.templateImage(withName: .tabUserData)
                navController.tabBarItem.title = StringsProvider.string(forKey: .tabUserData)
            case .studyInfo:
                let studyInfoViewController = StudyInfoViewController()
                navController = UINavigationController(rootViewController: studyInfoViewController)
                navController.tabBarItem.image = ImagePalette.templateImage(withName: .tabStudyInfo)
                navController.tabBarItem.title = StringsProvider.string(forKey: .tabStudyInfo)
            }
            
            // Disable interactive swipe-back
            navController.preventPopWithSwipe()
            // Apply custom font to tab title
            navController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
            
            viewControllers.append(navController)
        }
        
        tabBarController.viewControllers = viewControllers
        if let defaultIndex = tabs.firstIndex(of: Self.defaultStartingTab) {
            tabBarController.selectedIndex = defaultIndex
        }
        self.window.rootViewController = tabBarController
    }
    
    public func switchToFeedTab(presenter: UIViewController) {
        guard let tabBarController = presenter.tabBarController else { return }
        guard let feedViewControllerIndex = tabBarController.viewControllers?.firstIndex(where: { viewController in
            (viewController as? UINavigationController)?.viewControllers.first is FeedViewController
        }) else { return }
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabFeed)))
        tabBarController.selectedIndex = feedViewControllerIndex
    }
    
    public func switchToDiaryTab(presenter: UIViewController) {
        let viewController = self.getTopMostViewController()
        guard let tabBarController = viewController?.tabBarController else { return }
        guard let viewControllerIndex = tabBarController.viewControllers?.firstIndex(where: { viewController in
            (viewController as? UINavigationController)?.viewControllers.first is DiaryNotesViewController
        }) else { return }
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabDiary)))
        tabBarController.selectedIndex = viewControllerIndex
    }
    
    // MARK: Task
    
    public func startFeedFlow(withFeed feed: Feed, presenter: UIViewController) {
        if let schedulable = feed.schedulable {
            switch schedulable {
            case .quickActivity:
                print("AppNavigator - No section should be started for the quick activities")
            case .activity(let activity):
                self.startTaskSection(withTask: feed,
                                      activity: activity,
                                      taskOptions: nil,
                                      presenter: presenter)
            case .survey(let survey):
                self.repository.getSurvey(surveyId: survey.id)
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] surveyGroup in
                        guard let self = self else { return }
                        self.startSurveySection(withTask: feed,
                                                surveyGroup: surveyGroup,
                                                presenter: presenter)
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.handleError(error: error, presenter: presenter)
                    }).disposed(by: self.disposeBag)
            }
        } else if let notifiable = feed.notifiable {
            let urlString: String? = {
                switch notifiable {
                case .educational(let educational): return educational.urlString
                case .alert(let alert): return alert.urlString
                case .reward(let reward): return reward.urlString
                }
            }()
            guard let notifiableUrl = urlString else {
                assertionFailure("AppNavigator - Missing notifiable url for given notifiable")
                return
            }
            self.handleNotifiableTile(data: feed,
                                      notifiableUrl: notifiableUrl,
                                      presenter: presenter,
                                      weHaveNoticed: false)
        } else {
            assertionFailure("Unhandle Type")
        }
    }
    
    public func startTaskSection(withTask task: Feed,
                                 activity: Activity,
                                 taskOptions: TaskOptions?, presenter: UIViewController) {
        
        assert(false == self.isTaskInProgress, "A task is already in progress")
        
        guard let taskType = activity.taskType else {
            assertionFailure("Missing task type for given activity")
            self.handleError(error: nil, presenter: presenter)
            return
        }
        let completionCallback: NotificationCallback = {
            presenter.dismiss(animated: true, completion: nil)
        }
        let coordinator: ActivitySectionCoordinator = {
            switch taskType {
            case .videoDiary:
                return VideoDiarySectionCoordinator(withTask: task,
                                                    activity: activity,
                                                    completionCallback: completionCallback)
            case .mirSpyrometer:
                return SpyrometerSectionCoordinator(withTask: task,
                                                    activity: activity,
                                                    completionCallback: completionCallback)
            case .reflectionActivity:
                return ReflectionSectionCoordinator(withTask: task,
                                                    activity: activity,
                                                    completionCallback: completionCallback)
            case .camcogEbt, .camcogNbx, .camcogPvt:
                return CamcogSectionCoordinator(withTask: task,
                                                activity: activity,
                                                completionCallback: completionCallback)
            default:
                return TaskSectionCoordinator(withTask: task,
                                              activity: activity,
                                              taskType: taskType,
                                              taskOptions: taskOptions,
                                              completionCallback: completionCallback)
            }
        }()
        self.analytics.track(event: .recordScreen(screenName: task.id,
                                                  screenClass: String(describing: type(of: self))))
        
        let startingPage = coordinator.getStartingPage()
        startingPage.modalPresentationStyle = .fullScreen
        presenter.present(startingPage, animated: true, completion: nil)
        self.currentActivityCoordinator = coordinator
    }
    
    public func startSurveySection(withTask task: Feed, surveyGroup: SurveyGroup, presenter: UIViewController) {
        
        assert(false == self.isTaskInProgress, "A task is already in progress")
        
        let completionCallback: NotificationCallback = {
            presenter.dismiss(animated: true, completion: nil)
        }
        
        let coordinator = SurveyGroupSectionCoordinator(withTask: task,
                                                        sectionData: surveyGroup,
                                                        completionCallback: completionCallback)
        let startingPage = coordinator.getStartingPage()
        startingPage.modalPresentationStyle = .fullScreen
        presenter.present(startingPage, animated: true, completion: nil)
        
        self.currentActivityCoordinator = coordinator
    }
    
    public func startWeHaveNoticedSection(data: Feed, presenter: UIViewController) {
        
        let completionCallback: NotificationCallback = { [weak presenter] in
            presenter?.dismiss(animated: true, completion: nil)
            self.currentCoordinator = nil
        }
        
        guard let alert = {
            if case let .alert(alert) = data.notifiable {
                return alert
            }
            return nil
        }() else {
            // Handle case where notifiable is not an alert
            return
        }
        // Instantiate the coordinator, passing the original presenter.
        let weHaveNoticedCoordinator = WeHaveNoticedCoordinator(
            repository: Services.shared.repository,
            navigator: self,
            taskIdentifier: data.id,
            presenter: presenter,
            feed: data,
            alert: alert,
            completion: completionCallback
        )
        
        self.currentCoordinator = weHaveNoticedCoordinator
        let startVC = weHaveNoticedCoordinator.getStartingPage()
        startVC.modalPresentationStyle = .fullScreen
        presenter.present(startVC, animated: true, completion: nil)
    }
    
    public func handleNotifiableTile(data: Feed, notifiableUrl: String?, presenter: UIViewController, weHaveNoticed: Bool) {
        if let notifiableUrl = notifiableUrl {
            if let internalDeeplinkKey = InternalDeeplinkKey(rawValue: notifiableUrl) {
                self.handleInternalDeeplink(withKey: internalDeeplinkKey, presenter: presenter)
            } else if let oAuthIntegration = IntegrationProvider.oAuthIntegration(withName: notifiableUrl) {
                self.openIntegrationApp(forIntegration: oAuthIntegration)
            } else if let url = URL(string: notifiableUrl) {
                self.openUrlOnBrowser(url, presenter: presenter)
            }
        } else if weHaveNoticed {
            self.startWeHaveNoticedSection(data: data, presenter: presenter)
        }
    }
    
    // MARK: User Data
    
    public func showUserDataFilter(presenter: UIViewController, userDataAggregationFilterData: [UserDataAggregationFilter]) {
        let viewController = UserDataFilterViewController(withUserDataAggregationFilterData: userDataAggregationFilterData)
        viewController.modalPresentationStyle = .fullScreen
        presenter.present(viewController, animated: true, completion: nil)
    }
    
    public func presentDiaryNotes(diaryNote: DiaryNoteItem?,
                                  presenter: UIViewController,
                                  isFromChart: Bool,
                                  animated: Bool = true) {
        let diaryVC = DiaryNotesViewController(withDataPoint: diaryNote,
                                               isFromChart: isFromChart)
        let navVC = UINavigationController(rootViewController: diaryVC)
        navVC.modalPresentationStyle = .formSheet
        navVC.preventPopWithSwipe()
        presenter.present(navVC, animated: animated)
    }
    
    public func openDiaryNoteText(diaryNote: DiaryNoteItem?,
                                  presenter: UIViewController,
                                  isEditMode: Bool,
                                  isFromChart: Bool) {
        let diaryNoteTextViewController = DiaryNoteTextViewController(withDataPoint: diaryNote,
                                                                      isEditMode: isEditMode,
                                                                      isFromChart: isFromChart,
                                                                      reflectionCoordinator: nil)
        diaryNoteTextViewController.modalPresentationStyle = .fullScreen
        if !isFromChart {
            presenter.dismiss(animated: true) {
                // Get the topmost view controller after dismissal
                guard let topViewController = self.getTopMostViewController() else {
                    assertionFailure("Unable to find a top-most view controller to present DiaryNoteTextViewController")
                    return
                }
                topViewController.present(diaryNoteTextViewController, animated: true, completion: nil)
            }
        } else {
            guard let navigationController = presenter.navigationController else {
                assertionFailure("Missing UINavigationController")
                return
            }
            navigationController.pushViewController(diaryNoteTextViewController,
                                                    hidesBottomBarWhenPushed: true,
                                                    animated: true)
        }
    }
    
    public func openDiaryNoteAudio(diaryNote: DiaryNoteItem?,
                                   presenter: UIViewController,
                                   isEditMode: Bool,
                                   isFromChart: Bool) {
        let diaryNoteAudioViewController = DiaryNoteAudioViewController(withDiaryNote: diaryNote,
                                                                        isEditMode: isEditMode,
                                                                        reflectionCoordinator: nil)
        diaryNoteAudioViewController.modalPresentationStyle = .fullScreen
        if !isFromChart {
            presenter.dismiss(animated: true) {
                guard let topViewController = self.getTopMostViewController() else {
                    assertionFailure("Unable to find a top-most view controller to present DiaryNoteTextViewController")
                    return
                }
                topViewController.present(diaryNoteAudioViewController, animated: true, completion: nil)
            }
        } else {
            guard let navigationController = presenter.navigationController else {
                assertionFailure("Missing UINavigationController")
                return
            }
            navigationController.pushViewController(diaryNoteAudioViewController,
                                                    hidesBottomBarWhenPushed: true,
                                                    animated: true)
        }
    }
    
    public func openDiaryNoteVideo(diaryNote: DiaryNoteItem?,
                                   isEdit: Bool,
                                   presenter: UIViewController,
                                   isFromChart: Bool) {
        let diaryNoteVideoViewController = DiaryNoteVideoViewController(diaryNoteItem: diaryNote,
                                                                        isEdit: isEdit,
                                                                        reflectionCoordinator: nil)
        diaryNoteVideoViewController.modalPresentationStyle = .fullScreen
        if !isFromChart {
            presenter.dismiss(animated: true) {
                guard let topViewController = self.getTopMostViewController() else {
                    assertionFailure("Unable to find a top-most view controller to present DiaryNoteTextViewController")
                    return
                }
                topViewController.present(diaryNoteVideoViewController, animated: true, completion: nil)
            }
        } else {
            guard let navigationController = presenter.navigationController else {
                assertionFailure("Missing UINavigationController")
                return
            }
            navigationController.pushViewController(diaryNoteVideoViewController,
                                                    hidesBottomBarWhenPushed: true,
                                                    animated: true)
        }
    }
    
    public func openNoticedViewController(presenter: UIViewController) {
        let noticedViewController = NoticedViewController()
        noticedViewController.modalPresentationStyle = .formSheet
        presenter.present(noticedViewController, animated: true)
    }
    
    public func openEatenViewController(presenter: UIViewController) {
        // Prevent overlapping flows
        assert(self.currentActivityCoordinator == nil, "Another activity is already in progress")

        // Completion callback: dismiss modal and clear current coordinator
        let completion: NotificationCallback = { [weak self, weak presenter] in
            presenter?.dismiss(animated: true, completion: nil)
            self?.currentActivityCoordinator = nil
        }

        // Instantiate the FoodEntryCoordinator
        let coordinator = FoodEntryCoordinator(
            repository: self.repository,
            navigator: self,
            taskIdentifier: "foodEntry",
            variant: .standalone,
            onDataCallback: {_, _, _, _ in},
            completion: completion
        )

        // Get the first view controller of the flow
        let startVC = coordinator.getStartingPage()
        startVC.modalPresentationStyle = .fullScreen

        // Present modally
        presenter.present(startVC, animated: true, completion: nil)

        // Hold a strong reference so we can dismiss later
        self.currentActivityCoordinator = coordinator
    }
    
    public func openMyDosesViewController(presenter: UIViewController) {
        // Prevent overlapping flows
        assert(self.currentActivityCoordinator == nil, "Another activity is already in progress")

        // Completion callback: dismiss modal and clear current coordinator
        let completion: NotificationCallback = { [weak self, weak presenter] in
            presenter?.dismiss(animated: true, completion: nil)
            self?.currentActivityCoordinator = nil
        }

        // Instantiate the Insulin Coordinator
        let coordinator = InsulinEntryCoordinator(
            repository: self.repository,
            navigator: self,
            variant: .standalone,
            taskIdentifier: "insulinEntry",
            onData: {_, _, _ in },
            completion: completion
        )

        // Get the first view controller of the flow
        let startVC = coordinator.getStartingPage()
        startVC.modalPresentationStyle = .fullScreen

        // Present modally
        presenter.present(startVC, animated: true, completion: nil)

        // Hold a strong reference so we can dismiss later
        self.currentActivityCoordinator = coordinator
    }
    
    public func openEatenFormViewController(presenter: UIViewController, foodItem: DiaryNoteItem) {

        let vc = EatenEntryFormViewController()
        // Get the first view controller of the flow
        vc.modalPresentationStyle = .fullScreen
        vc.configure(with: foodItem)
        
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(vc,
                                                hidesBottomBarWhenPushed: true,
                                                animated: true)
    }
    
    public func openDosesFormViewController(presenter: UIViewController, dosesItem: DiaryNoteItem) {

        let vc = DosesEntryFormViewController()
        // Get the first view controller of the flow
        vc.modalPresentationStyle = .fullScreen
        vc.configure(with: dosesItem)
        
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(vc,
                                                hidesBottomBarWhenPushed: true,
                                                animated: true)
    }
    
    public func openNoticedFormViewController(presenter: UIViewController, noticedItem: DiaryNoteItem) {

        let vc = WeHaveNoticedEntryFormViewController()
        // Get the first view controller of the flow
        vc.modalPresentationStyle = .fullScreen
        vc.configure(with: noticedItem)
        
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(vc,
                                                hidesBottomBarWhenPushed: true,
                                                animated: true)
    }
    
    // MARK: About You
    
    public func showAboutYouPage(presenter: UIViewController) {
        let aboutYouViewController = AboutYouViewController()
        let navigationController = UINavigationController(rootViewController: aboutYouViewController)
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true, completion: nil)
    }
    
    public func showAppsAndDevices(navigationController: UINavigationController, title: String) {
        let devicesViewController = DevicesIntegrationViewController(withTitle: title)
        navigationController.pushViewController(devicesViewController, animated: true)
    }
    
    public func showPreferences(navigationController: UINavigationController, title: String) {
        let devicesViewController = PreferencesViewController(withTitle: title)
        navigationController.pushViewController(devicesViewController, animated: true)
    }
    
    public func showUserInfoPage(navigationController: UINavigationController,
                                 title: String,
                                 userInfoParameters: [UserInfoParameter]) {
        let userInfoViewController = UserInfoViewController(withTitle: title, userInfoParameters: userInfoParameters)
        navigationController.pushViewController(userInfoViewController, animated: true)
    }
    
    public func showPermissions(navigationController: UINavigationController, title: String) {
        let permissionViewController = PermissionViewController(withTitle: title)
        navigationController.pushViewController(permissionViewController, animated: true)
    }
    
    public func showSurveySchedule(navigationController: UINavigationController, title: String) {
        let permissionViewController = SurveyScheduleViewController(withTitle: title)
        navigationController.pushViewController(permissionViewController, animated: true)
    }
    
    public func showSwitchPhaseAlert(presenter: UIViewController) {
        let cancelAction = UIAlertAction(title: StringsProvider.string(forKey: .phaseSwitchButtonCancel), style: .cancel, handler: nil)
        let confirmAction = UIAlertAction(title: StringsProvider.string(forKey: .phaseSwitchButtonConfirm), style: .default, handler: { _ in
            self.openStudyInfoPage(studyInfoPage: .faq, presenter: presenter)
        })
        
        presenter.showAlert(withTitle: StringsProvider.string(forKey: .genericInfoTitle),
                            message: StringsProvider.string(forKey: .phaseSwitchMessage),
                            actions: [cancelAction, confirmAction],
                            tintColor: ColorPalette.color(withType: .primary))
    }
    
    public func openMessagePage(withLocation location: MessageInfoParameter, presenter: UIViewController) {
        let messageViewController = MessagesViewController(withLocation: location)
        messageViewController.modalPresentationStyle = .formSheet
        presenter.present(messageViewController, animated: true)
    }
    
    // MARK: Progress HUD
    
    public static func pushProgressHUD() {
        if self.progressHudCount == 0 {
            SVProgressHUD.show()
        }
        self.progressHudCount += 1
    }
    
    public static func popProgressHUD() {
        if self.progressHudCount > 0 {
            self.progressHudCount -= 1
            if self.progressHudCount == 0 {
                SVProgressHUD.dismiss()
            }
        } else {
            print("AppNavigator - Attempted hud progress pop when progressHudCount is 0")
        }
    }
    
    // MARK: - Misc
    
    public func logOut() {
        self.repository.logOut()
        self.goToWelcome()
    }
    
    public func canOpenExternalUrl(_ url: URL) -> Bool {
        return UIApplication.shared.canOpenURL(url)
    }
    
    public func openSettings() {
        if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
        }
    }
    
    public func openExternalUrl(_ url: URL) {
        guard self.canOpenExternalUrl(url) else {
            print("Cannot open given url: \(url)")
            return
        }
        UIApplication.shared.open(url)
    }
    
    public func openUrlOnBrowser(_ url: URL, presenter: UIViewController) {
        guard self.canOpenExternalUrl(url) else {
            print("Cannot open given url: \(url)")
            return
        }
        let viewController = SFSafariViewController(url: url)
        viewController.preferredControlTintColor = ColorPalette.color(withType: .primaryText)
        viewController.preferredBarTintColor = ColorPalette.color(withType: .secondary)
        presenter.present(viewController, animated: true, completion: nil)
    }
    
    public func openIntegrationApp(forIntegration intergration: Integration) {
        if self.canOpenExternalUrl(intergration.appSchemaUrl) {
            self.openExternalUrl(intergration.appSchemaUrl)
        } else {
            self.openExternalUrl(intergration.storeUrl)
        }
    }
    
    public func openWebView(withTitle title: String,
                            url: URL,
                            presenter: UIViewController,
                            configuration: WKWebViewConfiguration?) {
        let webViewViewController = WebViewViewController(withTitle: title,
                                                          allowNavigation: true,
                                                          url: url,
                                                          htmlString: nil,
                                                          webViewConfiguration: configuration ?? WKWebViewConfiguration())
        let navigationViewController = UINavigationController(rootViewController: webViewViewController)
        navigationViewController.preventPopWithSwipe()
        webViewViewController.onFabActionSelected = { [weak self] action in
            guard let self = self else { return }
            
            switch action {
            case .insulin:
                self.openMyDosesViewController(presenter: presenter)
            case .noticed:
                self.openNoticedViewController(presenter: presenter)
            case .eaten:
                self.openEatenViewController(presenter: presenter)
            }
        }
        presenter.present(navigationViewController, animated: true)
    }
    
    public func handleError(error: Error?,
                            presenter: UIViewController,
                            onDismiss: @escaping NotificationCallback = {},
                            onRetry: NotificationCallback? = nil,
                            dismissStyle: UIAlertAction.Style = .cancel) {
        SVProgressHUD.dismiss() // Safety dismiss
        guard let error = error else {
            presenter.showAlert(forError: nil, onDismiss: onDismiss, onRetry: onRetry, dismissStyle: dismissStyle)
            return
        }
        guard let alertError = error as? AlertError else {
            assertionFailure("Unexpected error type")
            presenter.showAlert(forError: nil, onDismiss: onDismiss, onRetry: onRetry, dismissStyle: dismissStyle)
            return
        }
        
        if false == self.handleUserNotLoggedError(error: error) {
            presenter.showAlert(forError: alertError, onDismiss: onDismiss, onRetry: onRetry, dismissStyle: dismissStyle)
        }
    }
    
    /// Check if the given error is a `Repository.userNotLoggedIn` error and, if so,
    /// perform a logout procedure.
    /// - Parameter error: the error to be checked
    /// - Returns: `true` if logout has been performed. `false` otherwise.
    public func handleUserNotLoggedError(error: Error?) -> Bool {
        if let error = error, case RepositoryError.userNotLoggedIn = error {
            print("Log out due to 'RepositoryError.userNotLoggedIn' error")
            self.logOut()
            return true
        } else {
            return false
        }
    }
    
    public func checkForNotificationPermission(presenter: UIViewController) {
        
        guard self.pushPermissionCompleted == false else {
            return
        }
        
        let notificationPermission: Permission = .notification
        let notificationStatus: Bool = notificationPermission.isNotDetermined
        notificationPermission.request().subscribe(onSuccess: { [weak self] _ in
            self?.pushPermissionCompleted = true
            if notificationPermission.isDenied, notificationStatus == false {
                self?.showPermissionDeniedAlert(presenter: presenter)
            }
        }, onFailure: { [weak self] error in
            self?.handleError(error: error, presenter: presenter)
        }).disposed(by: self.disposeBag)
        
    }
    
    public func showPermissionDeniedAlert(presenter: UIViewController) {
        
        let cancelAction = UIAlertAction(title: StringsProvider.string(forKey: .permissionCancel), style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: StringsProvider.string(forKey: .permissionSettings), style: .default, handler: { _ in
            PermissionsOpener.openSettings()
        })
        
        presenter.showAlert(withTitle: StringsProvider.string(forKey: .permissionDeniedTitle),
                            message: StringsProvider.string(forKey: .permissionMessage),
                            actions: [cancelAction, settingsAction])
    }
    
    public func showHealthPermissionSettingsAlert(presenter: UIViewController) {
        
        let cancelAction = UIAlertAction(title: StringsProvider.string(forKey: .permissionCancel), style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: StringsProvider.string(forKey: .permissionSettings), style: .default, handler: { _ in
            self.openSettings()
        })
        
        presenter.showAlert(withTitle: StringsProvider.string(forKey: .permissionHealthSettingsTitle),
                            message: StringsProvider.string(forKey: .permissionHealthSettingsMessage),
                            actions: [cancelAction, settingsAction])
    }
    
    // Helper function to get the top-most view controller
    private func getTopMostViewController() -> UIViewController? {
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            return nil
        }
        return findTopViewController(from: rootViewController)
    }

    // Recursive function to traverse presented view controllers
    private func findTopViewController(from rootViewController: UIViewController) -> UIViewController {
        if let presentedViewController = rootViewController.presentedViewController {
            return findTopViewController(from: presentedViewController)
        }
        if let navigationController = rootViewController as? UINavigationController {
            return navigationController.visibleViewController ?? navigationController
        }
        if let tabBarController = rootViewController as? UITabBarController {
            return tabBarController.selectedViewController ?? tabBarController
        }
        return rootViewController
    }
    
    // MARK: - Study Info
    
    public func showInfoDetailPage(presenter: UIViewController, page: Page, isModal: Bool) {
        let pageData = InfoDetailPageData(page: page, isModal: isModal)
        let viewController = InfoDetailPageViewController(withPageData: pageData)
        if isModal {
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.modalPresentationStyle = .fullScreen
            presenter.present(navigationController, animated: true, completion: nil)
        } else {
            guard let navController = presenter.navigationController else {
                assertionFailure("Missing UINavigationController")
                return
            }
            navController.pushViewController(viewController,
                                             hidesBottomBarWhenPushed: true,
                                             animated: true)
        }
    }
    
    // MARK: - Internal deeplink
    
    private func handleInternalDeeplink(withKey key: InternalDeeplinkKey, presenter: UIViewController) {
        switch key {
        case .feed: self.goToMainTab(tab: .feed, presenter: presenter)
        case .task: self.goToMainTab(tab: .task, presenter: presenter)
        case .diary: self.goToMainTab(tab: .diary, presenter: presenter)
        case .userData: self.goToMainTab(tab: .userData, presenter: presenter)
        case .studyInfo: self.goToMainTab(tab: .studyInfo, presenter: presenter)
        case .aboutYou: self.showAboutYouPage(presenter: presenter)
        case .faq: self.openStudyInfoPage(studyInfoPage: .faq, presenter: presenter)
        case .rewards: self.openStudyInfoPage(studyInfoPage: .reward, presenter: presenter)
        case .contacts: self.openStudyInfoPage(studyInfoPage: .contacts, presenter: presenter)
        case .consent: self.openConsent(presenter: presenter)
        }
    }
    
    private func goToMainTab(tab: MainTab, presenter: UIViewController) {
        // Try to get the UITabBarController from the presenter
        guard let tabBarController = presenter.tabBarController else {
            assertionFailure("AppNavigator - Missing UITabBarController on presenter")
            return
        }
        // Ensure the viewControllers array is available
        guard let controllers = tabBarController.viewControllers else {
            assertionFailure("AppNavigator - UITabBarController.viewControllers is nil")
            return
        }
        let index = tab.rawValue
        // Ensure the index is within the valid range
        guard index >= 0 && index < controllers.count else {
            assertionFailure("AppNavigator - Invalid tab index \(index); valid range is 0...\(controllers.count - 1)")
            return
        }
        // All good – switch to the desired tab
        tabBarController.selectedIndex = index
    }
    
    private func openStudyInfoPage(studyInfoPage: StudyInfoPage, presenter: UIViewController) {
        self.repository.getStudyInfoSection()
            .addProgress()
            .subscribe(onSuccess: { [weak self] section in
                guard let self = self else { return }
                let page: Page? = {
                    switch studyInfoPage {
                    case .faq: return section.faqPage
                    case .reward: return section.rewardPage
                    case .contacts: return section.contactsPage
                    }
                }()
                guard let unwrappedPage = page else { return }
                self.showInfoDetailPage(presenter: presenter, page: unwrappedPage, isModal: true)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.handleError(error: error, presenter: presenter)
            }).disposed(by: self.disposeBag)
    }
    
    private func openConsent(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing Navigation Controller")
            return
        }
        
        let sectionDriver = OnboardingSectionDriver(onboardingSectionGroups: [.consent])
        if let firstSection = sectionDriver.firstOnboardingSection {
            self.startOnboardingSection(section: firstSection,
                                        sectionDriver: sectionDriver,
                                        navigationController: navigationController,
                                        hidesBottomBarWhenPushed: true,
                                        addAbortOnboardingButton: false)
        } else {
            assertionFailure("Missing first section for consent flow")
            self.handleError(error: nil, presenter: presenter)
        }
    }
}

// MARK: - DeeplinkManagerDelegate

extension AppNavigator: DeeplinkManagerDelegate {
    func handleDeeplink(_ deeplink: Deeplink) -> Bool {
        guard self.setupCompleted else {
            // If App Setup is still in progress, the deeplink
            // will be handled upon setup completion
            return false
        }
        
        guard self.repository.isLoggedIn, self.repository.currentUser?.isOnboardingCompleted ?? false else {
            // Currently no deeplink are expected to do anything if user is logged out or
            // has not completed the onboarding yet.
            return true
        }
        
        switch deeplink {
        case .openTask, .openUrl:
            if self.isTaskInProgress == false {
                self.goHome()
                return false
            }
        case .openIntegrationApp(let integrationName):
            if let oAuthIntegration = IntegrationProvider.oAuthIntegration(withName: integrationName) {
                self.openIntegrationApp(forIntegration: oAuthIntegration)
            }
        }
        return true
    }
}

// MARK: - Extension(UIViewController)

extension UIViewController {
    func showAlert(forError error: Error?,
                   onDismiss: @escaping NotificationCallback = {},
                   onRetry: NotificationCallback? = nil,
                   dismissStyle: UIAlertAction.Style = .cancel) {
        var actions: [UIAlertAction] = []
        let dismissAction = UIAlertAction(title: StringsProvider.string(forKey: .errorButtonClose),
                                          style: dismissStyle,
                                          handler: { _ in onDismiss() })
        actions.append(dismissAction)
        if let onRetry = onRetry {
            let retryAction = UIAlertAction(title: StringsProvider.string(forKey: .errorButtonRetry),
                                            style: .default,
                                            handler: { _ in onRetry() })
            actions.append(retryAction)
        }
        self.showAlert(withTitle: StringsProvider.string(forKey: .errorTitleDefault),
                       message: error?.localizedDescription ?? StringsProvider.string(forKey: .errorMessageDefault),
                       actions: actions,
                       tintColor: ColorPalette.color(withType: .primary))
    }
    
    func showAlert(withTitle title: String,
                   message: String,
                   dismissButtonText: String,
                   onDismiss: @escaping NotificationCallback = {}) {
        let dismissAction = UIAlertAction(title: dismissButtonText,
                                          style: .default,
                                          handler: { _ in onDismiss() })
        self.showAlert(withTitle: title,
                       message: message,
                       actions: [dismissAction],
                       tintColor: ColorPalette.color(withType: .primary))
    }
}

extension PrimitiveSequence where Trait == SingleTrait {
    /// Add a progress view to the calling single, showing it on subscribe and hiding it upon success, error or dispose.
    /// NOTE: call this after the single object that should be covered by the progress view
    /// (tipically before the call to the subscribe method)
    func addProgress() -> Single<Element> {
        self.do(onSubscribe: { AppNavigator.pushProgressHUD() },
                onDispose: { AppNavigator.popProgressHUD() })
    }
}

extension Observable {
    /// Add a progress view to the calling observer, showing it on subscribe and hiding it upon success, error or dispose.
    /// NOTE: call this after the single observer that should be covered by the progress view
    /// (tipically before the call to the subscribe method)
    func addProgress() -> Observable<Element> {
        self.do(onSubscribe: { AppNavigator.pushProgressHUD() },
                onDispose: { AppNavigator.popProgressHUD() })
    }
}

// MARK: - Extension(UITabBar)

fileprivate extension UITabBar {
    func setBackgroundColor(_ color: UIColor) {
        self.barTintColor = color
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
            
            self.standardAppearance = appearance
            self.scrollEdgeAppearance = appearance
        }
    }
}

extension MainTab {
    init?(configKey: String) {
        switch configKey.lowercased() {
        case "feed":
            self = .feed
        case "task":
            self = .task
        case "log", "diary":
            self = .diary
        case "compass", "userdata":
            self = .userData
        case "settings", "studyinfo":
            self = .studyInfo
        default:
            return nil
        }
    }
}
