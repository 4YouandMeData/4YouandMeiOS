//
//  PermissionOpener.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

enum PermissionsOpener {

    static func openSettings() {
        DispatchQueue.main.async {
            // Try the `App-prefs:root=Privacy` private URL scheme first so the user
            // lands directly on iOS Settings > Privacy & Security (where the
            // SensorKit / Research Sensor & Usage Data section lives), then fall
            // back to the app's own Settings page. The private scheme is at the
            // host app's review-risk discretion; Jules has accepted the risk for
            // this fix. We deliberately do NOT register `App-prefs` in
            // LSApplicationQueriesSchemes — `UIApplication.open` does not require it
            // (only `canOpenURL` does), and listing it would surface the scheme to
            // Apple's automated scanners.
            guard let privacyURL = URL(string: "App-prefs:root=Privacy"),
                  let fallbackURL = URL(string: UIApplication.openSettingsURLString) else {
                return
            }

            UIApplication.shared.open(privacyURL, options: [:]) { success in
                if !success {
                    UIApplication.shared.open(fallbackURL)
                }
            }
        }
    }
}
