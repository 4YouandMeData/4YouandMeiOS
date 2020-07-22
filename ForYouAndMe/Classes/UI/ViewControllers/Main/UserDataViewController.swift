//
//  UserDataViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/07/2020.
//

import Foundation

import UIKit

class UserDataViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
}
