//
//  ContactsPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import Contacts
import AddressBook

struct ContactsPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        if #available(iOS 9.0, *) {
            return CNContactStore.authorizationStatus(for: .contacts) == .authorized
        } else {
            return ABAddressBookGetAuthorizationStatus() == .authorized
        }
    }
    
    var isDenied: Bool {
        if #available(iOS 9.0, *) {
            return CNContactStore.authorizationStatus(for: .contacts) == .denied
        } else {
            return ABAddressBookGetAuthorizationStatus() == .denied
        }
    }
    
    var isNotDetermined: Bool {
        if #available(iOS 9.0, *) {
            return CNContactStore.authorizationStatus(for: .contacts) == .notDetermined
        } else {
            return ABAddressBookGetAuthorizationStatus() == .notDetermined
        }
    }
    
    var isRestricted: Bool {
        if #available(iOS 9.0, *) {
            return CNContactStore.authorizationStatus(for: .contacts) == .restricted
        } else {
            return ABAddressBookGetAuthorizationStatus() == .restricted
        }
    }
    
    func request(completion: @escaping () -> Void?) {
        if #available(iOS 9.0, *) {
            let store = CNContactStore()
            store.requestAccess(for: .contacts, completionHandler: { (_, _) in
                DispatchQueue.main.async {
                    completion()
                }
            })
        } else {
            let addressBookRef: ABAddressBook = ABAddressBookCreateWithOptions(nil, nil).takeRetainedValue()
            ABAddressBookRequestAccessWithCompletion(addressBookRef) { (_, _) in
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
}
