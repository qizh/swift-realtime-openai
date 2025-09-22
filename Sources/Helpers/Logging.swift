//
//  Logging.swift
//  RealtimeAPI
//
//  Created by Serhii Shevchenko on 19.09.2025.
//  Copyright © 2025 Serhii Shevchenko. All rights reserved.
//

import Foundation
#if canImport(os.log)
import os.log
#endif

package struct Log {
	fileprivate static let subsystem = "net.qizh.RealtimeAPI"
	
	#if canImport(os.log)
	package static func create(category: String) -> Logger {
		Logger(subsystem: subsystem, category: category)
	}
	#else
	package static func create(category: String) -> PrintLogger {
		PrintLogger(subsystem: subsystem, category: category)
	}
	#endif
}

#if !canImport(os.log)

package enum OSLogType: Int {
	case debug = 0
	case info = 1
	case `default` = 2
	case error = 16
	case fault = 17
}

package typealias OSLogMessage = String

package struct OSLog {
	package let subsystem: String
	package let category: String
	package init(subsystem: String, category: String) {
		self.subsystem = subsystem
		self.category = category
	}
}

package struct PrintLogger: @unchecked Sendable {
	let subsystem: String
	let category: String

	package init(subsystem: String, category: String) {
		self.subsystem = subsystem
		self.category = category
	}

	package init() {
		self.subsystem = "default"
		self.category = "default"
	}

	package init(_ logObj: OSLog) {
		self.subsystem = logObj.subsystem
		self.category = logObj.category
	}

	@inline(__always) private func levelLabel(_ level: OSLogType) -> String {
		switch level {
		case .debug: 	"DEBUG"
		case .info: 	"INFO"
		case .default: 	"NOTICE"
		case .error: 	"ERROR"
		case .fault: 	"FAULT"
		}
	}

	@inline(__always) private func timestamp() -> String {
		let now = Date()
		let formatter = PrintLogger.dateFormatter
		return formatter.string(from: now)
	}

	private static let dateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "HH:mm:ss.SSS"
		return f
	}()

	@inline(__always) private func printLine(
		level: OSLogType,
		label: String? = nil,
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		let lvl = label ?? levelLabel(level)
		Swift.print("[\(timestamp())] [\(subsystem)/\(category)] [\(lvl)] \(message) (\(file):\(function):\(line))")
	}

	package func log(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .default, label: "NOTICE", message, file: file, function: function, line: line)
	}

	package func log(
		level: OSLogType,
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: level, message, file: file, function: function, line: line)
	}

	package func trace(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .debug, label: "TRACE", message, file: file, function: function, line: line)
	}

	package func debug(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .debug, message, file: file, function: function, line: line)
	}

	package func info(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .info, message, file: file, function: function, line: line)
	}

	package func notice(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .default, label: "NOTICE", message, file: file, function: function, line: line)
	}

	package func warning(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .error, label: "WARNING", message, file: file, function: function, line: line)
	}

	package func error(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .error, message, file: file, function: function, line: line)
	}

	package func critical(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .fault, label: "CRITICAL", message, file: file, function: function, line: line)
	}

	package func fault(
		_ message: OSLogMessage,
		file: StaticString = #fileID,
		function: StaticString = #function,
		line: UInt = #line
	) {
		printLine(level: .fault, label: "FAULT", message, file: file, function: function, line: line)
	}
}
#endif
