//
//  ChartTapPayloadSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3613: locks down the `chartPointTapped` bridge parser. The tapped
//  moment must become the entry time on any device calendar/locale (S4), a
//  numeric chart id is accepted, a bad payload is rejected with a named reason
//  and never replaced by "now" (Q11), and the chart link + interval reach the
//  create bodies.
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class ChartTapPayloadSpec: QuickSpec {
    override class func spec() {

        let rome = TimeZone(identifier: "Europe/Rome")!
        let keys = ["datetime_ref", "interval", "diary_noteable_type", "diary_noteable_id"]

        func validBody() -> [String: Any] {
            return [
                "datetime_ref": "2026-09-05 00:00",
                "diary_noteable_type": "Chart",
                "diary_noteable_id": "42",
                "interval": "7d"
            ]
        }

        func instant(_ iso: String) -> Date {
            return ISO8601DateFormatter().date(from: iso)!
        }

        func parse(_ body: [String: Any]) -> Result<DiaryNoteItem, ChartTapPayloadError> {
            return DiaryNoteItem.fromChartTap(body, timeZone: rome)
        }

        func note(_ result: Result<DiaryNoteItem, ChartTapPayloadError>) -> DiaryNoteItem? {
            if case .success(let item) = result { return item }
            return nil
        }

        func error(_ result: Result<DiaryNoteItem, ChartTapPayloadError>) -> ChartTapPayloadError? {
            if case .failure(let error) = result { return error }
            return nil
        }

        describe("DiaryNoteItem.fromChartTap") {

            it("T1 builds the chart-linked note from an all-string body") {
                let item = note(parse(validBody()))
                expect(item).toNot(beNil())
                expect(item?.diaryNoteId).to(equal(instant("2026-09-04T22:00:00Z")))
                expect(item?.diaryNoteable?.id).to(equal("42"))
                expect(item?.diaryNoteable?.type).to(equal("Chart"))
                expect(item?.interval).to(equal("7d"))
            }

            it("T2 accepts a numeric diary_noteable_id") {
                var body = validBody()
                body["diary_noteable_id"] = NSNumber(value: 42)
                expect(note(parse(body))?.diaryNoteable?.id).to(equal("42"))
            }

            it("T3 rejects a body missing any of the four keys, naming the key") {
                for key in keys {
                    var body = validBody()
                    body.removeValue(forKey: key)
                    expect(error(parse(body))).to(equal(.missingField(key)), description: key)
                }
            }

            it("T4 treats an empty or blank value as missing") {
                for key in keys {
                    for blank in ["", "   "] {
                        var body = validBody()
                        body[key] = blank
                        expect(error(parse(body))).to(equal(.missingField(key)), description: "\(key)='\(blank)'")
                    }
                }
            }

            it("T5 accepts a number only for the chart id") {
                var body = validBody()
                body["datetime_ref"] = NSNumber(value: 1_725_487_200_000)
                expect(error(parse(body))).to(equal(.missingField("datetime_ref")))
            }

            it("T6 rejects malformed datetimes instead of substituting now") {
                for malformed in ["05/09/2026 00:00", "2026-09-05T00:00", "2026-13-05 00:00", "not a date"] {
                    var body = validBody()
                    body["datetime_ref"] = malformed
                    expect(error(parse(body))).to(equal(.unparsableDatetime), description: malformed)
                }
            }

            it("T15 rejects impossible or unpadded datetimes the formatter would roll over") {
                for malformed in ["2026-02-30 10:00", "2026-09-24 24:00", "2026-9-4 1:5"] {
                    var body = validBody()
                    body["datetime_ref"] = malformed
                    expect(error(parse(body))).to(equal(.unparsableDatetime), description: malformed)
                }
            }

            it("T16 rejects a JS boolean diary_noteable_id instead of reading it as 1") {
                for flag in [true, false] {
                    var body = validBody()
                    body["diary_noteable_id"] = NSNumber(value: flag)
                    expect(error(parse(body))).to(equal(.missingField("diary_noteable_id")), description: "\(flag)")
                }
            }

            it("T7 keeps the minutes of a 24h bucket") {
                var body = validBody()
                body["datetime_ref"] = "2026-09-05 14:15"
                expect(note(parse(body))?.diaryNoteId).to(equal(instant("2026-09-05T12:15:00Z")))
            }

            it("T8 uses whole-day midnight as is and never clamps a future value") {
                expect(note(parse(validBody()))?.diaryNoteId).to(equal(instant("2026-09-04T22:00:00Z")))
                var body = validBody()
                body["datetime_ref"] = "2099-01-01 10:00"
                expect(note(parse(body))?.diaryNoteId).to(equal(instant("2099-01-01T09:00:00Z")))
            }

            it("T9 passes the interval through opaque") {
                for interval in ["phase", "12M"] {
                    var body = validBody()
                    body["interval"] = interval
                    expect(note(parse(body))?.interval).to(equal(interval))
                }
            }

            it("T10 names each rejection for Telemetry") {
                expect(ChartTapPayloadError.missingField("interval").telemetryDomain)
                    .to(equal("chart_tap.missing_field.interval"))
                expect(ChartTapPayloadError.unparsableDatetime.telemetryDomain)
                    .to(equal("chart_tap.unparsable_datetime"))
            }
        }

        describe("DiaryNoteItem.chartDatetimeFormatter") {

            it("T11 pins POSIX locale, Gregorian calendar, the given zone and the chart format") {
                let formatter = DiaryNoteItem.chartDatetimeFormatter(timeZone: rome)
                expect(formatter.locale.identifier).to(equal("en_US_POSIX"))
                expect(formatter.calendar.identifier).to(equal(.gregorian))
                expect(formatter.timeZone).to(equal(rome))
                expect(formatter.dateFormat).to(equal("yyyy-MM-dd HH:mm"))
            }

            it("T12 reads the Gregorian year where a Thai-locale formatter would not") {
                var gregorian = Calendar(identifier: .gregorian)
                gregorian.timeZone = rome

                let thai = DateFormatter()
                thai.locale = Locale(identifier: "th_TH")
                thai.timeZone = rome
                thai.dateFormat = "yyyy-MM-dd HH:mm"
                let thaiYear = thai.date(from: "2026-09-05 00:00").map { gregorian.component(.year, from: $0) }
                expect(thaiYear).toNot(equal(2026))

                let parsed = note(parse(validBody()))?.diaryNoteId
                expect(parsed.map { gregorian.component(.year, from: $0) }).to(equal(2026))
            }
        }

        describe("create bodies built from a chart tap") {

            it("T13 doses send the chart link, interval and UTC time under diary_note") {
                guard let item = note(parse(validBody())) else { return fail("parse failed") }
                let body = unwrapDiaryNote(.sendDiaryNoteDoses(doseType: "bolus_dose",
                                                               date: item.diaryNoteId,
                                                               amount: 2,
                                                               fromChart: true,
                                                               diaryNote: item))
                expect(body?["diary_noteable_type"] as? String).to(equal("Chart"))
                expect(body?["diary_noteable_id"] as? String).to(equal("42"))
                expect(body?["interval"] as? String).to(equal("7d"))
                expect(body?["datetime_ref"] as? String).to(equal("2026-09-04T22:00:00Z"))
            }

            it("T14 text sends the chart link, interval and UTC time under diary_note") {
                guard let item = note(parse(validBody())) else { return fail("parse failed") }
                let body = unwrapDiaryNote(.sendDiaryNoteText(diaryItem: item, fromChart: true))
                expect(body?["diary_noteable_type"] as? String).to(equal("Chart"))
                expect(body?["diary_noteable_id"] as? String).to(equal("42"))
                expect(body?["interval"] as? String).to(equal("7d"))
                expect(body?["datetime_ref"] as? String).to(equal("2026-09-04T22:00:00Z"))
            }
        }
    }
}

// MARK: - Helpers

private func unwrapRequestParameters(_ task: Task) -> [String: Any]? {
    if case let .requestParameters(parameters, _) = task {
        return parameters
    }
    return nil
}

private func unwrapDiaryNote(_ service: DefaultService) -> [String: Any]? {
    return unwrapRequestParameters(service.task)?["diary_note"] as? [String: Any]
}
