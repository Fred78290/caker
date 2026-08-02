//
//  BootCommand.swift
//  CakedLib
//
//  Parses Packer-style boot_command strings (e.g. "<wait30s>italiano<esc>english<enter>")
//  into a sequence of platform-agnostic steps. No AppKit/Virtualization dependency here —
//  the driver that turns these into actual input events lives in CakedLib.
//

import Foundation

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
}

public enum BootCommandStep: Equatable, Sendable {
	case wait(TimeInterval)
	case type(String)
	case press(KeyToken)
	case modifierOn(ModifierToken)
	case modifierOff(ModifierToken)
	case click(x: Int, y: Int)
	case clickText(String)
}

public enum BootCommandParseError: Error, LocalizedError, Equatable {
	case unterminatedToken(String)
	case unknownToken(String)
	case malformedClick(String)

	public var errorDescription: String? {
		switch self {
			case .unterminatedToken(let remainder): return "Unterminated boot_command token starting at: \(remainder)"
			case .unknownToken(let token): return "Unknown boot_command token: <\(token)>"
			case .malformedClick(let token): return "Malformed click token: <\(token)>"
		}
	}
}

public enum BootCommand {
	/// Parses a single boot_command string into a sequence of steps.
	public static func parse(_ command: String) throws -> [BootCommandStep] {
		var steps: [BootCommandStep] = []
		var literal = ""
		var remainder = Substring(command)

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
				steps.append(try parseToken(tokenBody))
				remainder = remainder[remainder.index(after: closeIndex)...]
			} else {
				literal.append(character)
				remainder = remainder.dropFirst()
			}
		}

		flushLiteral()

		return steps
	}

	private static func parseToken(_ rawBody: String) throws -> BootCommandStep {
		let body = rawBody.trimmingCharacters(in: .whitespaces)
		let lower = body.lowercased()

		if let waitStep = parseWait(lower) {
			return waitStep
		}

		if lower.hasPrefix("click") {
			return try parseClick(body)
		}

		switch lower {
			case "enter", "return": return .press(.enter)
			case "esc", "escape": return .press(.esc)
			case "tab": return .press(.tab)
			case "spacebar", "space": return .press(.spacebar)
			case "backspace": return .press(.backspace)
			case "delete", "del": return .press(.delete)
			case "insert": return .press(.insert)
			case "home": return .press(.home)
			case "end": return .press(.end)
			case "pageup": return .press(.pageUp)
			case "pagedown": return .press(.pageDown)
			case "up": return .press(.up)
			case "down": return .press(.down)
			case "left": return .press(.left)
			case "right": return .press(.right)
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
			default:
				if lower.hasPrefix("f"), let number = Int(lower.dropFirst()), (1...12).contains(number) {
					return .press(.function(number))
				}

				throw BootCommandParseError.unknownToken(body)
		}
	}

	/// Matches "wait", "waitN", "waitNs" or "waitNm" — a bare "wait" defaults to 1s,
	/// a bare number defaults to seconds.
	private static func parseWait(_ lower: String) -> BootCommandStep? {
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

	/// Matches `click 'Some Text'`, `click "Some Text"` (OCR-located click) or `click X,Y` (raw coordinates).
	private static func parseClick(_ body: String) throws -> BootCommandStep {
		let rest = body.dropFirst("click".count).trimmingCharacters(in: .whitespaces)

		if let quote = rest.first, quote == "'" || quote == "\"" {
			guard rest.count >= 2, rest.last == quote else {
				throw BootCommandParseError.malformedClick(body)
			}

			return .clickText(String(rest.dropFirst().dropLast()))
		}

		let parts = rest.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

		guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else {
			throw BootCommandParseError.malformedClick(body)
		}

		return .click(x: x, y: y)
	}
}
