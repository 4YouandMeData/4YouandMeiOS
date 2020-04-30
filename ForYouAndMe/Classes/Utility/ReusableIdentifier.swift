//
//  ReusableIdentifier.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

public protocol ReusableIdentifier: AnyObject {
    static var identifier: String { get }
}

public extension ReusableIdentifier {
    static var identifier: String {
        return String(describing: self.self)
    }
}

extension UITableViewCell: ReusableIdentifier { }
extension UICollectionReusableView: ReusableIdentifier {}
extension UITableViewHeaderFooterView: ReusableIdentifier {}

public extension UICollectionView {
    func register(_ cellClass: UICollectionViewCell.Type) {
        register(cellClass, forCellWithReuseIdentifier: cellClass.identifier)
    }
    
    func dequeueReusableCell<T: UICollectionViewCell>(ofType type: T.Type,
                                                      forIndexPath indexPath: IndexPath) -> T? {
        return dequeueReusableCell(withReuseIdentifier: (type as ReusableIdentifier.Type).identifier,
                                   for: indexPath) as? T
    }
    
    func register(_ viewClass: UICollectionReusableView.Type,
                  forSupplementaryViewOfKind kind: String) {
        register(viewClass, forSupplementaryViewOfKind: kind,
                 withReuseIdentifier: viewClass.identifier)
    }
    
    func dequeueReusableSupplementaryView<T: UICollectionReusableView>(ofType type: T.Type,
                                                                       forKind kind: String,
                                                                       forIndexPath indexPath: IndexPath) -> T? {
        return dequeueReusableSupplementaryView(ofKind: kind,
                                                withReuseIdentifier: (type as ReusableIdentifier.Type).identifier,
                                                for: indexPath) as? T
    }
}

public extension UITableView {
    func registerCellsWithClass(_ cellClass: UITableViewCell.Type) {
        register(cellClass, forCellReuseIdentifier: cellClass.identifier)
    }
    
    func registerHeaderFooterViewWithClass(_ viewClass: UITableViewHeaderFooterView.Type) {
        register(viewClass, forHeaderFooterViewReuseIdentifier: viewClass.identifier)
    }
    
    func dequeueReusableCellOfType<T: UITableViewCell>(type: T.Type,
                                                       forIndexPath indexPath: IndexPath) -> T? {
        return dequeueReusableCell(withIdentifier: (type as ReusableIdentifier.Type).identifier,
                                   for: indexPath) as? T
    }
    
    func dequeueReusableHeaderFooterViewOfType<T: UITableViewHeaderFooterView>(type: T.Type) -> T? {
        return dequeueReusableHeaderFooterView(withIdentifier: (type as ReusableIdentifier.Type).identifier) as? T
    }
}
