//
//  ExpiringValue.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/02/21.
//

import Foundation
import RxSwift

public class ExpiringValue<T: Equatable> {
    
    private(set) var value: T
    
    private let expiryTime: DispatchTimeInterval
    private let defaultValue: T
    
    private var disposeBag = DisposeBag()
    
    init(withDefaultValue defaultValue: T, expiryTime: DispatchTimeInterval) {
        self.defaultValue = defaultValue
        self.expiryTime = expiryTime
        self.value = defaultValue
    }
    
    // MARK: - Public Methods
    
    public func setValue(value: T, onExpiry: (() -> Void)?) {
        self.disposeBag = DisposeBag()
        self.value = value
        if self.value != self.defaultValue {
            Observable<Int>.timer(self.expiryTime, scheduler: MainScheduler.instance)
                .subscribe(onCompleted: { [weak self] in
                    guard let self = self else { return }
                    self.value = self.defaultValue
                    onExpiry?()
                }).disposed(by: self.disposeBag)
        }
    }
    
    public func resetValue() {
        self.disposeBag = DisposeBag()
        self.value = self.defaultValue
    }
}
