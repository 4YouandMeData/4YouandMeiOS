//
//  UIImageView+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/03/23.
//

import Foundation

extension UIImageView {
    
    func syncWithPhase(repository: Repository, templateImageName: TemplateImageName) {
        self.image = ImagePalette.templateImage(withName: templateImageName, forPhaseType: repository.currentPhaseType)
    }
    
    func syncWithPhase(repository: Repository, imageName: ImageName) {
        self.image = ImagePalette.image(withName: imageName, forPhaseType: repository.currentPhaseType)
    }
}
