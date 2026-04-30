//
//  DiaryNotesEndpointPathSpec.swift
//  ForYouAndMe_Tests
//
//  Locks down the v1/v2 split per the BE contract:
//   * create/update -> v2
//   * index/show/delete -> v1
//

import Quick
import Nimble
@testable import ForYouAndMe

class DiaryNotesEndpointPathSpec: QuickSpec {
    override class func spec() {

        let studyId = "studyXYZ"

        func makeMenstrualData() -> DiaryNoteMenstrualData {
            DiaryNoteMenstrualData(
                date: Date(timeIntervalSince1970: 1_750_000_000),
                flowAmount: .light,
                periodRelated: .yes,
                periodRelatedExplanation: nil,
                note: nil,
                fromChart: false,
                diaryNote: nil
            )
        }

        func makeEatenData() -> DiaryNoteEatenData {
            DiaryNoteEatenData(
                date: Date(timeIntervalSince1970: 1_750_000_000),
                mealType: "breakfast",
                quantity: "small",
                significantNutrition: false,
                canSpecifyCalories: nil,
                caloriesValue: nil,
                carbsGrams: nil,
                fromChart: false,
                diaryNote: nil
            )
        }

        func makeHotFlashData() -> DiaryNoteHotFlashData {
            DiaryNoteHotFlashData(date: Date(), fromChart: false, diaryNote: nil)
        }

        func makeWeNoticedItem() -> DiaryNoteWeHaveNoticedItem {
            DiaryNoteWeHaveNoticedItem(
                diaryType: .weNoticed,
                dosesData: nil,
                foodData: nil,
                diaryDate: Date(),
                answeredActivity: nil,
                answeredStress: nil,
                oldValue: 0,
                oldValueRetrievedAt: Date(),
                currentValue: 0,
                currentValueRetrievedAt: Date()
            )
        }

        func makeDiaryNote() -> DiaryNoteItem {
            DiaryNoteItem(
                id: "abc",
                type: "diary_note",
                diaryNoteId: Date(),
                diaryNoteType: .text,
                title: "T",
                body: "B",
                interval: nil
            )
        }

        let audioFile = DiaryNoteFile(data: Data(), fileExtension: .m4a)
        let videoFile = DiaryNoteFile(data: Data(), fileExtension: .mp4)

        describe("DefaultService.getPath(forStudyId:) — diary note endpoints") {

            // MARK: - v2 (create / update)
            it("uses v2 for sendDiaryNoteText") {
                let path = DefaultService.sendDiaryNoteText(diaryItem: makeDiaryNote(), fromChart: false)
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for sendDiaryNoteAudio") {
                let path = DefaultService
                    .sendDiaryNoteAudio(noteId: makeDiaryNote(), attachment: audioFile, fromChart: false)
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for sendDiaryNoteVideo") {
                let path = DefaultService
                    .sendDiaryNoteVideo(noteId: makeDiaryNote(), attachment: videoFile)
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for sendDiaryNoteEaten") {
                let path = DefaultService.sendDiaryNoteEaten(data: makeEatenData())
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for sendDiaryNoteDoses") {
                let path = DefaultService.sendDiaryNoteDoses(
                    doseType: "x", date: Date(), amount: 1.0, fromChart: false, diaryNote: nil
                ).getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for sendCombinedDiaryNote") {
                let path = DefaultService.sendCombinedDiaryNote(diaryNote: makeWeNoticedItem())
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for sendDiaryNoteHotFlash") {
                let path = DefaultService.sendDiaryNoteHotFlash(data: makeHotFlashData())
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for sendDiaryNoteMenstrual") {
                let path = DefaultService.sendDiaryNoteMenstrual(data: makeMenstrualData())
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes"))
            }

            it("uses v2 for updateDiaryNoteText") {
                let path = DefaultService.updateDiaryNoteText(diaryItem: makeDiaryNote())
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v2/diary_notes/abc"))
            }

            // MARK: - v1 (index / show / delete)
            it("keeps v1 for getDiaryNotes (index)") {
                let path = DefaultService.getDiaryNotes(diaryNote: nil, fromChart: false)
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v1/diary_notes"))
            }

            it("keeps v1 for getDiaryNoteText (show)") {
                let path = DefaultService.getDiaryNoteText(noteId: "xyz")
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v1/diary_notes/xyz"))
            }

            it("keeps v1 for getDiaryNoteAudio (show)") {
                let path = DefaultService.getDiaryNoteAudio(noteId: "xyz")
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v1/diary_notes/xyz"))
            }

            it("keeps v1 for deleteDiaryNote") {
                let path = DefaultService.deleteDiaryNote(noteId: "xyz")
                    .getPath(forStudyId: studyId)
                expect(path).to(equal("v1/diary_notes/xyz"))
            }
        }
    }
}
