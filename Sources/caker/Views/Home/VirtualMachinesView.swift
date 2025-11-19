//
//  VirtualMachinesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

struct VirtualMachinesView: View {
	static let cellWidth: CGFloat = 480
	static let cellHeight: CGFloat = 364
	static let cellSpacing: CGFloat = 10

	@Environment(\.openDocument) private var openDocument
	@Environment(\.appearsActive) private var appearsActive

	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel
	@State var columns: [GridItem]

	init(appState: Binding<AppState>, navigationModel: Binding<NavigationModel>, size: CGSize) {
		_navigationModel = navigationModel
		_appState = appState
		self.columns = Self.buildColumns(size)
	}

	@ViewBuilder
	func virtualMachineView(_ document: VirtualMachineDocument) -> some View {
		let selected: Bool = self.navigationModel.selectedVirtualMachine?.id == document.id

		VirtualMachineView(selected: selected, vm: document)
			.frame(size: .init(width: Self.cellWidth, height: Self.cellHeight))

//		if self.appearsActive {
//			VirtualMachineView(selected: selected, vm: document)
//				.frame(size: .init(width: Self.cellWidth, height: Self.cellHeight))
//				.animation(.easeInOut, value: self.columns.count)
//		} else {
//			VirtualMachineView(selected: selected, vm: document)
//				.frame(size: .init(width: Self.cellWidth, height: Self.cellHeight))
//		}
	}

	var body: some View {
		GeometryReader { geometry in
			ScrollView {
				LazyVGrid(columns: self.columns, alignment: .leading, spacing: Self.cellSpacing) {
					ForEach(appState.virtualMachines.vms) { vm in
						self.virtualMachineView(vm.document)
							.onTapGesture {
								self.navigationModel.selectedVirtualMachine = vm.document
								print("selected: \(vm.document.name)")
							}
							.onTapGesture(count: 2) {
								Task {
									try? await self.openDocument(at: vm.document.location.rootURL)
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

#Preview {
	VirtualMachinesView(appState: .constant(.init()), navigationModel: .constant(.init()), size: .init(width: 500, height: 600))
}
