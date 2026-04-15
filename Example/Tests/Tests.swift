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
    }
}
