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
    
    func request(completion: @escaping ()->()?) {
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: EKEntityType.event, completion: {
            (accessGranted: Bool, error: Error?) in
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
