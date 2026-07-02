//
//  SpatialSpanMemoryTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3484: verifies SpatialSpanMemoryTask.getNetworkResultData serializes an
//  ORKSpatialSpanMemoryResult into the backend contract — top-level score /
//  number_of_games / number_of_failures / start_time / end_time, and a
//  game_records array with sequence / game_size / game_status (string) / score /
//  touch_samples (timestamp / target_index / location{x,y} / correct).
//

import Quick
import Nimble
import ResearchKit
@testable import ForYouAndMe

class SpatialSpanMemoryTaskSpec: QuickSpec {
    override class func spec() {
        describe("SpatialSpanMemoryTask.getNetworkResultData") {

            let startDate = Date(timeIntervalSince1970: 1_750_000_000)
            let endDate = Date(timeIntervalSince1970: 1_750_000_042)

            func makeTouchSample(timestamp: TimeInterval,
                                 targetIndex: Int,
                                 location: CGPoint,
                                 correct: Bool) -> ORKSpatialSpanMemoryGameTouchSample {
                let sample = ORKSpatialSpanMemoryGameTouchSample()
                sample.timestamp = timestamp
                sample.targetIndex = targetIndex
                sample.location = location
                sample.isCorrect = correct
                return sample
            }

            func makeRecord(sequence: [Int],
                            gameSize: Int,
                            gameStatus: ORKSpatialSpanMemoryGameStatus,
                            score: Int,
                            touchSamples: [ORKSpatialSpanMemoryGameTouchSample]) -> ORKSpatialSpanMemoryGameRecord {
                let record = ORKSpatialSpanMemoryGameRecord()
                record.sequence = sequence.map { NSNumber(value: $0) }
                record.gameSize = gameSize
                record.gameStatus = gameStatus
                record.score = score
                record.touchSamples = touchSamples
                return record
            }

            func makeTaskResult() -> ORKTaskResult {
                let record1 = makeRecord(
                    sequence: [0, 2, 1],
                    gameSize: 3,
                    gameStatus: .success,
                    score: 10,
                    touchSamples: [
                        makeTouchSample(timestamp: 1.5, targetIndex: 0, location: CGPoint(x: 10, y: 20), correct: true),
                        makeTouchSample(timestamp: 2.5, targetIndex: 2, location: CGPoint(x: 30, y: 40), correct: true)
                    ]
                )
                let record2 = makeRecord(
                    sequence: [1, 3, 0, 2],
                    gameSize: 4,
                    gameStatus: .failure,
                    score: 4,
                    touchSamples: [
                        makeTouchSample(timestamp: 3.0, targetIndex: -1, location: CGPoint(x: 50, y: 60), correct: false)
                    ]
                )

                let memoryResult = ORKSpatialSpanMemoryResult(identifier: ORKSpatialSpanMemoryStepIdentifier)
                memoryResult.score = 14
                memoryResult.numberOfGames = 2
                memoryResult.numberOfFailures = 1
                memoryResult.gameRecords = [record1, record2]

                let stepResult = ORKStepResult(identifier: ORKSpatialSpanMemoryStepIdentifier)
                stepResult.results = [memoryResult]

                let taskResult = ORKTaskResult(identifier: "spatial_span_memory")
                taskResult.startDate = startDate
                taskResult.endDate = endDate
                taskResult.results = [stepResult]
                return taskResult
            }

            it("serializes the top-level score, game counts and timestamps") {
                let result = SpatialSpanMemoryTask.getNetworkResultData(taskResult: makeTaskResult())
                let data = result?.data

                expect(data?["score"] as? Int).to(equal(14))
                expect(data?["number_of_games"] as? Int).to(equal(2))
                expect(data?["number_of_failures"] as? Int).to(equal(1))
                expect(data?["start_time"] as? Double).to(equal(startDate.timeIntervalSince1970))
                expect(data?["end_time"] as? Double).to(equal(endDate.timeIntervalSince1970))
                expect(data?["task_id"]).to(beNil())
            }

            it("serializes the game_records array with sequence, size, status string and score") {
                let result = SpatialSpanMemoryTask.getNetworkResultData(taskResult: makeTaskResult())
                let gameRecords = result?.data["game_records"] as? [[String: Any]]

                expect(gameRecords?.count).to(equal(2))

                let first = gameRecords?.first
                expect(first?["sequence"] as? [Int]).to(equal([0, 2, 1]))
                expect(first?["game_size"] as? Int).to(equal(3))
                expect(first?["game_status"] as? String).to(equal("success"))
                expect(first?["score"] as? Int).to(equal(10))

                let second = gameRecords?.last
                expect(second?["game_status"] as? String).to(equal("failure"))
                expect(second?["game_size"] as? Int).to(equal(4))
                expect(second?["sequence"] as? [Int]).to(equal([1, 3, 0, 2]))
            }

            it("serializes touch_samples with timestamp, target_index, location and correct") {
                let result = SpatialSpanMemoryTask.getNetworkResultData(taskResult: makeTaskResult())
                let gameRecords = result?.data["game_records"] as? [[String: Any]]
                let touchSamples = gameRecords?.first?["touch_samples"] as? [[String: Any]]

                expect(touchSamples?.count).to(equal(2))

                let firstSample = touchSamples?.first
                expect(firstSample?["timestamp"] as? Double).to(equal(1.5))
                expect(firstSample?["target_index"] as? Int).to(equal(0))
                expect(firstSample?["correct"] as? Bool).to(beTrue())

                let location = firstSample?["location"] as? [String: CGFloat]
                expect(location?["x"]).to(equal(10))
                expect(location?["y"]).to(equal(20))

                let failingSample = (gameRecords?.last?["touch_samples"] as? [[String: Any]])?.first
                expect(failingSample?["target_index"] as? Int).to(equal(-1))
                expect(failingSample?["correct"] as? Bool).to(beFalse())
            }
        }
    }
}
