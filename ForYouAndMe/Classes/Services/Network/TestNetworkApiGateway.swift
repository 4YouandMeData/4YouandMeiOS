//
//  TestNetworkApiGateway.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Moya

class TestNetworkApiGateway: NetworkApiGateway {
    
    override func setupDefaultProvider() {
        if Constants.Test.NetworkStubsDelay > 0.0 {
            // Delayed responses (to test progress HUD, for example, or other UI tests)
            setupDelayedStub(delay: Constants.Test.NetworkStubsDelay)
        } else {
            // Immediate stubs for unit tests
            setupImmediateStub()
        }
    }
    
    private func setupImmediateStub() {
        defaultProvider = MoyaProvider(stubClosure: MoyaProvider.immediatelyStub)
    }
    
    private func setupDelayedStub(delay: TimeInterval) {
        defaultProvider = MoyaProvider(stubClosure: MoyaProvider.delayedStub(delay),
                                       plugins: [self.loggerPlugin])
    }
}
