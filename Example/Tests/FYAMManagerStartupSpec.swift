//
//  FYAMManagerStartupSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4519: `FYAMManager.startup` is idempotent. The test bundle statically links its own copy
//  of the framework, so it cannot see the window the host app's AppDelegate built; the spec seeds
//  the cache instead. The host app has already configured Firebase, so if the guard did not
//  short-circuit, `FirebaseApp.configure()` would raise "Default app has already been configured."
//  and fail the spec.
//

import Quick
import Nimble
import FirebaseCore
@testable import ForYouAndMe

class FYAMManagerStartupSpec: QuickSpec {
    override class func spec() {
        describe("FYAMManager.startup called again in the same process") {
            var seeded: UIWindow!

            beforeEach {
                seeded = UIWindow(frame: .zero)
                FYAMManager.startedWindow = seeded
            }
            afterEach {
                FYAMManager.startedWindow = nil
            }

            it("startup_twice_returns_the_same_window") {
                expect(FirebaseApp.app()).toNot(beNil())
                let first = FYAMManager.startup(withFontStyleMap: [:],
                                                showDefaultUserInfo: true,
                                                appleWatchAlternativeIntegrations: [])
                let second = FYAMManager.startup(withFontStyleMap: [:],
                                                 showDefaultUserInfo: true,
                                                 appleWatchAlternativeIntegrations: [])
                expect(first === seeded).to(beTrue())
                expect(second === first).to(beTrue())
            }

            it("startup_second_call_ignores_different_parameters") {
                let second = FYAMManager.startup(withFontStyleMap: [:],
                                                 showDefaultUserInfo: false,
                                                 appleWatchAlternativeIntegrations: [.garmin],
                                                 enableLocationServices: false,
                                                 healthReadDataTypes: [],
                                                 mirrorPrintToJam: true)
                expect(second === seeded).to(beTrue())
            }
        }
    }
}
