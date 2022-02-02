ForYouAndMe
===========

\[

![](https://img.shields.io/cocoapods/v/ForYouAndMe.svg?style=flat)

\]([https://cocoapods.org/pods/ForYouAndMe)](https://cocoapods.org/pods/ForYouAndMe))  
\[

![](https://img.shields.io/cocoapods/l/ForYouAndMe.svg?style=flat)

\]([https://cocoapods.org/pods/ForYouAndMe)](https://cocoapods.org/pods/ForYouAndMe))  
\[

![](https://img.shields.io/cocoapods/p/ForYouAndMe.svg?style=flat)

\]([https://cocoapods.org/pods/ForYouAndMe)](https://cocoapods.org/pods/ForYouAndMe))

Requirements
------------

iOS 13.0+

Description
-----------

The `ForYouAndMe` project contains an `Example Project` to easily build and run an iOS app that implements the `ForYouAndMe` framework. Follow the instructions under **Example Project** paragraph to build and run it.

The `ForYouAndMe` framework is also available as an iOS `CocoaPod` library in order to use it in a new project created from scratch. Follow the instructions under **Create a study app from scratch** paragraph to build and run it.

Example Project
---------------

To run the example project:

1.  clone the repo.
    
2.  run `pod install` from the Example directory.
    
3.  download your Firebase project `GoogleService-Info.plist` from Firebase Console(follow instructions at [https://firebase.google.com/docs/cloud-messaging/ios/client#upload\_your\_apns\_authentication\_key](https://firebase.google.com/docs/cloud-messaging/ios/client#upload_your_apns_authentication_key) ) then move it under the `Example/ForYouAndMe` folder.
    
4.  open `ForYouAndMe.xcworkspace` (**not the .xcodeproj file!**) with the latest version of XCode.
    
5.  in XCode select the `ForYouAndMe` project on the left panel and choose `Signing & Capabilities` tab and enter personal provisioning profile or choose `Automatically manage signing` and enter `Team`

6.  On the `Signing & Capabilities` tab also ensure that your app Bundle Identifier matches with the created Firebase app id.
    
7.  Navigate - using _Finder_ on _Mac_, or _Windows Explorer_ on _Windows_ - to `/Example/ForYouAndMe` folder and rename the `ProjectInfo_sample.plist` to `ProjectInfo.plist`.
    
8.  in XCode open `ProjectInfo.plist` file and fill the property values with the following:
    
    1.  `api_base_url` base url of the server that provides your remote APIs(ex.: https://api.example.com).
        
    2.  `oauth_base_url` base url of the server that handles your Oauth authentication against the supported integrations(ex.: https://oauth.example.com).
        
    3.  `study_id` identifier of your study as recorded on your server as the `alias` of your study.
        
    4.  `pin_code_suffix` (only needed in studies that use the pin login) pin code suffix needed for your study, or to `none` if pin code is not supported for your study.
        
9.  select the connected iPhone device or a simulator and run the app.
    
10.  in XCode select the `ForYouAndMe` project on the left panel, choose `General` tab and, in the `Display Name` field enter the app name you want to be displayed on the device.
    

**Create a study app from scratch**
-----------------------------------

The following instructions assume you want to install ForYouAndMe on a brand new project, created using the Storyboard option for the Interface setting and Swift as Language. Of course, this SDK is compatible with other initial settings, but you’ll have to change the project.

Create a new XCode project choosing `App` template, then fill the option as follows:

*   `Product Name`: name of the study project
    
*   `Team`: name of your team defined on the Apple Developer Console
    
*   `Organizer Indentifier`: your organisation identifier using the standard format `com.company`
    
*   `Bundle Identifier`: it’s a read only field that shows the bundle id created concatenating the `Organizer Identifier` and the `Product Name`. **IMPORTANT: this will be the unique identifier of the new app that will identify it on the App Store.**
    
*   `Interface`: select `Storyboard`
    
*   `Language`: select `Swift`
    
*   `Use Core Data`: uncheck it
    
*   `Include Tests`: check it
    

Click on `Next` and choose the project location.

ForYouAndMe is available through [CocoaPods](https://cocoapods.org). To install it follow these steps on `terminal`:

1.  Install `CocoaPods` following instructions on [https://cocoapods.org/](https://cocoapods.org/)
    
2.  Navigate to the project folder and run the command  
    
    ```java
    pod init
    ```
    

A file called `Podfile` should have been generated.

3\. Open the `Podfile` with XCode or another text editor and replace the content with the following lines:

```ruby
platform :ios, '13.0'
use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

# Pods for project
def available_pods
    pod 'ForYouAndMe'
end

target '<project_name>' do
    available_pods
    use_frameworks!
    
    target '<test_project_name>' do
        inherit! :search_paths
        # Pods for testing
    end
    
end
```

Replace `<project_name>` with the name you entered on `Product Name` on the project creation step.

Replace `<test_project_name>` with the test project that has been created, its default name is `<project_name>Tests` where the `<project_name>` is the `Product Name`.

Save the modified file.

4\. Run the command

```java
pod install
```

5\. A `<project_name>.xcworkspace` file should have been generated under your project folder, open it with XCode.

Once you have installed ForYouAndMe, there are some additional steps to be done in order to configure your own study app:

### Capabilities

Add the following Capabilities to your app:

1.  Push Notifications
    
2.  Access WiFi Information
    

### Info.plist

Add or edit the following entries to your info.plist file:

1.  `UIViewControllerBasedStatusBarAppearance` set to `false`.
    
2.  `UIUserInterfaceStyle` set to `Light`.
    
3.  `NSAppleMusicUsageDescription` set to `$(PRODUCT_NAME) uses Media Library during certain tasks.`
    
4.  `NSBluetoothAlwaysUsageDescription` set to `$(PRODUCT_NAME) uses Bluetooth to connect with wearables.`
    
5.  `NSBluetoothPeripheralUsageDescription` set to `$(PRODUCT_NAME) uses Bluetooth to connect with wearables.`
    
6.  `NSCalendarsUsageDescription` set to `$(PRODUCT_NAME) uses Calendar during certain tasks.`
    
7.  `NSCameraUsageDescription` set to `$(PRODUCT_NAME) captures photos and video during certain tasks.`
    
8.  `NSContactsUsageDescription` set to `$(PRODUCT_NAME) uses Contacts during certain tasks.`
    
9.  `NSLocationAlwaysAndWhenInUseUsageDescription` set to `$(PRODUCT_NAME) will use your location to verify information such as how far you travelled and the speed at which you travelled, as described in the informed consent.`
    
10.  `NSLocationWhenInUseUsageDescription` set to `$(PRODUCT_NAME) will use your location to verify information such as how far you travelled and the speed at which you travelled, as described in the informed consent.`
    
11.  `NSMicrophoneUsageDescription` set to `$(PRODUCT_NAME) records audio during certain tasks.`
    
12.  `NSMotionUsageDescription` set to `$(PRODUCT_NAME) will use your motion data for your active tasks.`
    
13.  `NSSpeechRecognitionUsageDescription` set to `$(PRODUCT_NAME) uses Speech Recognition during certain tasks.`
    
14.  `LSApplicationQueriesSchemes` set an array of strings, containing: `oura`, `fitbit`, `twitter`, `instagram`, `gcm-ciq`
    

Below an example of the xml version of the above options:

```java
...
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>oura</string>
		<string>fitbit</string>
		<string>twitter</string>
		<string>instagram</string>
		<string>gcm-ciq</string>
	</array>
	<key>NSAppleMusicUsageDescription</key>
	<string>$(PRODUCT_NAME) uses Media Library during certain tasks.</string>
	<key>NSBluetoothAlwaysUsageDescription</key>
	<string>$(PRODUCT_NAME) uses Bluetooth to connect with wearables.</string>
	<key>NSBluetoothPeripheralUsageDescription</key>
	<string>$(PRODUCT_NAME) uses Bluetooth to connect with wearables.</string>
	<key>NSCalendarsUsageDescription</key>
	<string>$(PRODUCT_NAME) uses Calendar during certain tasks.</string>
	<key>NSCameraUsageDescription</key>
	<string>$(PRODUCT_NAME) captures photos and video during certain tasks.</string>
	<key>NSContactsUsageDescription</key>
	<string>$(PRODUCT_NAME) uses Contacts during certain tasks.</string>
	<key>NSHealthShareUsageDescription</key>
	<string>$(PRODUCT_NAME) will use your health data for further analysis.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>$(PRODUCT_NAME) will use your location to verify information such as how far you travelled and the speed at which you travelled, as described in the informed consent.</string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>$(PRODUCT_NAME) will use your location to verify information such as how far you travelled and the speed at which you travelled, as described in the informed consent.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>$(PRODUCT_NAME) records audio during certain tasks.</string>
	<key>NSMotionUsageDescription</key>
	<string>$(PRODUCT_NAME) will use your motion data for your active tasks.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>$(PRODUCT_NAME) uses Speech Recognition during certain tasks.</string>
	<key>UIUserInterfaceStyle</key>
	<string>Light</string>
	<key>UIViewControllerBasedStatusBarAppearance</key>
	<false/>

...
```

### Cleanup default files and settings

If you have installed ForYouAndMe on a brand new project, there are a few files and settings generated by Xcode (version 12.1 at the time of writing) that have to be fixed:

#### From the project

1.  Remove `Main.storyboard`.
    
2.  Remove `SceneDelegate.swift`.
    
3.  Remove `ViewController.swift`.
    

#### From the info.plist file

Remove the `UIApplicationSceneManifest` entry from `info.plist`.

#### In the General Tab

1.  Set iOS 13.0 and iPhone .
    
2.  Clear the `Main Interface` field.
    
3.  Device Orientation: `Portrait`, `Landscape Left`, `Landscape Right`.
    

#### In the AppDelegate class

1.  Remove all methods under the `UISceneSession Lifecycle` mark.
    
2.  Add an instance variable called `window` of type `UIWindow?` using: `var window: UIWindow?`.
    

### Project Info

Create a plist file called `ProjectInfo.plist` and add it to your project. Inside this file, add the following entries:

1.  `api_base_url` set to the base url of the server that provides your remote APIs.
    
2.  `oauth_base_url` set to the base url of the server that handles your Oauth authentication against the supported integrations.
    
3.  `study_id` set to the identifier of your study as recorded on your server.
    
4.  `pin_code_suffix` set to the pin code suffix needed for your study, or to `none` if pin code is not supported for your study.
    

How to customise a study app
----------------------------

### Firebase

ForYouAndMe uses **Firebase** platform to track analytics, detect crashes and handle push notifications. Create a project on Firebase and add the resulting `GoogleService-info.plist` file to your project.  
Then setup your Firebase project to handle push notifications by uploading the `APNs Authentication Key` of your app to your Firebase project Settings (see [https://firebase.google.com/docs/cloud-messaging/ios/client#upload\_your\_apns\_authentication\_key](https://firebase.google.com/docs/cloud-messaging/ios/client#upload_your_apns_authentication_key) for more details).

### Study Video

You have to provide an introduction video for your app. This video format must be `mp4`. Name it `StudyVideo.mp4` and add it to your project.

### Images

ForYouAndMe requires that you provide a specific set of images to your default `Assets.xcassets` file. The images needed by the framework fall in two main categories: **normal images** and **template images**. While the first ones have no particular requirement, the second ones should be provided in grey scale as they will be used as template images and coloured by the framework according to the color palette of the current study.

#### Normal images list

<table data-layout="default" data-local-id="62075855-4623-4a0e-bc03-795e0361e5b9" class="confluenceTable"><colgroup><col style="width: 340.0px;"><col style="width: 340.0px;"></colgroup><tbody><tr><th class="confluenceTh"><p>image name</p></th><th class="confluenceTh"><p>description</p></th></tr><tr><td class="confluenceTd"><p>back_button_primary</p></td><td class="confluenceTd"><p>Button styled with primary color used for backward navigation typically located on page footers</p></td></tr><tr><td class="confluenceTd"><p>camera_switch</p></td><td class="confluenceTd"><p>Button to switch front and rear camera during some tasks (e.g.: Video Diary)</p></td></tr><tr><td class="confluenceTd"><p>checkmark</p></td><td class="confluenceTd"><p>Generic checkmark icon</p></td></tr><tr><td class="confluenceTd"><p>circular</p></td><td class="confluenceTd"><p>Generic handle used in video player sliders</p></td></tr><tr><td class="confluenceTd"><p>clear_button</p></td><td class="confluenceTd"><p>Clear icon for text fields</p></td></tr><tr><td class="confluenceTd"><p>clear_circular</p></td><td class="confluenceTd"><p>Video player sliders' handle that will be used when the handle is disabled. Typically a transparent will do the trick.</p></td></tr><tr><td class="confluenceTd"><p>close_circle_button</p></td><td class="confluenceTd"><p>Discard button for video diary</p></td></tr><tr><td class="confluenceTd"><p>edit</p></td><td class="confluenceTd"><p>Edit button for text fields</p></td></tr><tr><td class="confluenceTd"><p>failure</p></td><td class="confluenceTd"><p>Generic failure header image</p></td></tr><tr><td class="confluenceTd"><p>fitbit_icon</p></td><td class="confluenceTd"><p>Fitbit device icon</p></td></tr><tr><td class="confluenceTd"><p>flash_off</p></td><td class="confluenceTd"><p>Disabled flash icon for video record</p></td></tr><tr><td class="confluenceTd"><p>flash_on</p></td><td class="confluenceTd"><p>Enabled flash icon for video record</p></td></tr><tr><td class="confluenceTd"><p>fyam_logo_generic</p></td><td class="confluenceTd"><p>Generic logo image that should represent your organization</p></td></tr><tr><td class="confluenceTd"><p>fyam_logo_specific</p></td><td class="confluenceTd"><p>Organization logo image specific of the current study</p></td></tr><tr><td class="confluenceTd"><p>health_icon</p></td><td class="confluenceTd"><p>Health App permission icon</p></td></tr><tr><td class="confluenceTd"><p>garmin_icon</p></td><td class="confluenceTd"><p>Garmin device icon</p></td></tr><tr><td class="confluenceTd"><p>instagram_icon</p></td><td class="confluenceTd"><p>Instagram icon</p></td></tr><tr><td class="confluenceTd"><p>location_icon</p></td><td class="confluenceTd"><p>Location permission icon</p></td></tr><tr><td class="confluenceTd"><p>main_logo</p></td><td class="confluenceTd"><p>Current study logo</p></td></tr><tr><td class="confluenceTd"><p>next_button_primary</p></td><td class="confluenceTd"><p>Button styled with primary color used for forward navigation typically located on page footers</p></td></tr><tr><td class="confluenceTd"><p>next_button_secondary_disabled</p></td><td class="confluenceTd"><p>Button styled with secondary color in disabled mode, used on primary backgrounds</p></td></tr><tr><td class="confluenceTd"><p>next_button_secondary</p></td><td class="confluenceTd"><p>Button styled with secondary color, used on primary backgrounds</p></td></tr><tr><td class="confluenceTd"><p>oura_icon</p></td><td class="confluenceTd"><p>Oura device icon</p></td></tr><tr><td class="confluenceTd"><p>push_notification_icon</p></td><td class="confluenceTd"><p>Push notification permission icon</p></td></tr><tr><td class="confluenceTd"><p>rescue_time_icon</p></td><td class="confluenceTd"><p>Rescue time device icon</p></td></tr><tr><td class="confluenceTd"><p>star_empty</p></td><td class="confluenceTd"><p>Empty rate image shown your data</p></td></tr><tr><td class="confluenceTd"><p>star_fill</p></td><td class="confluenceTd"><p>Filled rate image shown your data</p></td></tr><tr><td class="confluenceTd"><p>twitter_icon</p></td><td class="confluenceTd"><p>Twitter icon</p></td></tr><tr><td class="confluenceTd"><p>video_calendar</p></td><td class="confluenceTd"><p>Calendar icon shown in video diary tasks</p></td></tr><tr><td class="confluenceTd"><p>video_pause</p></td><td class="confluenceTd"><p>Pause button for video players</p></td></tr><tr><td class="confluenceTd"><p>video_play</p></td><td class="confluenceTd"><p>Play button for video players</p></td></tr><tr><td class="confluenceTd"><p>video_record</p></td><td class="confluenceTd"><p>Record button for video players</p></td></tr><tr><td class="confluenceTd"><p>video_recorded_feedback</p></td><td class="confluenceTd"><p>Successful record icon shown in video diary tasks</p></td></tr><tr><td class="confluenceTd"><p>video_resume_record</p></td><td class="confluenceTd"><p>Resume record button for video players</p></td></tr><tr><td class="confluenceTd"><p>video_time</p></td><td class="confluenceTd"><p>Time icon for current record progress in video diary tasks</p></td></tr></tbody></table>

#### Template images list

<table data-layout="default" data-local-id="45f39d39-bf0a-4b88-9926-c031bbe95236" class="confluenceTable"><colgroup><col style="width: 340.0px;"><col style="width: 340.0px;"></colgroup><tbody><tr><th class="confluenceTh"><p>image name</p></th><th class="confluenceTh"><p>description</p></th></tr><tr><td class="confluenceTd"><p>arrow_right</p></td><td class="confluenceTd"><p>generic disclosure indicator</p></td></tr><tr><td class="confluenceTd"><p>back_button_navigation</p></td><td class="confluenceTd"><p>generic back button used in navigation bars</p></td></tr><tr><td class="confluenceTd"><p>checkbox_filled</p></td><td class="confluenceTd"><p>Generic filled checkbox icon</p></td></tr><tr><td class="confluenceTd"><p>checkbox_outline</p></td><td class="confluenceTd"><p>Generic not filled checkbox icon</p></td></tr><tr><td class="confluenceTd"><p>close_button</p></td><td class="confluenceTd"><p>Close button for modal pages</p></td></tr><tr><td class="confluenceTd"><p>contact_icon</p></td><td class="confluenceTd"><p>Contacts page icon</p></td></tr><tr><td class="confluenceTd"><p>devices_icon</p></td><td class="confluenceTd"><p>Your Apps and Devices page icon</p></td></tr><tr><td class="confluenceTd"><p>edit_small</p></td><td class="confluenceTd"><p>Smaller edit button for text fields</p></td></tr><tr><td class="confluenceTd"><p>faq_icon</p></td><td class="confluenceTd"><p>FAQ page icon</p></td></tr><tr><td class="confluenceTd"><p>filter_icon</p></td><td class="confluenceTd"><p>Filter icon in Your Data</p></td></tr><tr><td class="confluenceTd"><p>permission_icon</p></td><td class="confluenceTd"><p>Permission page icon</p></td></tr><tr><td class="confluenceTd"><p>radio_button_filled</p></td><td class="confluenceTd"><p>Generic filled radio button icon</p></td></tr><tr><td class="confluenceTd"><p>radio_button_outline</p></td><td class="confluenceTd"><p>Generic not filled radio button icon</p></td></tr><tr><td class="confluenceTd"><p>review_consent_icon</p></td><td class="confluenceTd"><p>Review Consent page icon</p></td></tr><tr><td class="confluenceTd"><p>rewards_icon</p></td><td class="confluenceTd"><p>Rewards summary page icon</p></td></tr><tr><td class="confluenceTd"><p>tab_feed</p></td><td class="confluenceTd"><p>Feed tab icon</p></td></tr><tr><td class="confluenceTd"><p>tab_study_info</p></td><td class="confluenceTd"><p>Study Info tab icon</p></td></tr><tr><td class="confluenceTd"><p>tab_task</p></td><td class="confluenceTd"><p>Task tab icon</p></td></tr><tr><td class="confluenceTd"><p>tab_user_data</p></td><td class="confluenceTd"><p>Your Data tab icon</p></td></tr><tr><td class="confluenceTd"><p>user_info_icon</p></td><td class="confluenceTd"><p>Editable profile info page icon</p></td></tr></tbody></table>

### Framework AppDelegate setup

In your AppDelegate file, import the ForYouAndMe framework by including:

```java
import ForYouAndMe
```

Add the following delegate method implementation:

```java
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            return FYAMManager.orientationLock
    }
```

Lastly, in the `application(_ application:, didFinishLaunchingWithOptions:)` method delete all existing code and call the `startup(withFontStyleMap:, showDefaultUserInfo:, checkResourcesAvailability:, enableLocationServices:)` static method of the `FYAMManager` class and store the result in the previously created `window` variable.

This method takes three parameters:

1.  `fontStyleMap`: a dictionary of `FontStyle` -> `FontStyleData`, where `FontStyle` is an enum representing the palette of font styles used throughout the framework, and `FontStyleData` is a struct that allows you to specify custom font, line spacing and uppercase flag for each font style.
    
2.  `showDefaultUserInfo`: whether or not to show a study-specific page that shows and allows to edit user's personal informations (will be removed in the future in favor of a more dynamic approach).
    
3.  `appleWatchAlternativeIntegrations`: list of Integrations (e.g.: Garmin, Fitbit, …) which are considered to be mutually exclusive with Apple Watch, regarding the data shown in Your Data. Specifically: if the user, during the Opt-In flow, has agreed to use the Apple Watch (thus she has granted the **health** permission), only Apple Watch data will be shown in the Your Data page, while all data coming from the integrations listed in this variable will be discarded. If the user has not agreed to use Apple Watch, data coming from Apple Watch will be discarded and all other data will be regularly shown.
    
4.  `checkResourcesAvailability`: whether or not font styles and images should be validated on startup to ensure that the framework has all the resources it needs. Default: false.
    
5.  `enableLocationServices`: whether or not to ask user location permission or show the relative permission in the permission page. Default: true.
    
6.  `healthReadDataTypes`: list of HealthDataType items that should be gathered via HealthKit and sent to the server. Note: this works only if HealthKit has been integrated (see later). Default: empty array.
    

Example:

```java
var fontStyleMap: FontStyleMap = [:]
if let font = UIFont(name: "Helvetica", size: 24.0) {
	fontStyleMap[.title] = FontStyleData(font: font, lineSpacing: 6.0, uppercase: false)
}
if let font = UIFont(name: "Helvetica", size: 20.0) {
	fontStyleMap[.header2] = FontStyleData(font: font, lineSpacing: 6.0, uppercase: false)
}
if let font = UIFont(name: "Helvetica", size: 16.0) {
	fontStyleMap[.paragraph] = FontStyleData(font: font, lineSpacing: 5.0, uppercase: false)
}
if let font = UIFont(name: "Helvetica", size: 13.0) {
	fontStyleMap[.header3] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: false)
}
if let font = UIFont(name: "Helvetica", size: 13.0) {
	fontStyleMap[.menu] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: true)
}
self.window = FYAMManager.startup(withFontStyleMap: fontStyleMap,
								  showDefaultUserInfo: true,
								  appleWatchAlternativeIntegrations: [.garmin, .fitbit],
								  checkResourcesAvailability: true,
								  enableLocationServices: false,
                                  healthReadDataTypes: HealthDataType.allCases)
return  true
```

Below an example of how the `AppDelegate` file could looks like after the above steps:  

```java
import UIKit
import ForYouAndMe

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        var fontStyleMap: FontStyleMap = [:]
        if let font = UIFont(name: "Helvetica", size: 24.0) {
            fontStyleMap[.title] = FontStyleData(font: font, lineSpacing: 6.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 20.0) {
            fontStyleMap[.header2] = FontStyleData(font: font, lineSpacing: 6.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 16.0) {
            fontStyleMap[.paragraph] = FontStyleData(font: font, lineSpacing: 5.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.header3] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.menu] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: true)
        }
        self.window = FYAMManager.startup(withFontStyleMap: fontStyleMap,
                                          showDefaultUserInfo: true,
                                          appleWatchAlternativeIntegrations: [.garmin, .fitbit],
                                          checkResourcesAvailability: true,
                                          healthReadDataTypes: HealthDataType.allCases)
        
        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            return FYAMManager.orientationLock
    }
}

```

### Launch Screen (Optional)

Edit your default `LaunchScreen.storyboard` file to show a launch screen that fits your study.

### HealthKit (Optional)

Currently data from user’s third party wearables are gathered through server-to-server scheduled operations. However Apple Watch cannot be accessed this way, so the app must take care of gathering data from the Health app and send them to the server.

If you want to include the use of Apple Watch in your study, use the following instructions:

1.  Add the following entries to your **Info.plist** file:
    
    1.  `NSHealthShareUsageDescription` set to `$(PRODUCT_NAME) will use your health data for further analysis` (or something appropriate for your study).
        
    2.  `NSHealthUpdateUsageDescription` set to `$(PRODUCT_NAME) will update your health data based on your task results` (actually, what you write here is irrelevant, since the purpose of the HealthKit implementation is just reading Health data. However, you need to add this key because otherwise you’ll get an error while uploading the app to AppStoreConnect, even if [official Apple doc](https://developer.apple.com/documentation/bundleresources/information_property_list/nshealthupdateusagedescription) states that this description is needed only if you save data in the Health app).
        
2.  Add the **HealthKit** capability to your project.
    
3.  In AppDelegate, inside the `application(_ application:, didFinishLaunchingWithOptions:)` method, provide the `healthReadDataTypes` parameter to the `startup` static method of the `FYAMManager` class. As value you’ll need to provide an array of cases of the `HealthDataType` enum, thus specifying what data you want to read from the Health app.
    
4.  Add the following code at the end of your **PodFile**:
    

```ruby
post_install do |installer_representation|
  installer_representation.pods_project.targets.each do |target|
    if ['ForYouAndMe'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) HEALTHKIT'
      end
    end
  end
end
```

Author
------

LeonardoPasseri, [leonardo@balzo.eu](mailto:leonardo@balzo.eu)

License
-------

ForYouAndMe is available under the MIT license. See the LICENSE file for more info.
