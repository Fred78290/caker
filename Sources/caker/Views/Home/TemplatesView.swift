//
//  TemplatesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI

struct TemplatesView: View {
	@Bindable var navigationModel: NavigationModel
	@State private var vmFromTemplate: TemplateEntry? = nil

	var body: some View {
		GeometryReader { geom in
			if AppState.shared.templates.isEmpty {
				VStack(alignment: .center) {
					ContentUnavailableView("List empty", systemImage: "tray")
				}.frame(width: geom.size.width)
			} else {
				List(AppState.shared.templates, id: \.self, selection: $navigationModel.selectedTemplate) { template in
					HStack(spacing: 12) {
						ZStack {
							RoundedRectangle(cornerRadius: 9)
								.fill(Color.blue.gradient)
								.frame(width: 38, height: 38)
							Image(systemName: "square.stack.3d.up.fill")
								.resizable()
								.aspectRatio(contentMode: .fit)
								.foregroundStyle(.white)
								.frame(width: 20, height: 20)
						}

						VStack(alignment: .leading, spacing: 2) {
							Text(template.name)
								.font(.system(size: 13, weight: .semibold))
							Text(ByteCountFormatter.string(fromByteCount: Int64(template.totalSize), countStyle: .file))
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
						}

						Spacer()
					}
					.padding(.vertical, 4)
					.contentShape(Rectangle())
					.contextMenu {
						Button("New Virtual Machine…") {
							vmFromTemplate = template
						}

						Divider()

						Button("Clone…") {
							AppState.shared.duplicateTemplate(name: template.name)
						}

						Divider()

						Button("Delete", role: .destructive) {
							AppState.shared.deleteTemplate(name: template.name)
						}
					}
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
				.frame(size: geom.size)
			}
		}
		.sheet(item: $vmFromTemplate) { template in
			VirtualMachineWizard(sheet: true, presetTemplate: template)
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(minWidth: 700, minHeight: 670)
		}
	}
}

#Preview {
	TemplatesView(navigationModel: .init(selectedCategory: .templates))
}
