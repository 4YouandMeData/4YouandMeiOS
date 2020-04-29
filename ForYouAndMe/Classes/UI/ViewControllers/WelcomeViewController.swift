//
//  WelcomeViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

public class WelcomeViewController: UIViewController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: Add Content to Welcome screen
        self.view.backgroundColor = UIColor.green
        
        let imageView = UIImageView()
        imageView.image = ImagePalette.image(withName: .testImage)
        self.view.addSubview(imageView)
        imageView.autoCenterInSuperview()
        
        let label = UILabel()
        label.text = "Test"
        label.font = FontPalette.font(withSize: 14.0)
        self.view.addSubview(label)
        label.autoAlignAxis(toSuperviewAxis: .vertical)
        label.autoPinEdge(toSuperviewSafeArea: .top)
    }
}
