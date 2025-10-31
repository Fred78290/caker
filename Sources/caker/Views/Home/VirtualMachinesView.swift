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
	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel
	@State var columns: [GridItem]

	init(appState: Binding<AppState>, navigationModel: Binding<NavigationModel>) {
		_navigationModel = navigationModel
		_appState = appState

		if appState.wrappedValue.vms.count < 3 {
			var columns: [GridItem] = []

			for _ in 0..<appState.wrappedValue.vms.count {
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
					ForEach(appState.vms) { vm in
						VirtualMachineView(vm: vm.document)
							.frame(size: .init(width: cellWidth, height: cellHeight))
							.padding()
					}
				}.padding()
			}.background(.white)
		}
	}
}

#Preview {
	VirtualMachinesView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
