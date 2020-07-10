//
//  InternalAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation
import RxSwift
import RxSwiftExt

class InternalAnalyticsPlatform: AnalyticsPlatform {
    
    private let api: ApiGateway
    
    private let disposeBag = DisposeBag()
    
    init(api: ApiGateway) {
        self.api = api
    }
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .screeningQuizCompleted(let answers):
            self.sendAnwsers(answers: answers)
        }
    }
    
    // MARK: - Private Methods
    
    private func sendAnwsers(answers: [Answer]) {
        let context = ApiContext()
        let requests: [Single<()>] = answers.map { self.api
            .send(request: ApiRequest(serviceRequest: .sendAnswer(answer: $0, context: context)))
        }
        self.sendRequests(requests)
    }
    
    private func sendRequests(_ requests: [Single<()>], callingMethod: String = #function) {
        let requests: [Single<()>] = requests.map { request in
            request
                .do(onSuccess: { print("InternalAnalyticsPlatform - \(callingMethod) success.") })
                .do(onError: { print("InternalAnalyticsPlatform - \(callingMethod) failed. Error: \($0)") })
                .asObservable()
                .retry(.delayed(maxCount: 3, time: 10.0))
                .asSingle()
                .catchErrorJustReturn(())
        }
        Single<()>.zip(requests).subscribe().disposed(by: self.disposeBag)
    }
}
