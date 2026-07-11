//
//  RemotesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI

struct RemotesView: View {
	@Bindable var navigationModel: NavigationModel

	var body: some View {
		GeometryReader { geom in
			if AppState.shared.remotes.isEmpty {
				VStack(alignment: .center) {
					ContentUnavailableView("List empty", systemImage: "tray")
				}.frame(width: geom.size.width)
			} else {
				List(AppState.shared.remotes, id: \.self, selection: $navigationModel.selectedRemote) { remote in
					HStack(spacing: 12) {
						ZStack {
							RoundedRectangle(cornerRadius: 9)
								.fill(Color.orange.gradient)
								.frame(width: 38, height: 38)
							Image(systemName: "icloud")
								.resizable()
								.aspectRatio(contentMode: .fit)
								.foregroundStyle(.white)
								.frame(width: 20, height: 20)
						}

						VStack(alignment: .leading, spacing: 2) {
							Text(remote.name)
								.font(.system(size: 13, weight: .semibold))
							Text(remote.url)
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
								.lineLimit(1)
								.truncationMode(.middle)
						}

						Spacer()
					}
					.padding(.vertical, 4)
					.contentShape(Rectangle())
					.contextMenu {
						Button("Delete", role: .destructive) {
							AppState.shared.deleteRemote(name: remote.name)
						}
					}
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
				.frame(size: geom.size)
			}
		}
	}
}

#Preview {
	RemotesView(navigationModel: .init(selectedCategory: .images))
}
