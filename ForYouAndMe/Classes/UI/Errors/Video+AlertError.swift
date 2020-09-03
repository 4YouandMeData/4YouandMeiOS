//
//  Video+AlertError.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/09/2020.
//

import Foundation

extension CaptureSessionError: AlertError {
    var errorDescription: String? {
        return StringsProvider.string(forKey: .errorMessageDefault)
    }
}

extension CaptureOutputError: AlertError {
    var errorDescription: String? {
        return StringsProvider.string(forKey: .errorMessageDefault)
    }
}

extension VideoMergingError: AlertError {
    var errorDescription: String? {
        return StringsProvider.string(forKey: .errorMessageDefault)
    }
}
