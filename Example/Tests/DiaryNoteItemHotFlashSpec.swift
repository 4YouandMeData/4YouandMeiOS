//
//  DiaryNoteItemHotFlashSpec.swift
//  ForYouAndMe_Tests
//
//  Specs covering the value types behind the Hot Flash flow:
//  - DiaryNoteItemType raw value contract
//  - DiaryNoteHotFlashData shape
//  - FlowVariant helpers
//
//  JSON decoding of `DiaryNoteItem` itself is *not* exercised here because the
//  production decoder is wired through Japx (JSON:API) and a custom DateValue
//  property wrapper, both of which need a lot of test scaffolding to drive.
//  Those tests belong in a follow-up dedicated to Japx-based decoding.
//

import Quick
import Nimble
import Foundation
@testable import ForYouAndMe

class DiaryNoteItemHotFlashSpec: QuickSpec {
    override func spec() {

        describe("DiaryNoteItemType.hotFlash") {
            it("maps to the server diary_type 'hot_flash_diary'") {
                expect(DiaryNoteItemType.hotFlash.rawValue) == "hot_flash_diary"
            }
        }

        describe("DiaryNoteHotFlashData") {
            it("captures date, fromChart, and the optional source diaryNote") {
                let date = Date(timeIntervalSince1970: 1_700_000_000)
                let note = DiaryNoteItem(
                    id: "src-1",
                    type: "diary_note",
                    diaryNoteId: date,
                    diaryNoteType: .hotFlash,
                    title: nil,
                    body: nil,
                    interval: nil
                )

                let standalone = DiaryNoteHotFlashData(date: date, fromChart: false, diaryNote: nil)
                expect(standalone.fromChart) == false
                expect(standalone.diaryNote).to(beNil())

                let fromChart = DiaryNoteHotFlashData(date: date, fromChart: true, diaryNote: note)
                expect(fromChart.fromChart) == true
                expect(fromChart.diaryNote?.id) == "src-1"
            }
        }

        describe("FlowVariant helpers") {
            it("reports isFromChart correctly") {
                let note = DiaryNoteItem(id: "x", type: "diary_note", diaryNoteId: Date(),
                                         diaryNoteType: .hotFlash, title: nil, body: nil, interval: nil)
                expect(FlowVariant.standalone.isFromChart) == false
                expect(FlowVariant.embeddedInNoticed.isFromChart) == false
                expect(FlowVariant.fromChart(diaryNote: note).isFromChart) == true
            }

            it("unwraps chartDiaryNote only for .fromChart") {
                let note = DiaryNoteItem(id: "y", type: "diary_note", diaryNoteId: Date(),
                                         diaryNoteType: .hotFlash, title: nil, body: nil, interval: nil)
                expect(FlowVariant.standalone.chartDiaryNote).to(beNil())
                expect(FlowVariant.embeddedInNoticed.chartDiaryNote).to(beNil())
                expect(FlowVariant.fromChart(diaryNote: note).chartDiaryNote?.id) == "y"
            }

            it("treats fromChart as standalone-like for UI copy") {
                let note = DiaryNoteItem(id: "z", type: "diary_note", diaryNoteId: Date(),
                                         diaryNoteType: .hotFlash, title: nil, body: nil, interval: nil)
                expect(FlowVariant.standalone.isStandaloneLike) == true
                expect(FlowVariant.fromChart(diaryNote: note).isStandaloneLike) == true
                expect(FlowVariant.embeddedInNoticed.isStandaloneLike) == false
            }
        }
    }
}
