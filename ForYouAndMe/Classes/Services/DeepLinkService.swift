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
    func clearDeeplinkedTaskData()
    func getDeeplinkedUrl() -> URL?
    func clearDeeplinkedUrlData()
}
