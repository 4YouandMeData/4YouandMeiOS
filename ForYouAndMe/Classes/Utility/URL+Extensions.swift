//
//  URL+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/08/2020.
//

import Foundation

extension URL {
    
    /// Computed property to get the size of the item in bytes
    var sizeInBytes: UInt64 {
        do {
            let attributesOfFile = try FileManager.default.attributesOfItem(atPath: self.path)
            guard let filesize = attributesOfFile[FileAttributeKey.size] as? UInt64  else { return 0 }
            return filesize
        } catch {
            debugPrint("Failed to get the size of the file")
            return 0
        }
    }
    
    /// Method to disable iCloud syncing for the URL
    mutating func disableiCloudSync() {
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try self.setResourceValues(resourceValues)
        } catch {
            debugPrint("Failed to disable iCloud sync")
        }
    }
}
