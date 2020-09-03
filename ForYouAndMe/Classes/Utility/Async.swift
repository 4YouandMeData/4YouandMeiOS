//
//  Async.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/09/2020.
//

import Foundation

typealias DispatchCancelableClosure = (_ cancel: Bool) -> Void

class Async {
    
    @discardableResult
    static func mainQueueWithDelay(_ time: TimeInterval, closure: @escaping () -> Void) -> DispatchCancelableClosure? {
        func dispatch_later(_ clsr: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(
                deadline: DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: clsr)
        }
        
        var theClousre: (() -> Void)? = closure
        var cancelableClosure: DispatchCancelableClosure?
        
        let delayedClosure: DispatchCancelableClosure = { cancel in
            if let theClousre = theClousre {
                if cancel == false {
                    DispatchQueue.main.async(execute: theClousre)
                }
            }
            theClousre = nil
            cancelableClosure = nil
        }
        
        cancelableClosure = delayedClosure
        
        dispatch_later {
            if let delayedClosure = cancelableClosure {
                delayedClosure(false)
            }
        }
        return cancelableClosure
    }
    
    static func cancelDelayedExecution(_ closure: DispatchCancelableClosure?) {
        if let closure = closure {
            closure(true)
        }
    }
    
    static func mainQueue(_ closure: @escaping () -> Void) {
        DispatchQueue.main.async(execute: closure)
    }
}
