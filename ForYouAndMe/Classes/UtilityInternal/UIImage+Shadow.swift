//
//  UIImage+Shadow.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/12/24.
//

import UIKit

extension UIImage {
    /// Crea una nuova immagine con un'ombra applicata.
    ///
    /// - Parameters:
    ///   - shadowColor: Colore dell'ombra. Default: Nero.
    ///   - shadowOffset: Offset dell'ombra. Default: (0, 2).
    ///   - shadowBlur: Raggio di sfocatura dell'ombra. Default: 4.
    ///   - shadowOpacity: Opacità dell'ombra. Default: 0.3.
    /// - Returns: Una nuova UIImage con l'ombra applicata, oppure nil se qualcosa va storto.
    func withShadow(shadowColor: UIColor = .black,
                   shadowOffset: CGSize = CGSize(width: 0, height: 2),
                   shadowBlur: CGFloat = 4,
                   shadowOpacity: Float = 0.3) -> UIImage? {
        // Calcola le dimensioni dell'immagine finale, includendo l'ombra
        let contextSize = CGSize(width: self.size.width + shadowBlur * 2,
                                 height: self.size.height + shadowBlur * 2)
        
        // Inizia un contesto grafico
        UIGraphicsBeginImageContextWithOptions(contextSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Configura l'ombra
        context.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor.withAlphaComponent(CGFloat(shadowOpacity)).cgColor)
        
        // Disegna l'immagine al centro del contesto
        let imageOrigin = CGPoint(x: shadowBlur, y: shadowBlur)
        self.draw(at: imageOrigin)
        
        // Recupera l'immagine con l'ombra
        let imageWithShadow = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return imageWithShadow
    }
}
