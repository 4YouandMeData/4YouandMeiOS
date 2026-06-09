//
//  SurveyRangePickerSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3396: locks in the off-by-one fix in SurveyRangePicker.
//
//  Pre-fix behaviour:
//    - slider.maxCount was set to UInt(maximum), so for a 0..6 range it
//      produced 6 ticks (0..5) and a 1..10 range produced 10 ticks but
//      with the wrong index mapping.
//    - the delegate was notified with the raw StepSlider index, so for a
//      question with minimum != 0 the answered value was off by `minimum`.
//
//  Post-fix expectations:
//    - slider.maxCount == (maximum - minimum + 1) inclusive tick count.
//    - delegate.answerDidChange(_, answer:) reports the user-visible scale
//      value (minimum + index), not the raw StepSlider index.
//

import Quick
import Nimble
import StepSlider
@testable import ForYouAndMe

// MARK: - Test helpers

private final class CapturingSurveyQuestionDelegate: SurveyQuestionProtocol {
    private(set) var answers: [Any] = []
    func answerDidChange(_ surveyQuestion: SurveyQuestion, answer: Any) {
        self.answers.append(answer)
    }
}

private enum SurveyQuestionFactory {

    /// Builds a SurveyQuestion via plain JSONDecoder. The struct is
    /// JapxDecodable (i.e. Decodable), so a flat payload that matches the
    /// CodingKeys decodes fine without going through Japx — and the test
    /// target does not link Japx directly.
    static func rangeQuestion(id: String, minimum: Int, maximum: Int) throws -> SurveyQuestion {
        let payload = """
        {
            "id": "\(id)",
            "type": "question",
            "question_type": "SurveyQuestionRange",
            "text": "Range question \(id)",
            "min": \(minimum),
            "max": \(maximum),
            "skippable": false,
            "targets": []
        }
        """.data(using: .utf8)!
        do {
            return try JSONDecoder().decode(SurveyQuestion.self, from: payload)
        } catch {
            // Surface the underlying DecodingError so a missing-key regression
            // gives a clearly diagnosable message rather than the generic
            // "data couldn't be read" wrapper.
            fatalError("SurveyQuestion JSON decoding failed: \(error)")
        }
    }
}

// MARK: - Mirror helpers

private extension SurveyRangePicker {
    /// Reads the private `slider` via Mirror so the test does not need to
    /// touch the production access level.
    var testSlider: StepSlider? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children where child.label == "slider" {
            return child.value as? StepSlider
        }
        return nil
    }
}

// MARK: - Spec

class SurveyRangePickerSpec: QuickSpec {
    override class func spec() {

        describe("SurveyRangePicker (FUAM-3396 — inclusive 0..N range)") {

            context("with minimum=0, maximum=6 (MENQOL 0..6 case)") {
                it("produces 7 ticks on the slider (was 6 before the fix)") {
                    let question = try SurveyQuestionFactory.rangeQuestion(
                        id: "q-menqol-0-6",
                        minimum: 0,
                        maximum: 6)
                    let delegate = CapturingSurveyQuestionDelegate()

                    let picker = SurveyRangePicker(surveyQuestion: question, delegate: delegate)

                    guard let slider = picker.testSlider else {
                        fail("SurveyRangePicker did not expose its private slider via Mirror")
                        return
                    }
                    expect(slider.maxCount) == 7
                }
            }

            context("with minimum=1, maximum=10 (1..10 case)") {
                it("produces 10 ticks on the slider") {
                    let question = try SurveyQuestionFactory.rangeQuestion(
                        id: "q-1-10",
                        minimum: 1,
                        maximum: 10)
                    let delegate = CapturingSurveyQuestionDelegate()

                    let picker = SurveyRangePicker(surveyQuestion: question, delegate: delegate)

                    guard let slider = picker.testSlider else {
                        fail("SurveyRangePicker did not expose its private slider via Mirror")
                        return
                    }
                    expect(slider.maxCount) == 10
                }
            }

            context("delegate answer reporting (minimum != 0)") {
                it("reports minimum + sliderIndex (user-visible scale), not the raw slider index") {
                    let question = try SurveyQuestionFactory.rangeQuestion(
                        id: "q-3-8",
                        minimum: 3,
                        maximum: 8)
                    let delegate = CapturingSurveyQuestionDelegate()

                    let picker = SurveyRangePicker(surveyQuestion: question, delegate: delegate)

                    guard let slider = picker.testSlider else {
                        fail("SurveyRangePicker did not expose its private slider via Mirror")
                        return
                    }

                    // The init forwards an initial answer through changeValue(_:),
                    // computed as `minimum + Int(slider.index)` post-fix.
                    // Pre-fix the answer was just `Int(slider.index)` — i.e. the
                    // raw position, which would have under-reported by `minimum`.
                    let expected = 3 + Int(slider.index)
                    expect(delegate.answers).toNot(beEmpty())
                    expect(delegate.answers.last as? Int) == expected
                    // And in absolute terms: the answer must fall inside [min, max].
                    if let last = delegate.answers.last as? Int {
                        expect(last) >= 3
                        expect(last) <= 8
                    }
                }
            }
        }
    }
}
