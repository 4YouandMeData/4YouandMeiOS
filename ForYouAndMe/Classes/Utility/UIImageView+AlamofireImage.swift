//
//  UIImageView+AlamofireImage.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 13/04/22.
//

import Foundation
import AlamofireImage

public extension UIImageView {
    func loadAsyncImage(withURL url:URL?, placeHolderImage: UIImage?, targetSize: CGSize?, blurRadius: UInt? = nil){
        if let url = url {
            var targetSize = targetSize
            if targetSize == CGSize.zero {
                targetSize = nil
            }
            self.af.setImage(withURL: url, placeholderImage: placeHolderImage, imageTransition:.crossDissolve(0.2))
        } else {
            self.image = placeHolderImage
        }
    }
}
