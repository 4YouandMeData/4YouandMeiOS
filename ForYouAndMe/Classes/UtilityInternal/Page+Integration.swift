//
//  Page+Integration.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 09/07/2020.
//

import Foundation

extension Page {
    var integrationSpecialLinkBehaviour: IntegrationSpecialLinkBehaviour? {
        guard PageSpecialLinkType.app == self.specialLinkType else {
            return nil
        }
        guard let specialLinkBehaviourString = self.specialLinkValue?.split(separator: "_").first else {
            return nil
        }
        guard let specialLinkBehaviour = IntegrationSpecialLinkBehaviour.allCases
            .first(where: { $0.keyword == specialLinkBehaviourString }) else {
            return nil
        }
        
        switch specialLinkBehaviour {
        case .download: return .download(app: self.integrationSpecialLinkApp)
        case .open: return .open(app: self.integrationSpecialLinkApp)
        case .active: return .active(app: self.integrationSpecialLinkApp)
        }
    }
    
    var integrationSpecialLinkApp: Integration? {
        guard let specialLinkValue = self.specialLinkValue,
            let specialLinkBehaviourString = self.specialLinkValue?.split(separator: "_").first else {
            return nil
        }
        
        let startIndex = specialLinkValue.startIndex
        let endIndex = specialLinkValue.index(startIndex, offsetBy: specialLinkBehaviourString.count + 1)
        let specialLinkAppString = specialLinkValue.replacingCharacters(in: startIndex..<endIndex, with: "")
        
        return IntegrationProvider.oAuthIntegration(withName: specialLinkAppString)
    }
}
