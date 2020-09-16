//
//  Permission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

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
//        case .locationAlwaysAndWhenInUse:
//            return "Location Always"
        case .motion:
            return "Motion"
        case .mediaLibrary:
            return "Media Library"
        case .bluetooth:
            return "Bluetooth"
            #endif
        case .notification:
            return "Notification"
//        case .locationWhenInUse:
//            return "Location When Use"
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
//    case locationAlwaysAndWhenInUse = 10
    case motion = 11
    case mediaLibrary = 12
    case bluetooth = 13
    #endif
    case notification = 2
//    case locationWhenInUse = 9
    
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
     Request permission now
     */
    public func request(completion: @escaping () -> Void) {
        let manager = Permission.manager(for: self)
        if let usageDescriptionKey = usageDescriptionKey {
            guard Bundle.main.object(forInfoDictionaryKey: usageDescriptionKey) != nil else {
                print("Permissions Warning - \(usageDescriptionKey) for \(name) not found in Info.plist")
                return
            }
        }
        manager.request(completion: { completion() })
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
            //        case .locationAlwaysAndWhenInUse:
            //            return "NSLocationAlwaysAndWhenInUseUsageDescription"
        case .motion:
            return "NSMotionUsageDescription"
        case .mediaLibrary:
            return "NSAppleMusicUsageDescription"
        case .bluetooth:
            return "NSBluetoothAlwaysUsageDescription"
            #endif
        case .notification:
            return nil
//        case .locationWhenInUse:
//            return "NSLocationWhenInUseUsageDescription"
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
            //        case .locationAlwaysAndWhenInUse:
            //            return LocationPermission(type: LocationPermission.LocationType.AlwaysAndWhenInUse)
        case .motion:
            return MotionPermission()
        case .mediaLibrary:
            return MediaLibraryPermission()
        case .bluetooth:
            return BluetoothPermission()
            #endif
        case .notification:
            return NotificationPermission()
            //        case .locationWhenInUse:
            //            return LocationPermission(type: LocationPermission.LocationType.WhenInUse)
        }
    }
    
    /**
     Description error about invalid installation.
     */
    fileprivate static func error(_ permission: Permission) -> String {
        return "Permissions - \(permission.name) not import. Problem NOT with usage description key. I recomend to see installation guide: https://youtu.be/1kR5HGVhJfk. More details in Readme: https://github.com/ivanvorobei/Permissions"
    }
    
    /**
     Name of permission.
     */
    public var name: String {
        return PermissionsText.name(for: self)
    }
}
