//
//  Permission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import RxSwift

enum PermissionError: Error {
    case missingPermissionDescription
}

enum PermissionImageName {
    
    static func iconName(for permission: Permission) -> String {
        switch permission {
            #if os(iOS)
        case .camera:
            return "camera_icon"
        case .photoLibrary:
            return "photo_library_icon"
        case .microphone:
            return "microphone_icon"
        case .calendar:
            return "calendar_icon"
        case .contacts:
            return "contacts_icon"
        case .reminders:
            return "reminders_icon"
        case .speech:
            return "speech_icon"
        case .locationAlwaysAndWhenInUse:
            return "Location Always"
        case .motion:
            return "motion_icon"
        case .mediaLibrary:
            return "media_library_icon"
        case .bluetooth:
            return "bluetooth_icon"
            #endif
        case .notification:
            return "notification_icon"
        case .locationWhenInUse:
            return "Location When Use"
        }
    }
}

enum PermissionsText {
    
    static func name(for permission: Permission) -> String {
        switch permission {
            #if os(iOS)
        case .camera:
            return "Camera"
        case .photoLibrary:
            return "Photo Library"
        case .microphone:
            return "Microphone"
        case .calendar:
            return "Calendar"
        case .contacts:
            return "Contacts"
        case .reminders:
            return "Reminders"
        case .speech:
            return "Speech"
        case .locationAlwaysAndWhenInUse:
            return "Location Always"
        case .motion:
            return "Motion"
        case .mediaLibrary:
            return "Media Library"
        case .bluetooth:
            return "Bluetooth"
            #endif
        case .notification:
            return "Notification"
        case .locationWhenInUse:
            return "Location When Use"
        }
    }
}

@objc public enum Permission: Int, CaseIterable {
    
    #if os(iOS)
    case camera = 0
    case photoLibrary = 1
    case microphone = 3
    case calendar = 4
    case contacts = 5
    case reminders = 6
    case speech = 7
    case locationAlwaysAndWhenInUse = 10
    case motion = 11
    case mediaLibrary = 12
    case bluetooth = 13
    #endif
    case notification = 2
    case locationWhenInUse = 9
    
    /**
     Check permission is allowed.
     */
    public var isAuthorized: Bool {
        return Permission.manager(for: self).isAuthorized
    }
    
    /**
     Check permission is denied. If permission not requested anytime returned `false`.
     */
    public var isDenied: Bool {
        return Permission.manager(for: self).isDenied
    }
    
    /**
     Check permission is not Determined.
     */
    public var isNotDetermined: Bool {
        return Permission.manager(for: self).isNotDetermined
    }
    
    /**
     Check permission is restricted. If permission not requested anytime returned `false`.
     */
    public var isRestricted: Bool {
        return Permission.manager(for: self).isRestricted
    }
    
    /**
     Request permission now
     */
    public func request() -> Single<()> {
        return Single.create { observer -> Disposable in
            let manager = Permission.manager(for: self)
            if let usageDescriptionKey = self.usageDescriptionKey,
                Bundle.main.object(forInfoDictionaryKey: usageDescriptionKey) == nil {
                print("Permissions Warning - \(usageDescriptionKey) for \(self.name) not found in Info.plist")
                observer(.failure(PermissionError.missingPermissionDescription))
            } else {
                manager.request(completion: { observer(.success(())) })
            }
            return Disposables.create()
        }
    }
    
    /**
     Key which should added in Info.plist file. If key not added, app can crash when request permission.
     Before request check if key added, if not - show warning in console. Without fatal error.
     */
    public var usageDescriptionKey: String? {
        switch self {
            #if os(iOS)
        case .camera:
            return "NSCameraUsageDescription"
        case .photoLibrary:
            return "NSPhotoLibraryUsageDescription"
        case .microphone:
            return "NSMicrophoneUsageDescription"
        case .calendar:
            return "NSCalendarsUsageDescription"
        case .contacts:
            return "NSContactsUsageDescription"
        case .reminders:
            return "NSRemindersUsageDescription"
        case .speech:
            return "NSSpeechRecognitionUsageDescription"
        case .locationAlwaysAndWhenInUse:
            return "NSLocationAlwaysAndWhenInUseUsageDescription"
        case .motion:
            return "NSMotionUsageDescription"
        case .mediaLibrary:
            return "NSAppleMusicUsageDescription"
        case .bluetooth:
            return "NSBluetoothAlwaysUsageDescription"
            #endif
        case .notification:
            return nil
        case .locationWhenInUse:
            return "NSLocationWhenInUseUsageDescription"
        }
    }
}

extension Permission {
    /**
     Permission worker. Implement base protocol `PermissionProtocol`, can request permission and check it state.
     */
    fileprivate static func manager(for permission: Permission) -> PermissionProtocol {
        switch permission {
            #if os(iOS)
        case .camera:
            return CameraPermission()
        case .photoLibrary:
            return PhotoLibraryPermission()
        case .microphone:
            return MicrophonePermission()
        case .calendar:
            return CalendarPermission()
        case .contacts:
            return ContactsPermission()
        case .reminders:
            return RemindersPermission()
        case .speech:
            return SpeechPermission()
        case .locationAlwaysAndWhenInUse:
            return LocationPermission(type: LocationPermission.LocationType.alwaysAndWhenInUse)
        case .motion:
            return MotionPermission()
        case .mediaLibrary:
            return MediaLibraryPermission()
        case .bluetooth:
            return BluetoothPermission()
            #endif
        case .notification:
            return NotificationPermission()
        case .locationWhenInUse:
            return LocationPermission(type: LocationPermission.LocationType.whenInUse)
        }
    }
    
    /**
     Description error about invalid installation.
     */
    fileprivate static func error(_ permission: Permission) -> String {
        return "Permissions - \(permission.name) not import. Problem NOT with usage description key."
    }
    
    /**
     Name of permission.
     */
    public var name: String {
        return PermissionsText.name(for: self)
    }
    
    public var iconName: String {
        return PermissionImageName.iconName(for: self)
    }
}

func getLocationAuthorized() -> Bool {
    let whenInUse: Permission = .locationWhenInUse
    let always: Permission = .locationAlwaysAndWhenInUse
    
    return whenInUse.isAuthorized || always.isAuthorized
}
