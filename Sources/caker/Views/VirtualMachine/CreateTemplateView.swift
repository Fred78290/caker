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
	@Binding var appState: AppState
	@State private var templateName: String = ""
	@State private var templateResult: CreateTemplateReply?

	var body: some View {
		TextField("Name", text: $templateName)

		AsyncButton(
			"Create",
			action: { done in
				await createTemplate { result in
					switch result {
					case .success(let value):
						self.templateResult = value
						self.appState.reloadRemotes()
					case .failure(let error):
						alertError(error)
					}
				}
			}
		)
		.disabled(templateName.isEmpty || self.appState.templateExists(name: templateName))
		.onChange(of: templateResult) { _, newValue in
			isCreateTemplatFailed(templateResult: newValue)
		}

		Button("Cancel", role: .cancel, action: {})
	}

	private func isCreateTemplatFailed(templateResult: CreateTemplateReply?) {
		if let templateResult = templateResult, templateResult.created == false {
			let alert = NSAlert()

			alert.messageText = "Failed to create template"
			alert.informativeText = templateResult.reason ?? "Internal error"
			alert.runModal()
		} else {
			self.appState.reloadRemotes()
		}
	}

	private func createTemplate(_ done: @escaping (Result<CreateTemplateReply, Error>) -> Void) async {
		DispatchQueue.main.async {
			do {
				guard let currentDocument = self.appState.currentDocument else {
					done(.failure(ServiceError("No VM found")))
					return
				}

				guard currentDocument.status.isStopped else {
					done(.failure(ServiceError("VM is running")))
					return
				}

				done(.success(try TemplateHandler.createTemplate(client: self.appState.cakedServiceClient, sourceName: self.appState.currentDocument!.name, templateName: self.templateName, runMode: self.appState.runMode)))
			} catch {
				done(.failure(error))
			}
		}
	}
}
