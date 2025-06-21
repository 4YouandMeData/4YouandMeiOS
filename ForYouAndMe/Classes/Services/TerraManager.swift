//
//  TerraManager.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 20/06/25.
//

import Foundation
import TerraiOS
import RxSwift

final class TerraManager: TerraService {

    private var terra: TerraiOS.TerraManager?
    private var isSDKInitialized = false

    var isInitialized: Bool { isSDKInitialized }
    
    func initialize() -> Single<()> {
        return Single.create { single in
            let refID = Services.shared.storageServices.user?.terraRefID ?? ""
            Terra.instance(devId: Constants.Network.TerraDevID, referenceId: refID) { [weak self] manager, error in
                if let error = error {
                    single(.failure(error))
                    return
                }
                
                guard let manager = manager else {
                    single(.failure(NSError(domain: "TerraService", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "TerraManager is nil"])))
                    return
                }
                
                self?.terra = manager
                self?.isSDKInitialized = true
                single(.success(()))
            }
            return Disposables.create()
        }
    }

    func connectToTerraIfAvailable() -> Single<Void> {
        return Services.shared.repository.refreshUser()
            .flatMap { user -> Single<String> in
                guard let refID = user.terraRefID ?? Services.shared.storageServices.user?.terraRefID else {
                    return .error(NSError(domain: "Terra", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing terraRefID"]))
                }
                return TerraManager.generateToken(referenceId: refID)
            }
            .flatMap { token in
                return Single.create { single in
                    self.terra?.initConnection(type: .APPLE_HEALTH,
                                               token: token,
                                               customReadTypes: [],
                                               schedulerOn: true) { success, error in
                        if let error = error {
                            single(.failure(error))
                            return
                        } else if !success {
                            single(.failure(NSError(domain: "Terra", code: -3,
                                                    userInfo: [NSLocalizedDescriptionKey: "InitConnection failed"])))
                            return
                        }
                        
                        single(.success(()))
                    }
                    return Disposables.create()
                }
            }
    }

    static func generateToken(referenceId: String) -> Single<String> {
        return Single.create { single in
            var request = URLRequest(url: URL(string: "https://api.tryterra.co/v2/auth/generateAuthToken")!)
            request.httpMethod = "POST"
            request.setValue("0NSwfZcN0x2gZpQRtFS3ftQi8B1Ve8di", forHTTPHeaderField: "x-api-key")
            request.setValue(Constants.Network.TerraDevID, forHTTPHeaderField: "dev-id")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["reference_id": referenceId]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    single(.failure(error))
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let token = json["token"] as? String else {
                    single(.failure(NSError(domain: "Terra", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])))
                    return
                }
                single(.success(token))
            }.resume()

            return Disposables.create()
        }
    }
}
