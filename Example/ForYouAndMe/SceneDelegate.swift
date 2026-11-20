//
//  SceneDelegate.swift
//  ForYouAndMe
//

import UIKit
import ForYouAndMe

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

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
        if let font = UIFont(name: "Helvetica-Bold", size: 16.0) {
            fontStyleMap[.paragraphBold] = FontStyleData(font: font, lineSpacing: 5.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.header3] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.menu] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: true)
        }
        if let font = UIFont(name: "Helvetica-Bold", size: 11.0) {
            fontStyleMap[.messages] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: true)
        }

        fontStyleMap[.infoNote] = FontStyleData(font: UIFont.boldSystemFont(ofSize: 11), lineSpacing: 3.0, uppercase: false)

        let window = FYAMManager.startup(withFontStyleMap: fontStyleMap,
                                         showDefaultUserInfo: true,
                                         appleWatchAlternativeIntegrations: [.garmin, .fitbit],
                                         checkResourcesAvailability: true,
                                         enableLocationServices: true,
                                         healthReadDataTypes: HealthDataType.allCases)
        // The SDK creates and shows the window before any scene exists, so attach
        // it to this scene and show it again (UIScene lifecycle, required on iOS 27).
        window.windowScene = windowScene
        window.makeKeyAndVisible()
        self.window = window
    }
}
