//
//  ViewController.swift
//  ForYouAndMe
//
//  Created by LeonardoPasseri on 04/22/2020.
//  Copyright (c) 2020 LeonardoPasseri. All rights reserved.
//

import UIKit
import PureLayout

public class TestViewController: UIViewController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white
        
        let imageView = UIImageView()
        let bundle = Bundle(url: Bundle(for: Self.self).url(forResource: "ForYouAndMe", withExtension: "bundle")!)!
        if let bundleIdentifier = bundle.bundleIdentifier {
            print("TestViewController - Bundle Identifier: \(bundleIdentifier)")
        }
        let image = UIImage(named: "checkmark_dark", in: bundle, with: nil)
        if let image = image {
            imageView.image = image
            self.view.addSubview(imageView)
            imageView.autoCenterInSuperview()
        }
        
        let button = UIButton(type: .roundedRect)
        button.frame = CGRect(x: 20, y: 50, width: 100, height: 30)
        button.setTitle("Crash", for: [])
        button.addTarget(self, action: #selector(self.crashButtonTapped(_:)), for: .touchUpInside)
        self.view.addSubview(button)
    }
    
    @IBAction func crashButtonTapped(_ sender: AnyObject) {
        fatalError()
    }
}
