//
//  PermissionProtocol.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

/**
 Requerid methods and property for permission class.
 */
protocol PermissionProtocol {
    
    /**
     Returned if permission authorized.
     */
    var isAuthorized: Bool { get }
    
    /**
     Return if permission denied.
     */
    var isDenied: Bool { get }
    
    /**
     Request permission.
     
     - parameter complection: Call after permission request complete.
     */
    func request(completion: @escaping () -> Void?)
}
