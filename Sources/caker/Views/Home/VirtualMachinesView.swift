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

#if DEBUG
	let tracker = TrackDealloc(from: "VirtualMachinesView")
#endif

	@Environment(\.appearsActive) private var appearsActive
	@ObservedObject var appState: AppState = .shared
	@StateObject var navigationModel: NavigationModel
	@State var columns: [GridItem]

	@ViewBuilder
	func virtualMachineView(_ document: VirtualMachineDocument) -> some View {
		let selected = self.navigationModel.selectedVirtualMachine?.id == document.id

		VirtualMachineView(.constant(document), selected: selected)
			.frame(size: .init(width: Self.cellWidth, height: Self.cellHeight))
	}

	var body: some View {
		GeometryReader { geometry in
			ScrollView {
				LazyVGrid(columns: self.columns, alignment: .leading, spacing: Self.cellSpacing) {
					ForEach(self.appState.virtualMachines.documents) { document in
						self.virtualMachineView(document)
							.onTapGesture(count: 2) {
								self.navigationModel.selectedVirtualMachine = document

								if self.appearsActive {
									AppState.shared.currentDocument = document
								}

								Task {
									await MainApp.app.openVirtualMachine(document.url)
								}
							}
							.onTapGesture {
								self.navigationModel.selectedVirtualMachine = document

								if self.appearsActive {
									AppState.shared.currentDocument = document
								}
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

	static func buildColumns(_ size: CGSize) -> [GridItem] {
		let numOfColums = max(Int(size.width) / Int(cellWidth - cellSpacing), 1)
		return Array(repeating: GridItem(.fixed(cellWidth)), count: numOfColums)
	}
}
