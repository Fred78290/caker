//  BootCommand.swift
//  CakedLib
//
//  Parses Packer-style boot_command strings (e.g. "<wait30s>italiano<esc>english<enter>")
//  into a sequence of platform-agnostic steps. No AppKit/Virtualization dependency here —
//  the driver that turns these into actual input events lives in CakedLib.
//

import Foundation
import GRPCLib

public enum KeyToken: Equatable, Sendable {
	case enter
	case esc
	case tab
	case spacebar
	case backspace
	case delete
	case insert
	case home
	case end
	case pageUp
	case pageDown
	case up
	case down
	case left
	case right
	case function(Int)
}

public enum ModifierToken: Equatable, Sendable {
	case leftShift
	case rightShift
	case leftAlt
	case rightAlt
	case leftCtrl
	case rightCtrl
	case leftSuper
	case rightSuper
	case function
}

public typealias BootCommandSteps = [BootCommandStep]

public struct BootCommandStep: Equatable, Sendable {
	public enum Step: Equatable, Sendable {
		public static func == (lhs: Step, rhs: Step) -> Bool {
			lhs.description == rhs.description
		}

		public var description: String {
			switch self {
			case .wait(let seconds): return "wait \(seconds)s"
			case .type(let text): return "type \(text)"
			case .press(let key, let repeated): return "press \(key) x\(repeated)"
			case .modifierOn(let modifier): return "modifier on \(modifier)"
			case .modifierOff(let modifier): return "modifier off \(modifier)"
			case .click(let point): return "click \(point)"
			case .clickText(let text, let timeout): return "clickText \(text) x\(timeout)s"
			case .locate(let text, let timeout): return "locate \(text) x\(timeout)s"
			case .keyboard(let translator): return "keyboard \(translator)"
			}
		}

		case wait(TimeInterval)
		case type(String)
		case press(KeyToken, repeated: Int = 1)
		case modifierOn(ModifierToken)
		case modifierOff(ModifierToken)
		case click(CGPoint)
		case clickText(String, timeout: TimeInterval)
		case locate(String, timeout: TimeInterval)
		case keyboard(any KeyLayoutTranslator)
	}

	public let title: String
	public let steps: [Step]

	public init(command: PackerLiteTemplate.Command) async throws {
		var steps: [Step] = []
		var literal = ""
		var remainder = Substring(command.commands.joined())

		func flushLiteral() {
			if literal.isEmpty == false {
				steps.append(.type(literal))
				literal = ""
			}
		}

		while let character = remainder.first {
			if character == "<" {
				guard let closeIndex = remainder.firstIndex(of: ">") else {
					throw BootCommandParseError.unterminatedToken(String(remainder))
				}

				let tokenBody = String(remainder[remainder.index(after: remainder.startIndex)..<closeIndex])

				flushLiteral()
				try await steps.append(Self.parseToken(tokenBody))
				remainder = remainder[remainder.index(after: closeIndex)...]
			} else {
				literal.append(character)
				remainder = remainder.dropFirst()
			}
		}

		flushLiteral()

		self.title = command.title
		self.steps = steps
	}

	private static func parseKey(_ token: String) throws -> BootCommandStep.Step? {
		// This function is a placeholder for potential future key parsing logic.
		let tokens = token.split(separator: " ", maxSplits: 1)
		var repeated = 1
		
		if tokens.count > 1 {
			if tokens.count == 2, let repeatString = tokens.last {
				let repeats = repeatString.split(separator: "=", maxSplits: 1)
				
				guard repeats.count == 2, repeats[0].lowercased() == "repeat", let repeatCount = Int(repeats[1]) else {
					throw BootCommandParseError.unknownToken(token)
				}
				
				repeated = repeatCount
			} else {
				throw BootCommandParseError.unknownToken(token)
			}
		}

		let lower = tokens.first!.lowercased()

		switch lower {
		case "enter", "return": return .press(.enter, repeated: repeated)
		case "esc", "escape": return .press(.esc, repeated: repeated)
		case "tab": return .press(.tab, repeated: repeated)
		case "spacebar", "space": return .press(.spacebar, repeated: repeated)
		case "backspace": return .press(.backspace, repeated: repeated)
		case "delete", "del": return .press(.delete, repeated: repeated)
		case "insert": return .press(.insert, repeated: repeated)
		case "home": return .press(.home, repeated: repeated)
		case "end": return .press(.end, repeated: repeated)
		case "pageup": return .press(.pageUp, repeated: repeated)
		case "pagedown": return .press(.pageDown, repeated: repeated)
		case "up": return .press(.up, repeated: repeated)
		case "down": return .press(.down, repeated: repeated)
		case "left": return .press(.left, repeated: repeated)
		case "right": return .press(.right, repeated: repeated)
		default:
			break
		}

		return nil
	}

	private static func parseToken(_ rawBody: String) async throws -> BootCommandStep.Step {
		let body = rawBody.trimmingCharacters(in: .whitespaces)
		let lower = body.lowercased()

		if let waitStep = parseWait(lower) {
			return waitStep
		}

		if lower.hasPrefix("keyboard") {
			return try await parseKeyboard(body)
		}

		if lower.hasPrefix("click") {
			return try parseClick(body)
		}

		if lower.hasPrefix("locate") {
			return try parseLocate(body)
		}

		if let tokenStep = try parseKey(lower) {
			return tokenStep
		}

		switch lower {
		case "leftshifton": return .modifierOn(.leftShift)
		case "leftshiftoff": return .modifierOff(.leftShift)
		case "rightshifton": return .modifierOn(.rightShift)
		case "rightshiftoff": return .modifierOff(.rightShift)
		case "leftalton": return .modifierOn(.leftAlt)
		case "leftaltoff": return .modifierOff(.leftAlt)
		case "rightalton": return .modifierOn(.rightAlt)
		case "rightaltoff": return .modifierOff(.rightAlt)
		case "leftctrlon": return .modifierOn(.leftCtrl)
		case "leftctrloff": return .modifierOff(.leftCtrl)
		case "rightctrlon": return .modifierOn(.rightCtrl)
		case "rightctrloff": return .modifierOff(.rightCtrl)
		case "leftsuperon": return .modifierOn(.leftSuper)
		case "leftsuperoff": return .modifierOff(.leftSuper)
		case "rightsuperon": return .modifierOn(.rightSuper)
		case "rightsuperoff": return .modifierOff(.rightSuper)
		case "fnon": return .modifierOn(.function)
		case "fnoff": return .modifierOff(.function)
		default:
			if lower.hasPrefix("f"), let number = Int(lower.dropFirst()), (1...20).contains(number) {
				return .press(.function(number))
			}

			throw BootCommandParseError.unknownToken(body)
		}
	}

	/// Matches "wait", "waitN", "waitNs" or "waitNm" — a bare "wait" defaults to 1s,
	/// a bare number defaults to seconds.
	private static func parseWait(_ lower: String) -> BootCommandStep.Step? {
		guard lower.hasPrefix("wait") else { return nil }

		let remainder = lower.dropFirst("wait".count)

		if remainder.isEmpty {
			return .wait(1)
		}

		var digits = ""
		var unit = ""

		for character in remainder {
			if character.isNumber {
				digits.append(character)
			} else {
				unit.append(character)
			}
		}

		guard unit.isEmpty || unit == "s" || unit == "m", let value = Double(digits) else {
			return nil
		}

		return .wait(unit == "m" ? value * 60 : value)
	}

	@MainActor
	private static func parseKeyboard(_ body: String) throws -> BootCommandStep.Step {
		let rest = body.dropFirst("keyboard".count).trimmingCharacters(in: .whitespaces)

		if let quote = rest.first, quote == "'" || quote == "\"" {
			guard rest.count >= 2, rest.last == quote else {
				throw BootCommandParseError.malformedClick(body)
			}

			let keyboardString = String(rest.dropFirst().dropLast())

			if keyboardString.isEmpty == false, keyboardString == "current" {
				guard let keyboard = PackerLiteDriver.LayoutTranslator() else {
					throw BootCommandParseError.keyboardNotFound(keyboardString)
				}

				return .keyboard(keyboard)
			}

			guard let keyboard = PackerLiteDriver.LayoutTranslator(keyboardString) else {
				throw BootCommandParseError.keyboardNotFound(keyboardString)
			}

			return .keyboard(keyboard)
		}

		throw BootCommandParseError.malformedKeyboard(body)
	}

	/// Matches `click 'Some Text'`, `click "Some Text"` (OCR-located click) or `click X,Y` (raw coordinates).
	private static func parseClick(_ body: String) throws -> BootCommandStep.Step {
		// Support formats:
		// 1) click 'Some Text' or click "Some Text"
		// 2) click X,Y
		// 3) click timeout=10 text="Some Text"
		// 4) click point="X,Y"
		let rest = body.dropFirst("click".count).trimmingCharacters(in: .whitespaces)

		// Attribute-style: key=value pairs
		if rest.contains("=") {
			let attributes = try parseAttributes(String(rest))

			if let pointString = attributes["point"]?.trimmingCharacters(in: .whitespacesAndNewlines) {
				// Expect point in form "X,Y" possibly quoted
				let trimmed = trimMatchingQuotes(pointString)
				let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

				guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else {
					throw BootCommandParseError.malformedClick(body)
				}

				return .click(CGPoint(x: CGFloat(x), y: CGFloat(y)))
			}

			if let textValue = attributes["text"] {
				let text = trimMatchingQuotes(textValue)
				let timeout: TimeInterval

				if let timeoutString = attributes["timeout"], let parsed = TimeInterval(trimMatchingQuotes(timeoutString)) {
					timeout = parsed
				} else {
					// Default to 10 seconds if not provided
					timeout = 10
				}

				return .clickText(text, timeout: timeout)
			}

			// Unknown attributes
			throw BootCommandParseError.malformedClick(body)
		}

		// Quoted text form
		if let quote = rest.first, quote == "'" || quote == "\"" {
			guard rest.count >= 2, rest.last == quote else {
				throw BootCommandParseError.malformedClick(body)
			}

			// Use a reasonable default timeout of 10s for OCR text clicks in legacy form
			return .clickText(String(rest.dropFirst().dropLast()), timeout: 10)
		}

		// Raw coordinates form: X,Y
		let parts = rest.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

		guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else {
			throw BootCommandParseError.malformedClick(body)
		}

		return .click(CGPoint(x: CGFloat(x), y: CGFloat(y)))
	}

	/// Matches `locate 'Some Text'`, `click "Some Text"
	private static func parseLocate(_ body: String) throws -> BootCommandStep.Step {
		// Support formats:
		// 1) locate 'Some Text' or locate "Some Text"
		// 3) locate timeout=10 text="Some Text"
		let rest = body.dropFirst("locate".count).trimmingCharacters(in: .whitespaces)

		// Attribute-style: key=value pairs
		if rest.contains("=") {
			let attributes = try parseAttributes(String(rest))

			if let textValue = attributes["text"] {
				let text = trimMatchingQuotes(textValue)
				let timeout: TimeInterval

				if let timeoutString = attributes["timeout"], let parsed = TimeInterval(trimMatchingQuotes(timeoutString)) {
					timeout = parsed
				} else {
					// Default to 10 seconds if not provided
					timeout = 10
				}

				return .locate(text, timeout: timeout)
			}

			// Unknown attributes
			throw BootCommandParseError.malformedClick(body)
		}

		// Quoted text form
		if let quote = rest.first, quote == "'" || quote == "\"" {
			guard rest.count >= 2, rest.last == quote else {
				throw BootCommandParseError.malformedClick(body)
			}

			// Use a reasonable default timeout of 10s for OCR text clicks in legacy form
			return .locate(String(rest.dropFirst().dropLast()), timeout: 10)
		}

		throw BootCommandParseError.malformedClick(body)
	}

	/// Parses a simple list of key=value attributes separated by whitespace.
	/// Supports values wrapped in single or double quotes and unquoted tokens without spaces.
	private static func parseAttributes(_ input: String) throws -> [String: String] {
		var result: [String: String] = [:]
		var i = input.startIndex
		func skipSpaces() {
			while i < input.endIndex, input[i].isWhitespace { i = input.index(after: i) }
		}
		while i < input.endIndex {
			skipSpaces()
			if i >= input.endIndex { break }
			// Read key
			let keyStart = i
			while i < input.endIndex, input[i].isLetter || input[i].isNumber { i = input.index(after: i) }
			let key = String(input[keyStart..<i]).lowercased()
			skipSpaces()
			guard i < input.endIndex, input[i] == "=" else { throw BootCommandParseError.malformedClick("click " + input) }
			i = input.index(after: i)
			skipSpaces()
			guard i < input.endIndex else { throw BootCommandParseError.malformedClick("click " + input) }
			let value: String
			if input[i] == "\"" || input[i] == "'" {
				let quote = input[i]
				i = input.index(after: i)
				let valueStart = i
				while i < input.endIndex, input[i] != quote { i = input.index(after: i) }
				guard i < input.endIndex else { throw BootCommandParseError.malformedClick("click " + input) }
				value = String(input[valueStart..<i])
				i = input.index(after: i) // consume closing quote
			} else {
				let valueStart = i
				while i < input.endIndex, input[i].isWhitespace == false { i = input.index(after: i) }
				value = String(input[valueStart..<i])
			}
			result[key] = value
		}
		return result
	}

	private static func trimMatchingQuotes(_ value: String) -> String {
		guard let first = value.first, let last = value.last, (first == "\"" || first == "'") && first == last, value.count >= 2 else {
			return value
		}
		return String(value.dropFirst().dropLast())
	}
}

public enum BootCommandParseError: Error, LocalizedError, Equatable {
	case unterminatedToken(String)
	case unknownToken(String)
	case malformedClick(String)
	case malformedKeyboard(String)
	case keyboardNotFound(String)

	public var errorDescription: String? {
		switch self {
		case .unterminatedToken(let remainder): return "Unterminated boot_command token starting at: \(remainder)"
		case .unknownToken(let token): return "Unknown boot_command token: <\(token)>"
		case .malformedClick(let token): return "Malformed click token: <\(token)>"
		case .malformedKeyboard(let token): return "Malformed keyboard token: <\(token)>"
		case .keyboardNotFound(let keyboard): return "Keyboard not found: <\(keyboard)>"
		}
	}
}

public enum BootCommand {
	/// Parses a single boot_command string into a sequence of steps.
	public static func parse(_ command: PackerLiteTemplate.Command) async throws -> BootCommandStep {
		try await BootCommandStep(command: command)
	}
}
