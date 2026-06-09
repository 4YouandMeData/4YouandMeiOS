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
//  The fixture `FUAM-3396-menqol-survey.json` is the verbatim JSON:API
//  payload Proxyman captured from a live MENQOL survey response. We treat
//  it as the canonical reference shape: the post-Japx flat attributes are
//  what the production decoder actually sees, so deriving the SurveyQuestion
//  payload from it removes the hand-crafted-JSON drift that produced the
//  previous SIGTRAP on certain build configurations.
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

private enum FixtureError: Error {
    case fixtureNotFound
    case noRangeQuestionInFixture
    case malformedQuestionEntry
}

private enum MenqolFixture {

    /// Loads the bundled MENQOL JSON:API payload that Jules captured from
    /// Proxyman and returns the flat attribute dict for the first
    /// `SurveyQuestionRange` question (id + type + attributes merged into
    /// a single dictionary — i.e. the shape the production decoder sees
    /// after Japx flattens the JSON:API envelope).
    static func loadFirstRangeQuestionDict() throws -> [String: Any] {
        let bundle = Bundle(for: SurveyRangePickerSpec.self)
        guard let url = bundle.url(forResource: "FUAM-3396-menqol-survey",
                                   withExtension: "json") else {
            throw FixtureError.fixtureNotFound
        }
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let included = json?["included"] as? [[String: Any]] ?? []
        for entry in included {
            guard let type = entry["type"] as? String, type == "question",
                  let attributes = entry["attributes"] as? [String: Any],
                  let qType = attributes["question_type"] as? String,
                  qType == SurveyQuestionType.range.rawValue else {
                continue
            }
            guard let id = entry["id"] as? String else {
                throw FixtureError.malformedQuestionEntry
            }
            var flat: [String: Any] = attributes
            flat["id"] = id
            flat["type"] = type
            return flat
        }
        throw FixtureError.noRangeQuestionInFixture
    }

    /// Builds an in-memory variant of the fixture's flat dict with the
    /// given `min`/`max` overrides, then encodes+decodes it into a
    /// `SurveyQuestion`. This keeps the synthetic cases anchored to the
    /// real server shape — only the numeric range moves.
    static func decodeRangeQuestion(minimum: Double,
                                    maximum: Double,
                                    overridingId: String? = nil) throws -> SurveyQuestion {
        var dict = try loadFirstRangeQuestionDict()
        dict["min"] = minimum
        dict["max"] = maximum
        if let overridingId = overridingId {
            dict["id"] = overridingId
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [])
        return try JSONDecoder().decode(SurveyQuestion.self, from: data)
    }
}

// MARK: - Mirror / view-tree helpers

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

    /// All UILabels in the view subtree (depth-first). Used to verify the
    /// `min_display` / `max_display` strings the picker renders as the
    /// slider's endpoint legends, since they aren't stored on the picker
    /// as named ivars.
    func allLabelTexts() -> [String] {
        var texts: [String] = []
        var stack: [UIView] = [self]
        while let v = stack.popLast() {
            if let label = v as? UILabel, let text = label.text {
                texts.append(text)
            }
            stack.append(contentsOf: v.subviews)
        }
        return texts
    }
}

// MARK: - Spec

class SurveyRangePickerSpec: QuickSpec {
    override class func spec() {

        describe("SurveyRangePicker (FUAM-3396 — inclusive 0..N range)") {

            context("with the real MENQOL fixture (min=0, max=6)") {

                it("decodes the fixture into a SurveyQuestion with min=0, max=6") {
                    let dict = try MenqolFixture.loadFirstRangeQuestionDict()
                    let data = try JSONSerialization.data(withJSONObject: dict, options: [])
                    let question = try JSONDecoder().decode(SurveyQuestion.self, from: data)

                    expect(question.questionType) == .range
                    expect(question.minimum) == 0
                    expect(question.maximum) == 6
                    // The fixture's first range question (id 4730) carries
                    // these endpoint labels — guard against accidental
                    // CodingKeys rename.
                    expect(question.minimumDisplay) == "Not at all bothered"
                    expect(question.maximumDisplay) == "Extremely bothered"
                }

                it("produces 7 ticks on the slider (was 6 before the fix)") {
                    let dict = try MenqolFixture.loadFirstRangeQuestionDict()
                    let data = try JSONSerialization.data(withJSONObject: dict, options: [])
                    let question = try JSONDecoder().decode(SurveyQuestion.self, from: data)
                    let delegate = CapturingSurveyQuestionDelegate()

                    let picker = SurveyRangePicker(surveyQuestion: question, delegate: delegate)

                    guard let slider = picker.testSlider else {
                        fail("SurveyRangePicker did not expose its private slider via Mirror")
                        return
                    }
                    expect(slider.maxCount) == 7
                }

                it("renders the min_display / max_display endpoint legends") {
                    let dict = try MenqolFixture.loadFirstRangeQuestionDict()
                    let data = try JSONSerialization.data(withJSONObject: dict, options: [])
                    let question = try JSONDecoder().decode(SurveyQuestion.self, from: data)
                    let delegate = CapturingSurveyQuestionDelegate()

                    let picker = SurveyRangePicker(surveyQuestion: question, delegate: delegate)
                    let labelTexts = picker.allLabelTexts()

                    expect(labelTexts).to(contain("Not at all bothered"))
                    expect(labelTexts).to(contain("Extremely bothered"))
                }
            }

            context("with a synthetic min=1, max=10 variant of the fixture") {
                it("produces 10 ticks on the slider") {
                    let question = try MenqolFixture.decodeRangeQuestion(
                        minimum: 1.0,
                        maximum: 10.0,
                        overridingId: "q-synthetic-1-10")
                    let delegate = CapturingSurveyQuestionDelegate()

                    let picker = SurveyRangePicker(surveyQuestion: question, delegate: delegate)

                    guard let slider = picker.testSlider else {
                        fail("SurveyRangePicker did not expose its private slider via Mirror")
                        return
                    }
                    expect(slider.maxCount) == 10
                }
            }

            context("delegate answer reporting with min != 0 (synthetic 3..8)") {
                it("reports minimum + sliderIndex (user-visible scale), not the raw slider index") {
                    let question = try MenqolFixture.decodeRangeQuestion(
                        minimum: 3.0,
                        maximum: 8.0,
                        overridingId: "q-synthetic-3-8")
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
