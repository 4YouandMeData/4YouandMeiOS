//
//  StdoutMirror.swift
//  ForYouAndMe
//
//  Internal helper that pipes process stdout/stderr into JamLog so that
//  every `print(...)` and `debugPrint(...)` (host app or framework) is
//  captured during a Jam recording, without altering Xcode console
//  behaviour.
//
//  Mechanism: dup the original stdout/stderr file descriptors so writes
//  still reach the original TTY (Xcode's debug console), then redirect
//  STDOUT_FILENO / STDERR_FILENO into a `pipe(2)`. A background
//  `DispatchSourceRead` reads each line off the pipe and forwards it
//  to `JamLog.debug` AND to the original FD — Xcode keeps showing the
//  output, and Jam captures it during a recording.
//
//  Intentionally opt-in (off by default) because installing the dup is
//  process-wide, mildly invasive, and not free per-print.
//

import Foundation
import JamLog

enum StdoutMirror {

    private static var installed = false
    private static var sources: [DispatchSourceRead] = []

    /// Installs the mirror. Idempotent — calling more than once is a no-op.
    /// Safe to call only from the main thread early in app launch.
    static func install() {
        guard !installed else { return }
        installed = true

        mirror(fd: STDOUT_FILENO)
        mirror(fd: STDERR_FILENO)
    }

    private static func mirror(fd: Int32) {
        // Duplicate the original FD so writes still reach the original TTY
        // (Xcode debug console / stderr).
        let originalFD = dup(fd)
        guard originalFD != -1 else { return }

        var pipeFDs: [Int32] = [-1, -1]
        let pipeResult = pipeFDs.withUnsafeMutableBufferPointer { buf -> Int32 in
            guard let baseAddress = buf.baseAddress else { return -1 }
            return pipe(baseAddress)
        }
        guard pipeResult == 0 else {
            close(originalFD)
            return
        }

        let readEnd = pipeFDs[0]
        let writeEnd = pipeFDs[1]

        // Redirect the original FD (stdout or stderr) into the write end of
        // the pipe. After this, every `print` / `debugPrint` lands in the pipe.
        guard dup2(writeEnd, fd) != -1 else {
            close(readEnd)
            close(writeEnd)
            close(originalFD)
            return
        }
        close(writeEnd)

        // Read the pipe asynchronously and forward each chunk both to JamLog
        // and back to the original FD so Xcode keeps showing the line.
        let queue = DispatchQueue(label: "com.4youandme.ios.stdoutmirror.fd\(fd)", qos: .utility)
        let source = DispatchSource.makeReadSource(fileDescriptor: readEnd, queue: queue)

        source.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = buffer.withUnsafeMutableBufferPointer { buf -> Int in
                guard let baseAddress = buf.baseAddress else { return 0 }
                return read(readEnd, baseAddress, buf.count)
            }
            guard bytesRead > 0 else { return }

            // Forward to the original FD so Xcode's console keeps showing it.
            _ = buffer.withUnsafeBufferPointer { buf -> Int in
                guard let baseAddress = buf.baseAddress else { return 0 }
                return write(originalFD, baseAddress, bytesRead)
            }

            // Forward to JamLog. Trim trailing newlines so each call is a
            // clean line in the recording.
            let data = Data(buffer.prefix(bytesRead))
            guard let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
                let trimmed = String(line)
                if !trimmed.isEmpty {
                    JamLog.debug(trimmed)
                }
            }
        }

        source.setCancelHandler {
            close(readEnd)
            close(originalFD)
        }

        source.resume()
        sources.append(source)
    }
}
