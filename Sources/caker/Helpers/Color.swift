//
//  Color.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/10/2025.
//

import SwiftUI

extension Color {
	public static var toolbarForegroundColor: Color {
		switch colorScheme {
		case .dark:
			return Color(fromHex: "9d9b9aFF")!
		default:
			return Color.primary
		}
		
	}

	public static var toolbarPressedColor: Color {
		switch colorScheme {
		case .dark:
			return Color(fromHex: "eeeeeeff")!
		default:
			return Color(fromHex: "202020ff")!
		}
		
	}

	static var toolbarFillColor: Color {
		switch colorScheme {
		case .dark:
			return Color(fromHex: "494543FF")!
		default:
			return Color(fromHex: "e6e4e1ff")!
		}
		
	}
}

