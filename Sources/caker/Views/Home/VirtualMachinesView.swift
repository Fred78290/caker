//
//  VirtualMachinesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

private let cellWidth = 480.0
private	let cellHeight: CGFloat = 364

struct VirtualMachinesView: View {
	@Environment(\.openDocument) private var openDocument

	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel
	@State var columns: [GridItem]

	init(appState: Binding<AppState>, navigationModel: Binding<NavigationModel>) {
		_navigationModel = navigationModel
		_appState = appState

		if appState.wrappedValue.virtualMachines.count < 3 {
			var columns: [GridItem] = []

			for _ in 0..<appState.wrappedValue.virtualMachines.count {
				columns.append(GridItem(.fixed(cellWidth)))
			}
			
			self.columns = columns
		} else {
			self.columns = [GridItem(.fixed(cellWidth)), GridItem(.fixed(cellWidth)), GridItem(.fixed(cellWidth))]
		}
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .center) {
				LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
					ForEach(appState.virtualMachines.vms) { vm in
						VirtualMachineView(vm: vm.document)
							.frame(size: .init(width: cellWidth, height: cellHeight))
							.padding()
							.onTapGesture {
								Task {
									try? await self.openDocument(at: vm.document.location.rootURL)
								}
							}
					}
				}.padding()
			}
		}
	}
}

#Preview {
	VirtualMachinesView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
