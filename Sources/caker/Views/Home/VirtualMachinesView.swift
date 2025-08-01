//
//  VirtualMachinesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

struct VirtualMachinesView: View {
	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel

	let columns = [GridItem(.fixed(200)), GridItem(.fixed(200)), GridItem(.fixed(200))]

	var body: some View {
		ScrollView {
			VStack(alignment: .center) {
				LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
					ForEach(appState.vms) { vm in
						VStack {
							LabeledContent("Name") {
								Text("\(vm.document.name)")
							}
							LabeledContent("Status") {
								Text("\(vm.document.status)")
							}
						}.frame(size: .init(width: 200, height: 200)).border(.gray, width: 1)
					}
				}.padding()
			}.background(.white)
		}
	}
}

#Preview {
	VirtualMachinesView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
