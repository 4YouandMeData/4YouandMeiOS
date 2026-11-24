//
//  SurveyQuestionScaleSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4488: on iOS 27 the scale slider never updated its label or answer,
//  because UIKit calls endTracking with a nil touch. The picker now reads the
//  slider through UIControl events and snaps to the allowed scale values;
//  touches off the thumb go through Slider's own pan and tap recognizers.
//

import Quick
import Nimble
@testable import ForYouAndMe

private final class ScaleAnswerDelegate: SurveyQuestionProtocol {
    private(set) var answers: [Int] = []
    func answerDidChange(_ surveyQuestion: SurveyQuestion, answer: Any) {
        if let answer = answer as? Int { self.answers.append(answer) }
    }
    func surveyQuestion(_ question: SurveyQuestion, didUpdateValidity isValid: Bool) {}
}

private func makeScaleQuestion(minimum: Int, maximum: Int, interval: Int?) throws -> SurveyQuestion {
    // Optional attributes are sent as explicit nulls, as the backend does; some decoders require the key.
    var dict: [String: Any] = ["image", "clickable_image", "max_click_points", "interval", "min_display", "max_display",
                               "min_label", "max_label", "placeholder", "max_characters", "min_date", "max_date",
                               "possible_answers", "targets"].reduce(into: [:]) { $0[$1] = NSNull() }
    dict.merge(["id": "q-scale", "type": "question", "question_type": "SurveyQuestionScale",
                "text": "Scale", "min": minimum, "max": maximum, "skippable": false]) { $1 }
    // The backend sends the interval as a string (StringToInt ignores a JSON number).
    if let interval = interval { dict["interval"] = String(interval) }
    let data = try JSONSerialization.data(withJSONObject: dict, options: [])
    return try JSONDecoder().decode(SurveyQuestion.self, from: data)
}

private extension SurveyQuestionScale {
    var testSlider: UISlider? {
        return Mirror(reflecting: self).children.first { $0.label == "slider" }?.value as? UISlider
    }
}

class SurveyQuestionScaleSpec: QuickSpec {
    override class func spec() {
        describe("SurveyQuestionScale.snappedValue") {
            it("rounds to the nearest step") {
                expect(SurveyQuestionScale.snappedValue(3.42, minimum: 0, maximum: 10, interval: 1)) == 3
                expect(SurveyQuestionScale.snappedValue(3.5, minimum: 0, maximum: 10, interval: 1)) == 4
            }
            it("clamps to the first and last value") {
                expect(SurveyQuestionScale.snappedValue(-2, minimum: 0, maximum: 10, interval: 1)) == 0
                expect(SurveyQuestionScale.snappedValue(12, minimum: 0, maximum: 10, interval: 1)) == 10
            }
            it("never exceeds the last reachable step when the interval does not divide the range") {
                expect(SurveyQuestionScale.snappedValue(10, minimum: 0, maximum: 10, interval: 3)) == 9
                expect(SurveyQuestionScale.snappedValue(4.4, minimum: 0, maximum: 10, interval: 3)) == 3
                expect(SurveyQuestionScale.snappedValue(4.6, minimum: 0, maximum: 10, interval: 3)) == 6
            }
            it("handles a negative minimum") {
                expect(SurveyQuestionScale.snappedValue(-3.4, minimum: -5, maximum: 5, interval: 1)) == -3
                expect(SurveyQuestionScale.snappedValue(-9, minimum: -5, maximum: 5, interval: 1)) == -5
            }
        }

        describe("Slider.trackValue") {
            // Track 3...303 wide with a 30pt thumb: the thumb centre travels from x = 18 to x = 288.
            let track = CGRect(x: 3, y: 0, width: 300, height: 10)
            it("maps the thumb's end positions to the ends of the range") {
                expect(Slider.trackValue(atX: 18, trackRect: track, thumbWidth: 30, minimum: 0, maximum: 10)) == 0
                expect(Slider.trackValue(atX: 288, trackRect: track, thumbWidth: 30, minimum: 0, maximum: 10)) == 10
            }
            it("maps the middle of the track to the middle of the range") {
                expect(Slider.trackValue(atX: 153, trackRect: track, thumbWidth: 30, minimum: 0, maximum: 10)) == 5
                expect(Slider.trackValue(atX: 153, trackRect: track, thumbWidth: 30, minimum: -5, maximum: 5)) == 0
            }
            it("clamps positions beyond the thumb's travel") {
                expect(Slider.trackValue(atX: 0, trackRect: track, thumbWidth: 30, minimum: 1, maximum: 7)) == 1
                expect(Slider.trackValue(atX: 400, trackRect: track, thumbWidth: 30, minimum: 1, maximum: 7)) == 7
            }
        }

        describe("Slider.isHorizontalPan") {
            it("begins for horizontal and mostly horizontal pans") {
                expect(Slider.isHorizontalPan(velocity: CGPoint(x: 300, y: 0))) == true
                expect(Slider.isHorizontalPan(velocity: CGPoint(x: -300, y: 120))) == true
            }
            it("leaves vertical and diagonal pans to the scroll view") {
                expect(Slider.isHorizontalPan(velocity: CGPoint(x: 0, y: -300))) == false
                expect(Slider.isHorizontalPan(velocity: CGPoint(x: 120, y: -300))) == false
                expect(Slider.isHorizontalPan(velocity: CGPoint(x: 200, y: 200))) == false
            }
        }

        describe("SurveyQuestionScale slider wiring") {
            it("answers the minimum when untouched") {
                let delegate = ScaleAnswerDelegate()
                _ = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 1, maximum: 7, interval: nil),
                                        delegate: delegate)
                expect(delegate.answers) == [1]
            }
            it("answers and snaps the thumb on a .valueChanged released between steps") {
                let delegate = ScaleAnswerDelegate()
                let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 0, maximum: 10, interval: nil),
                                                delegate: delegate)
                guard let slider = scale.testSlider else { return fail("slider not found") }
                slider.value = 3.42
                slider.sendActions(for: .valueChanged)
                expect(delegate.answers) == [0, 3]
                expect(slider.value) == 3
            }
            it("answers and snaps the thumb on release events") {
                for event: UIControl.Event in [.touchUpInside, .touchUpOutside, .touchCancel] {
                    let delegate = ScaleAnswerDelegate()
                    let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 0, maximum: 10, interval: nil),
                                                    delegate: delegate)
                    guard let slider = scale.testSlider else { return fail("slider not found") }
                    slider.value = 3.42
                    slider.sendActions(for: event)
                    expect(delegate.answers) == [0, 3]
                    expect(slider.value) == 3
                }
            }
            it("moves one value per VoiceOver increment or decrement, within the range") {
                let delegate = ScaleAnswerDelegate()
                let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 1, maximum: 5, interval: nil),
                                                delegate: delegate)
                guard let slider = scale.testSlider else { return fail("slider not found") }
                slider.accessibilityIncrement()
                expect(delegate.answers) == [1, 2]
                expect(slider.value) == 2
                slider.accessibilityDecrement()
                slider.accessibilityDecrement()
                expect(delegate.answers) == [1, 2, 1]
                expect(slider.value) == 1
            }
            it("moves one interval per VoiceOver increment and stops at the last reachable step") {
                let delegate = ScaleAnswerDelegate()
                let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 0, maximum: 10, interval: 3),
                                                delegate: delegate)
                guard let slider = scale.testSlider else { return fail("slider not found") }
                (0..<4).forEach { _ in slider.accessibilityIncrement() }
                expect(delegate.answers) == [0, 3, 6, 9]
                expect(slider.value) == 9
            }
            it("handles touches off the thumb with the slider's own pan and tap recognizers") {
                let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 0, maximum: 10, interval: nil),
                                                delegate: ScaleAnswerDelegate())
                guard let slider = scale.testSlider else { return fail("slider not found") }
                let ownRecognizers = (slider.gestureRecognizers ?? []).filter { $0.delegate === slider }
                expect(ownRecognizers.contains { $0 is UIPanGestureRecognizer }) == true
                expect(ownRecognizers.contains { $0 is UITapGestureRecognizer }) == true
            }
            it("does not begin the track pan without horizontal motion, so vertical scrolls reach the page") {
                let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 0, maximum: 10, interval: nil),
                                                delegate: ScaleAnswerDelegate())
                guard let slider = scale.testSlider,
                      let pan = slider.gestureRecognizers?.first(where: { $0 is UIPanGestureRecognizer && $0.delegate === slider }) else {
                    return fail("slider pan not found")
                }
                expect(slider.gestureRecognizerShouldBegin(pan)) == false
            }
            it("answers and snaps when a track gesture moves the slider") {
                let delegate = ScaleAnswerDelegate()
                let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 0, maximum: 10, interval: nil),
                                                delegate: delegate)
                guard let slider = scale.testSlider as? Slider,
                      let tap = slider.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer && $0.delegate === slider }) else {
                    return fail("slider tap not found")
                }
                slider.value = 10
                slider.sendActions(for: .valueChanged)
                // An untouched recognizer reports its location at the slider's origin, i.e. the start of the track.
                slider.trackGesture(tap)
                expect(delegate.answers) == [0, 10, 0]
                expect(slider.value) == 0
            }
            it("ends on the last reachable step for 0-10 step 3") {
                let delegate = ScaleAnswerDelegate()
                let scale = SurveyQuestionScale(surveyQuestion: try makeScaleQuestion(minimum: 0, maximum: 10, interval: 3),
                                                delegate: delegate)
                guard let slider = scale.testSlider else { return fail("slider not found") }
                expect(slider.maximumValue) == 9
                slider.value = slider.maximumValue
                slider.sendActions(for: .valueChanged)
                expect(delegate.answers) == [0, 9]
            }
        }
    }
}
