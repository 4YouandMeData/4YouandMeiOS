//
//  RemindersPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import Foundation

import EventKit

struct RemindersPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.reminder) == .authorized
    }
    
    var isDenied: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.reminder) == .denied
    }
    
    var isNotDetermined: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.reminder) == .notDetermined
    }
    
    var isRestricted: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.reminder) == .restricted
    }
    
    func request(completion: @escaping () -> Void?) {
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: EKEntityType.reminder, completion: {
            (accessGranted: Bool, error: Error?) in
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
