import Carbon.HIToolbox
import Foundation

/// The host's keyboard layout as an XKB layout name. Seamless windows send keys by physical position, so the guest
/// compositor has to use the same layout as the host's keyboard.
public enum SeamlessKeyboardLayout {
	private static let layouts: [String: String] = [
		"US": "us",
		"ABC": "us",
		"USExtended": "us",
		"USInternational-PC": "us",
		"British": "gb",
		"French": "fr",
		"German": "de",
		"Spanish": "es",
		"Italian": "it",
		"Dutch": "nl",
		"Portuguese": "pt",
		"Brazilian": "br",
		"Swedish": "se",
		"Norwegian": "no",
		"Danish": "dk",
		"Finnish": "fi",
		"Belgian": "be",
		"Swiss": "ch",
		"Irish": "ie",
		"Russian": "ru",
		"Polish": "pl",
		"Czech": "cz",
		"Hungarian": "hu",
		"Turkish-QWERTY": "tr",
		"Canadian-CSA": "ca",
	]

	/// XKB layout for a macOS input source id (`com.apple.keylayout.French`), nil when there is no plain equivalent
	/// (layouts that need an XKB variant are left to the guest default rather than guessed).
	public static func xkbLayout(forInputSourceID id: String) -> String? {
		let prefix = "com.apple.keylayout."

		guard id.hasPrefix(prefix) else { return nil }

		return layouts[String(id.dropFirst(prefix.count))]
	}

	/// The layout of the keyboard in use now.
	public static func hostXkbLayout() -> String? {
		let read: () -> String? = {
			guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
				let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
			else {
				return nil
			}

			return xkbLayout(forInputSourceID: Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String)
		}

		return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
	}
}
