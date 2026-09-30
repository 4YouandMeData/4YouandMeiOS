//
//  ResourceResolutionSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3857: architectural rule for this SDK — the framework holds all the defaults
//  (strings, images, assets), and a host app can override any of them.
//  `ImagePalette.image(withName:)` tries the main bundle (host override) first and falls
//  back to the pod resource bundle (framework default); `StringsProvider.string(forKey:)` is
//  `requiredStringMap[key] ?? key.defaultValue` (study-config override, framework default).
//  This spec locks both directions down so a future change can't silently re-break them.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

class ResourceResolutionSpec: QuickSpec {
    override class func spec() {

        describe("ImagePalette — framework-default images (no host copy)") {

            // `.setupFailure` and `.emojiNone` exist only in
            // ForYouAndMe/Assets/ForYouAndMe.xcassets, never in
            // Example/ForYouAndMe/Images.xcassets. Both halves of each assertion matter: the
            // main-bundle miss proves the host isn't supplying it, and the ImagePalette hit
            // proves the pod-resource-bundle fallback (PodUtils) actually served it. Without
            // this, deleting a host copy (as task 1 does for `emoji_none`) could silently
            // regress the fallback with nothing left to catch it.
            let frameworkOnlyImages: [ImageName] = [.setupFailure, .emojiNone]

            for imageName in frameworkOnlyImages {
                it("resolves \(imageName.rawValue) only through the framework default, not a host copy") {
                    expect(UIImage(named: imageName.rawValue)).to(beNil(),
                        description: "\(imageName.rawValue) unexpectedly has a host-bundle copy")
                    expect(ImagePalette.image(withName: imageName)).toNot(beNil(),
                        description: "\(imageName.rawValue) did not resolve via the framework default")
                }
            }
        }

        describe("ImagePalette — host-overridable image") {

            // `.cronometerIcon` ships in both catalogs. `ImagePalette.image(withName:)` tries
            // the main bundle first and RETURNS on a hit, so `ImagePalette.image(withName:
            // .cronometerIcon)` never actually reaches the pod bundle here — asserting it
            // against `UIImage(named:)` alone would just be comparing the same call to itself.
            // Resolve the pod bundle copy explicitly (the same lookup `ImagePalette` would
            // fall back to) so both sides of the comparison are independently produced.
            // The two PNGs are also byte-identical (md5-checked), so this cannot prove the
            // main bundle wins *precedence* over the pod bundle — only that the two copies
            // are override-COMPATIBLE (interchangeable) today. Proving precedence would
            // require the host copy to differ from the framework copy, which this spec
            // deliberately does not manufacture.
            it("resolves cronometer_icon from both the host bundle and the framework's pod bundle, and they match") {
                let hostImage = UIImage(named: ImageName.cronometerIcon.rawValue)
                expect(hostImage).toNot(beNil())

                let podBundle = PodUtils.getPodResourceBundle(withName: Constants.Resources.DefaultBundleName)
                expect(podBundle).toNot(beNil())
                let frameworkImage = podBundle.flatMap { UIImage(named: ImageName.cronometerIcon.rawValue, in: $0, with: nil) }
                expect(frameworkImage).toNot(beNil())

                guard let hostImage = hostImage, let frameworkImage = frameworkImage else { return }
                expect(UIImagePNGRepresentation(hostImage)).to(equal(UIImagePNGRepresentation(frameworkImage)))
            }
        }

        describe("StringsProvider — framework default vs. study override") {

            afterEach {
                // Reset so this spec cannot leak global StringsProvider state into the rest
                // of the suite, and doesn't depend on running before/after any other spec.
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
            }

            // .errorButtonClose has a non-empty default ("Ok", verified in StringsProvider's
            // `defaultValue`) and is read through `requiredStringMap`, so both sides of the
            // override are directly provable — unlike the image case above.
            it("falls back to the framework default when no study value is configured") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
                expect(StringsProvider.string(forKey: .errorButtonClose)).to(equal("Ok"))
            }

            it("uses the study-configured value instead of the framework default when one is set") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.errorButtonClose: "Dismiss"])
                expect(StringsProvider.string(forKey: .errorButtonClose)).to(equal("Dismiss"))
            }

            // FUAM-3857's own case: the sentinel caption key has a blank framework default
            // (no key ships one), and a study can still override it.
            it("resolves EMOJI_NONE_LABEL to a blank framework default, and to the study value when configured") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
                expect(StringsProvider.string(forKey: .emojiNoneLabel)).to(equal(""))

                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Skip"])
                expect(StringsProvider.string(forKey: .emojiNoneLabel)).to(equal("Skip"))
            }
        }
    }
}
