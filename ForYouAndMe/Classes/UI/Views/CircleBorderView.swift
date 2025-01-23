//
//  CircleBorderView.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 23/01/25.
//

import UIKit

/// Una semplice UIView che disegna solo il bordo di un cerchio.
class CircleBorderView: UIView {
    
    /// Inizializzatore personalizzato
    /// - Parameters:
    ///   - frame: frame della vista
    ///   - color: colore del bordo
    ///   - borderWidth: spessore del bordo
    ///                  (usa 1 / UIScreen.main.scale per avere 1px fisico su Retina)
    init(frame: CGRect, color: UIColor, borderWidth: CGFloat) {
        super.init(frame: frame)
        
        // Sfondo trasparente
        self.backgroundColor = .clear
        
        // Impostazioni per il bordo
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = borderWidth
        
        self.layer.cornerRadius = frame.size.width / 2
        self.layer.masksToBounds = true
        
        self.layer.zPosition = 1
        
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
