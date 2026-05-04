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

        context("NumericInputValidator integer") {

            it("accepts empty string") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "", maxDigits: 4)) == true
            }

            it("accepts single zero") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "0", maxDigits: 4)) == true
            }

            it("accepts values up to max digits") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "1", maxDigits: 4)) == true
                expect(NumericInputValidator.shouldAcceptInteger(newText: "9999", maxDigits: 4)) == true
            }

            it("rejects values with too many digits") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "10000", maxDigits: 4)) == false
            }

            it("rejects leading zeros") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "00", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "01", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "0123", maxDigits: 4)) == false
            }

            it("rejects non-digit characters") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "1a", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "12.3", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "-5", maxDigits: 4)) == false
            }
        }

        context("NumericInputValidator decimal") {

            it("accepts empty string") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
            }

            it("accepts valid decimals") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0.5", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0.12", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.5", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "9999", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "9999.99", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
            }

            it("rejects leading zeros") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "00", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "01", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "012.5", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects too many integer digits") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "10000", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "99999", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects too many fraction digits") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.234", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects multiple dots") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.2.3", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects non-digit characters") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1a", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.a", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects empty integer part") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: ".5", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: ",5", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("accepts comma as decimal separator (non-US locales)") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0,5", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "9999,99", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1,234", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects multiple separators of any kind") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1,2,3", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.2,3", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("normalizes comma to dot for parsing") {
                expect(NumericInputValidator.normalizedDecimalString("9,5")) == "9.5"
                expect(NumericInputValidator.normalizedDecimalString("9.5")) == "9.5"
                expect(Double(NumericInputValidator.normalizedDecimalString("9,5"))) == 9.5
            }
        }

        context("EmailValidator") {

            it("accepts standard addresses") {
                expect(EmailValidator.isValid("foo@bar.com")) == true
                expect(EmailValidator.isValid("user@example.org")) == true
                expect(EmailValidator.isValid("a.b@c.co.uk")) == true
            }

            it("accepts addresses with plus tags and dots in local part") {
                expect(EmailValidator.isValid("foo+tag@bar.com")) == true
                expect(EmailValidator.isValid("first.last@example.com")) == true
                expect(EmailValidator.isValid("first.last+tag@sub.example.com")) == true
            }

            it("accepts addresses with digits and hyphens") {
                expect(EmailValidator.isValid("user123@my-domain.com")) == true
                expect(EmailValidator.isValid("42@a1.io")) == true
            }

            it("rejects empty and whitespace-only strings") {
                expect(EmailValidator.isValid("")) == false
                expect(EmailValidator.isValid("   ")) == false
            }

            it("rejects strings missing the @ symbol") {
                expect(EmailValidator.isValid("foo")) == false
                expect(EmailValidator.isValid("foo.bar.com")) == false
            }

            it("rejects strings missing a domain TLD") {
                expect(EmailValidator.isValid("foo@bar")) == false
                expect(EmailValidator.isValid("foo@bar.")) == false
            }

            it("rejects strings missing a local part or domain") {
                expect(EmailValidator.isValid("@bar.com")) == false
                expect(EmailValidator.isValid("foo@.com")) == false
            }

            it("rejects strings with invalid characters") {
                expect(EmailValidator.isValid("foo bar@baz.com")) == false
                expect(EmailValidator.isValid("foo@bar .com")) == false
                expect(EmailValidator.isValid("foo@@bar.com")) == false
            }

            it("rejects single-character TLDs") {
                expect(EmailValidator.isValid("foo@bar.c")) == false
            }
        }
    }
}

// MARK: - HEALTHKIT / SENSORKIT / TERRA flag decoupling (FUAM-2998 + FUAM-3008)
//
// The Example app builds the ForYouAndMe framework with HEALTHKIT and SENSORKIT
// but without TERRA (see Example/Podfile post_install). The references to
// HealthManager / SensorKitManager below are *compile-time* assertions that
// those flags are still set; the absence of any Terra-gated symbol reference
// is the assertion that TERRA gating strips Terra code from this build.

class CompilationFlagsSpec: QuickSpec {
    override func spec() {
        context("HEALTHKIT flag wiring") {

            it("links HealthManager into the framework binary") {
                _ = HealthManager.self
                expect(true) == true
            }

            it("keeps DummyHealthManager available as the no-HEALTHKIT fallback type") {
                _ = DummyHealthManager.self
                expect(true) == true
            }
        }

        context("SENSORKIT flag wiring") {

            it("links SensorKitManager into the framework binary") {
                _ = SensorKitManager.self
                expect(true) == true
            }
        }

        context("TERRA flag - stripped from this build") {

            it("documents that TERRA-gated symbols are not linked into the Example test target") {
                // Example does not pull the ForYouAndMe/Terra subspec, so TerraManager,
                // TerraService, TerraTokenResponse and Repository.getTerraToken() are
                // stripped at compile time. Adding `_ = TerraManager.self` here would
                // fail to build - that failure mode is precisely what TERRA gating
                // prevents from regressing.
                expect(true) == true
            }
        }
    }
}

class IntegrationTerraSpec: QuickSpec {
    override func spec() {
        context("Integration.terra (flag-independent)") {

            it("resolves terra from raw value") {
                let integration = Integration(rawValue: "terra")
                expect(integration).toNot(beNil())
                expect(integration) == .terra
            }

            it("exposes terra storeUrl pointing at the App Store") {
                let url = Integration.terra.storeUrl
                expect(url.scheme) == "itms-apps"
                expect(url.absoluteString).to(contain("apps.apple.com"))
            }

            it("exposes terra appSchemaUrl with the terra scheme") {
                let url = Integration.terra.appSchemaUrl
                expect(url.scheme) == "terra"
            }

            it("appends the terra path component to the OAuth base URL") {
                let url = Integration.terra.apiOAuthUrl
                expect(url.path).to(contain("/integration_oauth/terra"))
            }

            it("includes a non-empty locale query item on the terra OAuth URL") {
                let url = Integration.terra.apiOAuthUrl
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let localeItem = components?.queryItems?.first { $0.name == "locale" }
                expect(localeItem).toNot(beNil())
                expect(localeItem?.value ?? "") != ""
            }

            it("does not add a locale query item to non-terra integrations") {
                let url = Integration.cronometer.apiOAuthUrl
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                expect(components?.queryItems).to(beNil())
            }

            it("appends the terra path component to the deauthorize URL") {
                let url = Integration.terra.apiOAuthDeauthorizeUrl
                expect(url.path).to(contain("terra"))
            }

            it("uses raw value as strategy prefix") {
                expect(Integration.terra.strategyPrefix) == "terra"
            }
        }
    }
}
