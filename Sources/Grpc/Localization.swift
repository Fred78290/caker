//
//  Localization.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/04/2026.
//
import Foundation
import SwiftUI

extension String {
	public static func localizedString(for key: LocalizedStringKey, locale: Locale = .current) -> String {
		guard let stringKey = key.stringKey else {
			return "\(key)"
		}

		let language = locale.language.languageCode?.identifier
		let path = Bundle.main.path(forResource: language, ofType: "lproj")!

		guard let bundle = Bundle(path: path) else {
			return stringKey
		}

		return NSLocalizedString(stringKey, bundle: bundle, comment: String.empty)
	}
}

extension LocalizedStringKey {
	// This will mirror the `LocalizedStringKey` so it can access its
	// internal `key` property. Mirroring is rather expensive, but it
	// should be fine performance-wise, unless you are
	// using it too much or doing something out of the norm.
	public var stringKey: String? {
		Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
	}
	
	public func stringValue(locale: Locale = .current) -> String {
		return .localizedString(for: self, locale: locale)
	}
}
