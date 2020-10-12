//
//  DeepLinkService.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 12/10/2020.
//
import Foundation
import RxSwift

protocol DeeplinkService: class {
    func getDeeplinkedTaskId() -> String?
    func clearDeeplinkedTask()
    
    func createDeepLink(toActivity activity: Activity) -> Single<()>
    func createDeepLink(toSurvey survey: Survey) -> Single<()>
    func createDeepLink(toAlert alert: Alert) -> Single<()>
    func createDeepLink(toRewards rewards: Rewards) -> Single<()>
    func createDeepLink(toEducational educational: Educational) -> Single<()>
}
