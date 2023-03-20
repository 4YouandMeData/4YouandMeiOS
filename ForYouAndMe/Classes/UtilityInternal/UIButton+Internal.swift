//
//  UIButton+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/03/23.
//

import Foundation

extension UIButton {
    
    func syncWithPhase(repository: Repository, templateImageName: TemplateImageName) {
        let image = ImagePalette.templateImage(withName: templateImageName, forPhaseType: repository.currentPhaseType)
        self.setImage(image, for: .normal)
    }
    
    func syncWithPhase(repository: Repository, imageName: ImageName) {
        let image = ImagePalette.image(withName: imageName, forPhaseType: repository.currentPhaseType)
        self.setImage(image, for: .normal)
    }
}
