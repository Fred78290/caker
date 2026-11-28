import CakedLib
//
//  CreateTemplateView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//
import Foundation
import GRPCLib
import SwiftUI

struct CreateTemplateView: View {
	@State private var templateName: String = String.empty

	var body: some View {
		TextField("Name", text: $templateName)

		// The alert closes on the tap; the creation then runs behind a cancellable wait window.
		Button("Create") {
			let templateName = self.templateName

			Task { @MainActor in
				await AppState.shared.createTemplate(templateName: templateName)
			}
		}
		.disabled(templateName.isEmpty || AppState.shared.templateExists(name: templateName))
		.withButtonStyle(.bordered)

		Button("Cancel", role: .cancel, action: {})
			.withButtonStyle(.borderedProminent)
	}
}
