//
//  VirtualMachinesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import CakedLib
import SwiftUI

struct VirtualMachinesView: View {
	static let cellWidth: CGFloat = 480
	static let cellHeight: CGFloat = 364
	static let cellSpacing: CGFloat = 10

#if TRACE_SWIFTUI_DEALLOC
	let tracker = TrackDealloc(from: "VirtualMachinesView")
#endif

	@Environment(\.appearsActive) private var appearsActive
	var appState: AppState = .shared
	@State var navigationModel: NavigationModel
	@State var columns: [GridItem]
	@AppStorage("VirtualMachinesViewMode") private var viewMode: VirtualMachinesViewMode = .mosaic

	private var sortedDocuments: [VirtualMachineDocumentState] {
		Array(self.navigationModel.documents.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}

	private func openDocument(_ document: VirtualMachineDocumentState) {
		self.navigationModel.selectedVirtualMachine = document

		if self.appearsActive, let document = AppState.shared.findVirtualMachineDocument(document.url) {
			AppState.shared.currentDocument = document
		}

		Task {
			await MainApp.app.openVirtualMachine(document.url)
		}
	}

	private func selectDocument(_ document: VirtualMachineDocumentState) {
		self.navigationModel.selectedVirtualMachine = document

		if self.appearsActive, let document = AppState.shared.findVirtualMachineDocument(document.url) {
			AppState.shared.currentDocument = document
		}
	}

	@ViewBuilder
	func virtualMachineView(_ document: VirtualMachineDocumentState) -> some View {
		let selected = self.navigationModel.selectedVirtualMachine?.id == document.id

		VirtualMachineView(document, selected: selected)
			.frame(size: .init(width: Self.cellWidth, height: Self.cellHeight))
	}

	var body: some View {
		switch self.viewMode {
		case .mosaic:
			self.mosaicBody
		case .list:
			self.listBody
		}
	}

	@ViewBuilder
	private var mosaicBody: some View {
		GeometryReader { geometry in
			ScrollView {
				LazyVGrid(columns: self.columns, alignment: .leading, spacing: Self.cellSpacing) {
					ForEach(self.sortedDocuments, id: \.url) { document in
						self.virtualMachineView(document)
							.onTapGesture(count: 2) {
								self.openDocument(document)
							}
							.onTapGesture {
								self.selectDocument(document)
							}
					}
				}
				.padding(Self.cellSpacing)
			}
		}
		.frame(minWidth: Self.cellWidth + Self.cellSpacing, maxWidth: .infinity, minHeight: Self.cellWidth + Self.cellSpacing, maxHeight: .infinity)
		.onGeometryChange(for: CGRect.self) { proxy in
			proxy.frame(in: .global)
		} action: { newValue in
			self.columns = Self.buildColumns(newValue.size)
		}
	}

	@ViewBuilder
	private func listRow(_ document: VirtualMachineDocumentState) -> some View {
		HStack(spacing: 12) {
			document.osImage
				.frame(width: 28, height: 28)

			VStack(alignment: .leading, spacing: 2) {
				Text(document.name)
					.font(.system(size: 13, weight: .semibold))
					.lineLimit(1)
				Text(document.status.description.capitalized)
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}

			Spacer()

			GlossyCircle(color: HostVirtualMachineView.vmStatusColor(document.status))
				.frame(width: 10, height: 10)
		}
		.padding(.vertical, 4)
		.contentShape(Rectangle())
		.onTapGesture(count: 2) {
			self.openDocument(document)
		}
	}

	@ViewBuilder
	private var listBody: some View {
		if self.sortedDocuments.isEmpty {
			ContentUnavailableView("List empty", systemImage: "tray")
		} else {
			List(self.sortedDocuments, id: \.self, selection: $navigationModel.selectedVirtualMachine) { document in
				self.listRow(document)
			}
			.listStyle(.inset(alternatesRowBackgrounds: true))
			.onChange(of: self.navigationModel.selectedVirtualMachine) { _, newValue in
				if self.appearsActive, let document = newValue.flatMap({ AppState.shared.findVirtualMachineDocument($0.url) }) {
					AppState.shared.currentDocument = document
				}
			}
		}
	}

	static func buildColumns(_ size: CGSize) -> [GridItem] {
		let numOfColums = max(Int(size.width) / Int(cellWidth - cellSpacing), 1)
		return Array(repeating: GridItem(.fixed(cellWidth)), count: numOfColums)
	}
}
