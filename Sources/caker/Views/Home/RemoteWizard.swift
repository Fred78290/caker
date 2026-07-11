//
//  RemoteWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/11/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

struct RemoteWizard: View {
	@Environment(\.dismiss) private var dismiss

	@State private var name: String = String.empty
	@State private var url: String = String.empty
	@State private var reason: String? = nil

	private var isValid: Bool {
		guard self.name.isEmpty == false, self.url.isEmpty == false else {
			return false
		}

		guard let parsed = URL(string: self.url),
			  let scheme = parsed.scheme?.lowercased(),
			  ["http", "https"].contains(scheme),
			  let host = parsed.host,
			  host.isEmpty == false
		else {
			return false
		}

		return AppState.shared.remotes.first(where: { $0.name == self.name }) == nil
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Add remote")
				.font(.system(size: 16, weight: .semibold))

			Form {
				TextField("Name", text: $name)
				TextField("URL", text: $url, prompt: Text("https://cloud-images.ubuntu.com/releases"))
			}

			if let reason {
				Text(reason)
					.font(.callout)
					.foregroundStyle(.red)
			}

			Divider()

			HStack {
				Spacer()
				AsyncButton("Create", action: { done in
					await self.createRemote()
					done()
				})
				.disabled(self.isValid == false)
				.buttonStyle(.borderedProminent)

				Button("Cancel", role: .cancel) {
					self.dismiss()
				}
				Spacer()
			}
		}
		.padding()
		.frame(width: 420)
	}

	private func createRemote() async {
		guard let parsed = URL(string: self.url) else {
			return
		}

		do {
			try await AppState.shared.addRemote(name: self.name, url: parsed)

			await MainActor.run {
				self.dismiss()
			}
		} catch {
			await MainActor.run {
				self.reason = error.reason
			}
		}
	}
}

#Preview {
	RemoteWizard()
}
