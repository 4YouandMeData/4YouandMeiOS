// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import ForYouAndMe

class TableOfContentsSpec: QuickSpec {
    override func spec() {
        context("these will pass") {

            it("can do maths") {
                expect(23) == 23
            }

            it("can read") {
                expect("🐮") == "🐮"
            }

            it("will eventually pass") {
                var time = "passing"

                DispatchQueue.main.async {
                    time = "done"
                }

                waitUntil { done in
                    Thread.sleep(forTimeInterval: 0.5)
                    expect(time) == "done"

                    done()
                }
            }
        }

        context("Integration enum") {

            it("resolves cronometer from raw value") {
                let integration = Integration(rawValue: "cronometer")
                expect(integration).toNot(beNil())
                expect(integration) == .cronometer
            }

            it("builds correct OAuth URL for cronometer") {
                let url = Integration.cronometer.apiOAuthUrl
                expect(url.path).to(contain("cronometer"))
            }

            it("builds correct deauthorize URL for cronometer") {
                let url = Integration.cronometer.apiOAuthDeauthorizeUrl
                expect(url.path).to(contain("cronometer"))
            }
        }
    }
}
