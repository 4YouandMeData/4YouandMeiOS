//
//  Page+Wearable.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 09/07/2020.
//

import Foundation

extension Page {
    var wearablesSpecialLinkBehaviour: WearablesSpecialLinkBehaviour? {
        guard PageSpecialLinkType.app == self.specialLinkType else {
            return nil
        }
        guard let specialLinkBehaviourString = self.specialLinkValue?.split(separator: "_").first else {
            return nil
        }
        guard let specialLinkBehaviour = WearablesSpecialLinkBehaviour.allCases
            .first(where: { $0.keyword == specialLinkBehaviourString }) else {
            return nil
        }
        
        switch specialLinkBehaviour {
        case .download: return .download(app: self.wearablesSpecialLinkApp)
        case .open: return .open(app: self.wearablesSpecialLinkApp)
        }
    }
    
    var wearablesSpecialLinkApp: WearableApp? {
        guard let specialLinkValue = self.specialLinkValue,
            let specialLinkBehaviourString = self.specialLinkValue?.split(separator: "_").first else {
            return nil
        }
        
        let startIndex = specialLinkValue.startIndex
        let endIndex = specialLinkValue.index(startIndex, offsetBy: specialLinkBehaviourString.count + 1)
        let specialLinkAppString = specialLinkValue.replacingCharacters(in: startIndex..<endIndex, with: "")
        
        return WearableApp(rawValue: specialLinkAppString)
    }
}
