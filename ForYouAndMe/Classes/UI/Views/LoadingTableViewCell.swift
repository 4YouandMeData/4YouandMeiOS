//
//  LoadingTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/11/20.
//

import UIKit

class LoadingTableViewCell: UITableViewCell {
    
    private let activityIndicator = UIActivityIndicatorView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .clear
        
        self.contentView.addSubview(self.activityIndicator)
        self.activityIndicator.autoCenterInSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // StartAnimating doesn't work if called in init,
        // maybe because it's automatically stopped when the cell is pooled
        self.activityIndicator.startAnimating()
    }
}
