//
//  Activity+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/10/2020.
//

import Foundation

extension Activity {
    var pagedSectionData: PagedSectionData {
        return PagedSectionData(welcomePage: self.welcomePage,
                                successPage: self.successPage,
                                pages: self.pages)
    }
}
