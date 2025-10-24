//
//  Extensions.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/07/2025.
//
import SwiftUI

extension View {
	func colorSchemeForColor(_ scheme: ColorScheme) -> some View {
		Color.colorScheme = scheme
		return self
	}

	func onReceive(
		_ name: Notification.Name,
		center: NotificationCenter = .default,
		object: AnyObject? = nil,
		perform action: @escaping (Notification) -> Void
	) -> some View {
		self.onReceive(
			center.publisher(for: name, object: object), perform: action
		)
	}
}
