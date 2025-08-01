import Combine
import Foundation
import SwiftUI

struct FormatAndValidateTextFieldStore<T, F: ParseableFormatStyle>: ViewModifier where F.FormatOutput == String, F.FormatInput == T {
	private var errorCondition: FormatAndValidateErrorCondition?

	typealias FormatAndValidateErrorCondition = (T) -> Bool

	@Binding private var textFieldStore: TextFieldStore<T, F>
	@State private var inputError: Bool = false

	init(_ textFieldStore: Binding<TextFieldStore<T, F>>, errorCondition: FormatAndValidateErrorCondition? = nil) {
		self.errorCondition = errorCondition
		self._textFieldStore = textFieldStore
	}

	func body(content: Content) -> some View {
		return content.onChange(of: textFieldStore.text) { text in
			guard let value = textFieldStore.getValue() else {
				if text.isEmpty || (text == textFieldStore.minusCharacter && textFieldStore.allowNegative) {
					inputError = false
				} else {
					inputError = true
				}
				return
			}

			if let errorCondition = errorCondition {
				inputError = errorCondition(value)

				if inputError == false {
					textFieldStore.value = value
				}
			} else {
				inputError = false
				textFieldStore.value = value
			}
		}
		.foregroundColor(inputError ? .red : .primary)
		.disableAutocorrection(true)
		.onSubmit {
			if textFieldStore.text.count > 1 && textFieldStore.text.suffix(1) == textFieldStore.decimalSeparator {
				textFieldStore.text.removeLast()
			}
		}
	}
}

extension View {
	func formatAndValidate<T, F: ParseableFormatStyle>(_ textFieldStore: Binding<TextFieldStore<T, F>>, errorCondition: ((T) -> Bool)? = nil) -> some View {
		modifier(FormatAndValidateTextFieldStore(textFieldStore, errorCondition: errorCondition))
	}
}

class TextFieldStore<T, F: ParseableFormatStyle>: ObservableObject where F.FormatOutput == String, F.FormatInput == T {
	@Published var text: String
	@Published var value: T

	let minusCharacter = "-"
	let type: ValidationType
	let maxLength: Int
	let allowNegative: Bool
	let formatter: F

	private var backupText: String
	private let locale: Locale

	init(value: T, text: String? = nil, type: ValidationType, maxLength: Int = 18, allowNegative: Bool = false, formatter: F, locale: Locale = .current) {
		let input = text ?? formatter.format(value)

		self.value = value
		self.text = input
		self.backupText = input
		self.type = type
		self.allowNegative = allowNegative
		self.formatter = formatter
		self.locale = locale
		self.maxLength = maxLength == .max ? .max - 1 : maxLength
	}

	var result: T? {
		try? formatter.parseStrategy.parse(text)
	}

	func restore() {
		text = backupText
	}

	func backup() {
		backupText = text
	}

	lazy var decimalSeparator: String = {
		locale.decimalSeparator ?? "."
	}()

	private lazy var groupingSeparator: String = {
		locale.groupingSeparator ?? ""
	}()

	private lazy var characters: String = {
		let number = "0123456789"

		switch type {
		case .int:
			return number + (allowNegative ? minusCharacter : "")
		case .double:
			return number + (allowNegative ? minusCharacter : "") + decimalSeparator
		case .none:
			return ""
		case .macAddress:
			return "0123456789ABCDEFabcdef:"
		}
	}()

	var minusCount: Int {
		text.components(separatedBy: minusCharacter).count - 1
	}

	func characterValidator() -> Bool {
		let chars = self.characters

		if chars.isEmpty {
			return true
		}

		return text.replacingOccurrences(of: groupingSeparator, with: "").allSatisfy { chars.contains($0) }
	}

	func getValue() -> T? {
		if text.isEmpty || ((type == .double || type == .int) && text == minusCharacter) || (type == .double && text == decimalSeparator) {
			backup()
			return nil
		}

		guard characterValidator() else {
			restore()
			return nil
		}

		if type == .int || type == .double {
			if type == .double {
				if text.components(separatedBy: decimalSeparator).count > 2 {
					restore()
					return nil
				}
			}

			if minusCount > 1 {
				restore()
				return nil
			}

			if minusCount == 1, !text.hasPrefix("-") {
				restore()
				return nil
			}

			guard text.count <= maxLength + minusCount else {
				restore()
				return nil
			}
		} else {
			guard text.count <= maxLength else {
				restore()
				return nil
			}
		}

		if let value = try? formatter.parseStrategy.parse(text) {
			let oldText = text
			var newText = formatter.format(value)

			if type == .int || type == .double {
				if oldText.contains(decimalSeparator), !newText.contains(decimalSeparator) {
					let zeroCount = oldText.trailingZerosCountAfterDecimal()

					newText.append(decimalSeparator)
					newText += (0..<zeroCount).map { _ in "0" }.joined(separator: "")
				}
			}

			self.text = newText

			backup()
			return value
		} else {
			restore()
			return nil
		}
	}

	enum ValidationType {
		case int
		case double
		case macAddress
		case none
	}
}

extension String {
	func trailingZerosCountAfterDecimal() -> Int {
		var count = 0
		var foundDecimal = false

		for char in self.reversed() {
			if char == "." {
				foundDecimal = true
				break
			}
		}

		for char in self.reversed() {
			if foundDecimal && char == "0" {
				count += 1
			} else if char != "0" {
				break
			}
		}

		return count
	}
}
