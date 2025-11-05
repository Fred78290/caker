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

	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel
	@State var columns: [GridItem]

	init(appState: Binding<AppState>, navigationModel: Binding<NavigationModel>, size: CGSize) {
		_navigationModel = navigationModel
		_appState = appState
		self.columns = Self.buildColumns(size)
	}

	var body: some View {
		ScrollView {
			GeometryReader { geometry in
				LazyVGrid(columns: self.columns, alignment: .leading, spacing: Self.cellSpacing) {
					ForEach(appState.virtualMachines.vms) { vm in
						VirtualMachineView(vm: vm.document)
							.frame(size: .init(width: Self.cellWidth, height: Self.cellHeight))
							.onTapGesture {
								Task {
									try? await self.openDocument(at: vm.document.location.rootURL)
								}
							}
					}
					.animation(.easeInOut, value: self.columns.count)
				}
				.padding(Self.cellSpacing)
			}
		}
		.frame(minWidth: Self.cellWidth + Self.cellSpacing, maxWidth: .infinity)
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
