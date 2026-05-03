//
//  FYAMLog.swift
//  ForYouAndMe
//
//  Forward-looking logging helper for new framework code. Routes through
//  `os.Logger` (visible in Console.app and Xcode) AND `JamLog` (captured
//  during a Jam recording — no-op otherwise).
//
//  Existing `print` / `debugPrint` call sites are intentionally left
//  alone so they keep showing up in Xcode's debug console; reach them
//  in Jam recordings via `mirrorPrintToJam: true` on `FYAMManager.startup`.
//

import Foundation
import JamLog
import os

public enum FYAMLog {

    private static let osLogger = os.Logger(subsystem: "com.4youandme.ios", category: "FYAM")

    public static func debug(_ msg: @autoclosure () -> String,
                             file: String = #fileID,
                             function: String = #function,
                             line: UInt = #line) {
        let m = msg()
        #if DEBUG
        osLogger.debug("\(m, privacy: .public)")
        #endif
        JamLog.debug(m, file: file, function: function, line: line)
    }

    public static func info(_ msg: @autoclosure () -> String,
                            file: String = #fileID,
                            function: String = #function,
                            line: UInt = #line) {
        let m = msg()
        osLogger.info("\(m, privacy: .public)")
        JamLog.info(m, file: file, function: function, line: line)
    }

    public static func warn(_ msg: @autoclosure () -> String,
                            file: String = #fileID,
                            function: String = #function,
                            line: UInt = #line) {
        let m = msg()
        osLogger.warning("\(m, privacy: .public)")
        JamLog.warn(m, file: file, function: function, line: line)
    }

    public static func error(_ msg: @autoclosure () -> String,
                             file: String = #fileID,
                             function: String = #function,
                             line: UInt = #line) {
        let m = msg()
        osLogger.error("\(m, privacy: .public)")
        JamLog.error(m, file: file, function: function, line: line)
    }
}
