
## Release 0.62.0

- App version label added

## Release 0.61.0

- Custom Daily Survey timing page title width fixed

- Margin for Generic Button in Daily Survey Schedule fixed

- Pods for M1 build fixed

- Anchor button Survey schedule fixed

##  Release 0.60.0

-Bugfix: Fixed texts in Permission page.

##  Release 0.59.0

-Bugfix: TimeZone missing on reward tiles

##  Release 0.58.0

-Bugfix: TimeZone missing on reward tiles

##  Release 0.57.0

-Avoid stand-by phone when video diary is recording

##  Release 0.56.0

-Add network logic for daily survey schedule

-Bugfix: missing number of peg step

-Daily Survey Timing function added

-Add creation and result handle for hole peg task

-Hole Peg task added

##  Release 0.55.0

-Deauthorize label color changed

## Release 0.54.0

-Bugfix: skip logic after is_other option issue

## Release 0.53.0

-Pick one and Pick Many Other option add

## Release 0.52.0

-Pin code suffix added on PIN login mode

## Release 0.51.0

-Bugfix:"{{rewarderd_at}}" wrong label parsing

## Release 0.50.0

-Bugfix: "None Option" issue on survey

-Pod updated to current version

-Pin code login added

-None option on survey added

## Release 0.49.0

-Keywords in feed reward title replaced during parsing. 

-Pod dependency from Japx/RxCodableMoya with BLZJapx/RxCodableMoya (this fork allow parsing of meta) replaced. 

-Pods Replaced.

## Release 0.48.0

-About You section: conditioned visibility of the review consent section based on the existance of the same section in the onboarding.

-Opt-in onboarding section as a standalone section group added.

-User Consent API: encoding logic for optional parameters updated (not sent instead of null if missing).

-Onboarding completed notification sending to server.

## Release 0.47.0

-DeviceManager: added a timer after which phone events are sent anyway the location update.

-File size limit added to Video Diary exported video files.

-AddProgress() logic

-Relative location tracked on phone events.

## Release 0.46.0

-Bugfix: Quick Activities current page number issue.

## Release 0.45.0

-FIxed coding-style issues.

-BatchEventUpload - fixed racing conditions on uploadBuffers calls.

-Updated default walk time and rest time for fitness task.

-Phone Events - Added location permission data. Separated wifi not connected from unknown state. Improved logic on location permissions change.

## Release 0.44.0

-Request for phone events

-Phone events sending.

-Survey Question Pick Many - added support for multi-line text in answer labels.

## Release 0.43.0

-Updated FYAMResearchKit to version 3.0.0. Removed link to HealthKit framework and removed related privacy usage descriptions from info.plist.

-Made welcome page optional for SurveyTask entities (survey block). Fixed code styling issues.

-Fixed progress view show/hide logic for Opt-In permissions choices.

## Release 0.42.0

-Forced dependency from PhoneNumberKit pod version 3.3.1 due to issue in version 3.3.3..

## Release 0.41.0

-HealthKit import removed.

## Release 0.40.0

-HealthKit permission removed.

## Release 0.39.0

-Added push notification permission request on welcome screen too.

## Release 0.38.0

-Deauthorize page added

-Deauthorize Instagram page added

## Release 0.37.0

-Relative Location Permission added

-Bugfix: Max/Min display aren't showing on range question type

-Bugfix: App should always prompt to allow push notifications

-Gender and name from Your Pregnancy Page removed

## Release 0.36.0

-Logic for quickActivity page indicator changed

## Release 0.35.0

-Quick activities - disabled horizontal scroll.

-Changed submit button text for all quick activities except for the last one

## Release 0.34.0

-Handled missing success and failure pages in onboarding sections.

## Release 0.33.0

-Fixed test target build settings

## Release 0.32.0

-Updated pods. Handled custom texts for ResearchKit tasks. Updated Firebase Messaging delegate method.

-Removed unnecessary Firebase Messaging Auto Init delay.

-Push Notifications - added push notifications as SystemPermission, so that the corresponding permission could be asked in the Opt-In section.

-Survey - ignored matching target with question id pointing to a previous question.

-LoadingTableViewCell - Added custom color to activity indicator.

-completed feed and tasks pagination. Added items merging and fixed page index calculation.

-Adding pagination in feeds and tasks (WIP, missing section merge and test).

-Updated query parameters for feeds and tasks API requests.

-Added pagination info in tasks and feeds API requests.

-Fixed Test target compilation error. Enabled testability for ForYouAndMe pod on release builds.

## Release 0.31.0

-Update azure-pipelines.yml for Azure Pipelines

## Release 0.30.0

-User Data Name page - added body.

-Feed cells: fixed background color animation on cell reload. Restored start/end color usage, if provided.

## Release 0.29.0

-Fixed uri schema to garmin app.

-Fixed rotation issues by changing rotation handling architecture.

-Added Analytics debug log.

-Dynamically managed onboarding sections.

-Grouped onboarding sections in section groups. Updated OnboardingSectionProvider accordingly and added tests.

-Parsed list of onboarding sections from GlobalConfig strings. Embedded IntroViewController in dedicated coordinator.

-Survey text input: added keyboard toolbar with done button to dismiss the keyboard.

-Survey questions - removed header image space if image is not provided.

-Removed replaced close button image usages with its tamplate version.

-Your Data - fixed quick activities Y mapping. Changed line draw mode.

## Release 0.28.0

-Fix markdown visualization

## Release 0.27.0

-Integration section - fixed wrong page layout.

-Removed study video label from intro video page

-Your Data - Restored chart line dots appearance.

-Your Data - added mock data. Smoothed lines for monthly and yearly charts. Added dots to line for the weekly chart.

## Release 0.26.0

-Your Data - handled different x label array sizes.

-Sent timezone identifier to server instead of abbreviation timezone

-Fixed wrong ouath base url

-Your Data - removed dots from chart lines

## Release 0.25.0

-Moved secrets to plist file outside version control.

## Release 0.24.0

-Suvery Questions: Handled possible invalid targets structure and possible invalid target items. Also fixed other parsing liabilities

-Improved SVProgressHUD show and dismiss logic.

-Added ActivitySectionViewController class to persist activity coordinators and updated section coordinators life cycle logic. Changed Firebase log level to minimum.

-Survey questions - Applied scrolling on the whole page.

## Release 0.23.0

-Fix rotation bug

-Fix rotation bug

## Release 0.22.0. 

-Migration to https://github.com/4youandme/4YouandmeiOS.

-Updated available integrations source.


-Updated Remind Me Later logic.

-Push Token - Update architecture and cache logic according to Firebase doc.

-Removed unused strings and images.

-Added welcome and success pages to SurveyGroupSectionCoordinator.

-Added pages to Activity and SurveyGroup entities. Abstracted paged navigation for activities in PagedActivitySectionCoordinator protocol and used it for VideoDiary, ResearchKit tasks and Camcog. Handled multiple actions in deeplink payload.

-Add Firebase Token to user

-Fix label position in scale range

-Added splash screen in example project.

-Added internal deeplink to study info sections.

-Refactored Rewards class in Reward. Fixed missing parsing of link_url in Alert and Reward entities. Added default button texts for notifiable feeds.

-Allow to open integration apps through deeplinks. Refactored deeplink-related classes. Refactored IntegrationLoginViewController in more generic ReactiveAuthWebViewController.

-Fix missing time zone update after login. Ignored time zone update error to avoid blocking more important operations.

## Release 0.21.0

-Error Handling fix

## Release 0.20.0

-Overlay View Removed

-Internal deeplink - added internal deeplink to main tabs and to about you page.

-Deeplink - fixed and completed deeplink handling.

-Handle Deeplink at launch

-Handle DeepLink from FeedViewController

-Survey - updated validation logic.

-Survey - Updated entity parsing. Updated skip login and entities for pick-one and pick-many question types. Added survey validation. General refactor.

-Survey - updated result sending structure and API call.

-Study Info: handled missing study info pages.

-Added user timezone update on user refresh. Added user refresh on pull to refresh in FeedViewController.

-Added success page to Camcog tasks. Added missing mock data.

-Camcog - Disabled backward navigation in camcog task.

-Deeplink - prepared main deeplink architecture. Moved push notification code inside the framework.

-Added remind me later to survey. Abstracted remind me later behavior for all activities.

-Survey - Updated parsing of the main structure. Updated API call specs.

-Update Repo for Pod

-Update azure-pipelines.yml for Azure Pipelines

## Release 0.19.0

-Added podspec workaround for Xcode build architecture management.


## Release 0.18.0

-Handle Alert, Rewards and Educational logic

-Move logic for Rewards, Alert and Educational Feed in Notifiable property wrapper

-Add Deeplink Service

-Fix item dimension

-Add end color to gradient view

-Add card color to feed tile

-Errors bugfixes

-Handle Info tile interaction

-Fix Rotation on whole application

-Added custom success page to ResearchKit tasts.

-Camcog - Added remind me later.

-Fixed UserInfoParameter date coding strategy.

-Video Diary - Added remind me later.

-Tasks - Added Remind Me Later button and API call

-Tasks - Added welcome page to tasks. Devices - Added UI refresh on viewWillAppear. Fixed layout issue in DeviceItemView.

-Camcog configuration complete

-Study Info images and views

-Add StudyInfo api integration

-Fixed blocking navigation in review consent in case of network error. Applied network first logic in user refresh in Feed.

-Replaced overFullScreen occurrencies with fullScreen (to trigger viewWillAppear correctly). Fixed Feed header time computation. Corrected code style.

-Disabled strings and color checks on Release builds.

-Fixed line spacing in html content.

-Reverted string key for User Info title.

-Integration - Added list of available integrations per study and used to show it in Devices page.

-Integrations: refactored Wearable occurrencies into Integration. Added all available integrations.

-Updated user sending protocol. Updated Feed header with user info.

-Feed: removed notification button

-User Info - added temporary hardcoded user info parameters for bump project. Refactored non-generic code.

-Stubs removed from network

-Video rotation complete

-Handle rotation

-Removed unused DTCoreText pod dependency. Fixed code style warnings.

-Data visualization improved

-Set axis dependencies

-Fix xlabels on axis

-Fix Label on xAxis

-Set axis dependencies

-Removed user location request from currently expected ResearchKit tasks

-Fix xlabels on axis



## Release 0.17.0

-Fix Label on xAxis



## Release 0.17.0

-range of month visualization changed

-Fix Oauth Wearables

-Name of TextView changed

-Html string added

-Html string added

-DTCoreText dependency added

-Your Data - Progress setting charts data.

-Range of month visualization changed

-Name of TextView changed

-Html string added

-Your Data - Progress setting charts data.

-Range of month visualization changed

-Oauth Wearables fixed

-Name of TextView changed

-Html string added

-DTCoreText dependency added

-Your Data - Progress setting charts data.

-Html string added

-Range of month visualization changed

-Day from study Period removed

-Name of TextView changed

-Html label added to other pages

-Html string added

-DTCoreText dependency added

-Your Data - Progress setting charts data.

-Syntax fixed

-Oauth handled


-Icon for wearables added

-Range of month visualization changed

-Name of TextView changed

-Html label to other pages added

-Html string added

-Your Data - Progress setting charts data.

-Name of TextView changed

-Html label added to other pages

-Test stuff removed

-Html string added

-Range of month visualization changed

-Name of TextView changed

-Html label to other pages added

-Html string added

-Your Data - Progress setting charts data.

-Range of month visualization changed

-Day removed from study Period

-Your Data - Progress setting charts data.

-Range of month visualization changed

-Day removed from study Period

-Name of TextView changed

-Html label added to other pages


## Release iOS 0.16.0

-Test stuff removed

-Html string added

-DTCoreText dependency added

-Name of TextView changed

-Html label to other pages added



## Release iOS 0.16.0

-Test stuff removed

-Html string added

-DTCoreText dependency added

-Your Data - Progress setting charts data.

-Handled errors on user data aggration fetch calls.

-Created dedicated GenericErrorView class out of the LoadingViewController error view. Applied GenericErrorView as generic fetch error view of all tabs. Updated UserData fetch logic.

-Your Data: shown UserData in page header. Updated network fetch logic.

-Created UserData and UserDataAggregation entities and Implemented related API calls.

-User Data: updated period segment control layout.

-User status managament - Updated User decoding and get user API.

-Push notification added to the project

-User status management - Implemented get user API call. Handled startup and login flow cases based on the onboarding completion state.

-Survey: updated pick one radio button tint color.

-Pods updated

-Updated existing Firebase pods from 6.25.0 to 6.33.0. Added Firebase Messaging pod.

-Survey - fixed enable state of the confirm buttons.

-ResearchKit tasks: replaced hardcoded step identifiers with newly available public constants from ResearchKit pod.

-ResearchKit customization: updated FYAMResearchKit to version 2.2.0. Customized task colors with ColorPalette values. Rounded next buttons and added shadow.

-Selection of answers in Pick Many questions improved

-Delegate for update answers added

-Scale Slider added

-Range question added

-Temporary Slider added

-Survey - Fixed double push after text-input and date-input question types.

-Survey - Updated value types for scale and range question types

-Survey Question Date picker

-UI Survey Text Input fixed

-Text input with textview instead of textfield

-Survey Question Text Input added

-Survey Question Pick Many layout added

-PickOne question added

-Picker Customization added

-Minimum and maximum display label handled

-Numerical Picker View for Survey added

-Survey - Added skip logic.

-Survey - Added step count in survey navigation bar.

-Survey - Added main navigation architecture.

-Sintax warning fixed

-VideoDiary actions added

-Notification and location changed permission added

-Your Data selection period tracked

-Switch tab tracked

-Connect, Allow and Allowed strings from configurator added

-Warning fixed

-Quick activity tracking added

-Event when user cancel onboarding added

-Analytics event name and parameters added

-CacheService and set Firebase UserID and DeviceID added

-Analytics event name and SetUserID added

-New events tracked

-Feed api added

-Analytics added

-Analytics added

-Survey - Added model and API calls to get a survey and to send answers.

-Updated Consent appearance when viewed in profile (removed title and subtitle; changed navigation bar style).

-Offset on Date Selector fixed

-Star Rating View added

-Period selection added

-Format String and positioning fixed

-Style to graph data added

-About You Item added

-Bug on reload fixed

-Fixed date picker on iOS 14.

-Firebase Analytics architecture setup.



## Release iOS 0.15.0

-Missing Permission added



## Release 0.14.0

-Feed page on open setted

-Location Permission added and Location Service removed

-String with Permission denied text updated

-Refresh status on user permission action added

-Strings for About You and Study Info main pages added

-Permission status for restricted and not determined added, Open Settings when permission is denied

-Permission Class added

-Permissions views added

-Intro video added

-Video Diary: handled recording error.

-Fixed issues in DatePickerHandler. Refactored DataPickerHandler and DatePickerHandler. Prepared API call to update user info parameters.

-User Info: added date picker. Removed cursor from data picker. Improved keyboard dismiss logic. Improved structure.

-User Info: added item picker. Dimissed keyboard when scrolling.

-User Info: added text fields UI and edit logic.

-Added UserInfoViewController. Created header and navigation bar with state handling. Wired navigation with mock data.

-Name of template image changed

-Permission icon crash fixed

-Permission icon changed

-Disabled Image and connect login added to DeviceItem

-Wearable Integration added

-Your Apps and devices Header added

-Review Consent Section added

-About You Page and logic added

-Icon added

-Info Detail View Controller added

-Name refactoring

-Show Info detail page from study info added

-Gesture added on list item view

-Generic Item List added

-Image asset added

-Prepared layout and navigation to show the device integration login page from profile.

-Prepared review consent for presentation from the profile page.

-Fixed not working flash light during video diary recording. Added flags to exclude global config validation.

-Feed: added scrolling header

-Feed: added static header view.

-Page: added new modal link properties. Created InfoDetailViewController and used to show modal link pages.

-Added Fitness Task

-Video Diary: updated and activated actual upload. Added discard button in record state.


## Release 0.13.0

-Your Data: added Charts pod. Added mocked charts.

-Your Data: added base UI structure.

-Attachment upload strategy updated

-Video Diary - Restored demo send result method.

-Video Diary: refactor

-Video Diary: timed pause button appearence during play states.

-Video Diary: added overlay in non-playback state.

-Video Diary: handled foreground - background transitions.

-Video Diary: handled errors and permissions.

-Video Diary: sent video to server

-Video diary: fixed behavior on recording till the time limit.

-Video Diary: increased record time precision. Fixed shown record duration in review state.

-Video diary: player slider thumb is always shown (previous auto-hide feature has been flagged out).

-Video diary: enabled interaction on player view (needed to show slider thumb).

-Video Diary: added confirm popup before dicarding video.

-Video Diary: added player.

-Video Diary: added video recording.

-Video Diary: completed UI.

-Video Diary: creating UI (WIP)

-Video Diary: created navigation architecture. Added intro and success pages.


## Release 0.12.0

-Quick activities: fixed default page number.

-Fixed swiftlint warnings and excluded type_body_length rule.

-Quick activities: sent result to server.

-Quick activities: fixed confirm button enabled state logic and UI. Handled option image of smaller size. Refined cell update upon selection.

-Added quick activity views and logic.

-Parsed survey (cell info only).

-Parsed quick activities

-Completed tasks parsing for activity type.

-Parsing tasks endpoint (WIP).

-Tasks: sent tremor task results

-Tasks: sent gait task results.

-Tasks: added optional form results from Walk test.

-Refactored alert presentation utility methods. Handled errors while sending tasks results.

-Tasks: sent Walk Task results.

-Task: sent Trail Making task results.

-Tasks: created architecture to generate tasks and to encode task results. Implemented API call to send task results. Implemented Reaction Time task results.

-Fixed tableviewheader header resize logic.



## Release 0.11.0

-Integration api refactoring



## Release 0.10.0

-Added missing Privacy items in info.plist file needed by ResearchKit tasks.




## Release 0.9.0

-Removed custom ResearchKit library as framework and added as a pod dependency (FYAMResearchKit).

-Started ResearchKit tasks through mock data in Tasks tab.

-Added ResearchKit fork as Framework. Added test versions of the required tasks.

-Added empty view in feed tab. Added headers and WIP placeholders in Your Data and Study Info sections.

-Created generic FeedListManager to handle both feed and tasks pages. Filled tab page with mock data.

-Created main tab bar and added empty view controllers for each tab.

-Updated phone number validation code status code.



## Release 0.8.0

-Wearables: fixed section url. Fixed page parsing key for specialLinkValue. Fixed parsing key for special_link_type "app" case. Updated mock data.

-Opt-in: updated parsing keys.

-Tracked informed consent answers.

-Added RxSwiftExt pod. Refactored Analytics architecture. Added retry login to InternalAnalyticsPlatform tracking attempts.

-Added analytics architecture. Added contextual api request architecture. Tracked screening answers. Fixed opt in send permission request.

-Fixed opt in permission send request

-Wearables login: fixed cookie expiration. Fixed callback handling.

-Added minimum required correct answers for screening and informed consent questions.

-Wearables: added login flow.

-Wearable pages: added default button texts.

-Completed Wearables section.

-Renamed InfoPage entity in Page entity. Handled missing key error when decoding using property wrappers. Added Wearables section (WIP).

-Refactored images: removed monochromatic duplicate images with different colors and colored template images programmatically.

-Opt-in: added section mock data. Fixed layout issues. Added property wrapper to exclude invalid items in array when decoding.

-Opt-In: handled system permissions.

-Opt-in: handled mandatory permissions.

-Opt-In: implemented API call to send user permission.

-Opt-in: added navigation through permissions and to success page.

-Created GenericTextCheckboxView for views with checkbox and text. Added grant and deny permission checkboxes in OptInPermissionViewController.

-Created OptInSection and releated entities. Implemented API call to get opt in section. Created opt in permission UI.

-Moved global config cache flag context from Debug build to any build.

-Disabled global config caching.



## Release 0.7.0

-Added mime type to signature base string in user consent update API request.

-Fixed wrong agree assignment in user content create/update API call.



## Release 0.6.0

-Review consent page subtitle attribute name added

-Removed unwanted option in base64 encoding for signature upload.

-Consent User Data: fixed backward navigation in signature page.

-Consent User Data: added back button in email page.

-Fixed wrong email verification token error code. Removed wrong assert.

-Consent User Data: refactored network layer.

-Applyed StyleCategory pattern to NavigationBarStyles. Adapted status bar based on different navigation bar styles.

-Removed unused Validator extensions.

-Consent User Data: updated network layer.

-Added UberSignature pod. Added user signature page to Consent User Data section. Fixed code styling warnings.

-Consent User Data: created email verification page.

-Created UserEmailViewController. Added style category to GenericTextFieldView. Implemented user consent related API calls. Added user content static strings.

-Added RxCocoa pod. Replaced occurrencies of BehaviorSubject with BehaviorRelay. Created coordinator architecture for Consent User Data section. Created page to add user first name and last name.

-Refactored GenericButton styles.

-Consent review: made subtitle optional (waiting for API update).

-Added disagree confermation popup in consent review. Fixed shadows.

-Consent Review: added page content.

-Refactored ButtonStyles in ButtonTextStyleCategory enum. Created DoubleButtonHorizontalView and added in AcceptanceViewController. Updated mock data.

-Consent Review: implement consent section API call. Added basic coordinator structure and empty AcceptanceViewController.

-Fixed wrong log out flow on status code 401 for responses that do not expect auth token.



## Release 0.5.0

-Increased abstraction in section navigation architercure.

-Updated nextButtonSecondary images.

-Informed consent quiz: Added quiz pages (QuestionViewController).

-Informed consent quiz: added custom bottom view to failure page.

-Handled no questions cases for both Screening questions and Informed Consent.

-Added page navigation through links. Increased code abstraction in coordinator architecture.

-Added Learn More button to InforPageViewController.

-Updated Firebase SDK to 6.25.0.

-Added basic structure for informed consent.

-Update azure-pipelines.yml for Azure Pipelines

-Update azure-pipelines.yml for Azure Pipelines

-Replaced hardcorded text in bottom button of the failure page of the screening questions with the one provided by the InfoPage entity.

-Handled user not logged in error on LoadingViewController.

-Revert signing settings to Automatic.

-temporary app icons added in order to upload app on TestFlight

-Screening questions: prevented backward navigation on success and failure pages.

-Retreived country codes from global config.

-Screening questions: hardcoded body text alignment in info pages. Updated mock data.

-Refactored some entities' name.

-Improved coordinator achitecture.

-Screening questions: handled error cases. Generalized SetupViewController in LoadingViewController to manage section loading.

-Screening questions: added custom layout for retry button in failure page.

-Created ScreeningCoordinator to manager screening navigation (to be improved). Added InfoPageViewController to show Page entities.

-Screening questions: displayed screening section questions.

-Added Japx pod. Created screening-related entities. Adapted network layer to parse responses in jsonapi standard. Implemented screening section endpoint call.

-Screening questions: completed screening questions list with hardcoded data. Added test app entry point enum.

-Fixed onboarding abort button font style

- Added abort button and logic for onboarding sections.

-Generalized Utility classes.

-Refactored style naming. Improved GenericButtonView styling. Added empty ScreeningQuestionsViewController (just confirm button and backward navigation)

-Created font style set and applied to existing views.

-Fixed NetworkApiGateway contruction in Release. Improved error handling in AppNavigator.

-Persisted bearer jwt.

-Phone Validation: retrived country codes from global config (currently hardcoded during parsing stage).

-Phone Validation: improved phone number formatting.

-Phone Validation: updated API requirements. Created architecture for endpoint-specific error handling.

-WebView: handled connectivity and generic errors.

-Phone Validation: added CountryPickerView pod. Added country picker.

-Phone Validation: added resend code button. Updated bottom items layout

-Phone Validation: added text field maximum character logic and set max number of digits and keyboard type for validation code.

-Phone Validation: added PhoneNumberKit pod. Added phone format in phone number textfield.

-Phone Validation: added abstraction to textfields.

-Phone Validation: separated phone text view in dedicated class. Added code validation page.

-Phone Validation: shown links in webview.

-Phone Validation: improved scrolling inset (still need work). Completed next button availability.

-Phone Validation: added legal note with checkbox and label interactions.

-Phone Validation: handled keyboard-related issues.

-Phone Validation: synced right icon appearance.

-Phone Validation: added phone number textfield.

-Phone verification: added top static elements and confirm button.

-Sign Up: added temporary API calls for phone number submit and verification.

-Updated initial loading screen graphic.

-IntroViewController: extended tappable area on bottom buttons.

-Added shadow to wide buttons in WelcomeViewController and SetupLaterViewController.

-Matched bottom views height in IntroViewController and SetupLaterViewController.

-Used primary color for progress hud.

-Resolved warnings. Reinstalled pods.

-Welcome page: added fade easeInOut animation to the Get Started button when page appears.

-Setup later page: fixed bottom background.

-Added setup later page.

-Removed failing tests.

-CI with Azure Pipelines setup

-Signing and certificates for AppStore added

-Second welcome page added.

-Created welcome page. Added GenericButtonView for future use and added style pattern for UIButton, GenericButtonView and UINavigationBar classes.

-Updated network layer settings

-Added gradient background to loading page. Fixed copyright in file comments. Added utility files.

-Added error view to initial loading screen.

-Added initial loading screen

-Added persistence to GlobalConfig

-Created GlobalConfig entity. Requested and parsed on startup. Initialized ColorPalette and StringsProvider.

-Added StringsProvider

-Added ColorPalette.

-Added ImagePalette and FontPalette.

-Added main archieture and utility classes. Implemented initial async setup logic.



## Release 0.4.0. 

-Configured swiftlint. Updated podspec homepage to a reachable one. Cleared warnings. Updated PodFile to show only dev pod warnings.

-Moved pod to repo root. Updated tag.

-Cleanup podspecs. Updated tag.

-Created Pod. Added Third party libraries. Integrated Firebase on Example project. Setup pod to show image from xcassets. Shown test view controller.

