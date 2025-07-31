//
//  CreateTemplateView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//
import Foundation
import SwiftUI
import CakedLib
import GRPCLib

struct CreateTemplateView: View {
	@Binding var appState: AppState
	@State private var templateName: String = ""
	@State private var templateResult: CreateTemplateReply?
	
	var body: some View {
		TextField("Name", text: $templateName)
		
		AsyncButton("Create", action: { done in
			await createTemplate(done)
		})
		.disabled(templateName.isEmpty || TemplateHandler.exists(name: templateName, runMode: .app))
		.onChange(of: templateResult) { newValue in
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
	
	private func createTemplate(_ done: @escaping () -> Void) async {
		DispatchQueue.main.async {
			self.templateResult = self.appState.currentDocument?.createTemplateFromUI(name: self.templateName)
			done()
		}
	}
}
