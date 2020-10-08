//
//  CalendarPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import Foundation

import EventKit

struct CalendarPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.event) == .authorized
    }
    
    var isDenied: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.event) == .denied
    }
    
    var isNotDetermined: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.event) == .notDetermined
    }
    
    var isRestricted: Bool {
        return EKEventStore.authorizationStatus(for: EKEntityType.event) == .restricted
    }
    
    func request(completion: @escaping () -> Void?) {
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: EKEntityType.event, completion: { (_, _) in
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
