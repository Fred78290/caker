import CakedLib
//
//  RemoteData.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/06/2025.
//
import Foundation
import GRPCLib
import SwiftUI

class RemoteData: ObservableObject, Observable {
	@Published var name: String
	@Published var url: String
	@Published var images: [ImageInfo] = []

	init(name: String, url: String) {
		self.name = name
		self.url = url
	}

	convenience init(remote: String) {
		let remotes = AppState.shared.loadRemotes()

		guard remotes.isEmpty == false else {
			self.init(name: remote, url: "")
			return
		}

		guard let entry = remotes.first(where: { $0.name == remote }) else {
			self.init(name: remote, url: "")
			return
		}

		self.init(name: entry.name, url: entry.url)
	}

	@MainActor
	func loadImages() async {
		self.images = await AppState.shared.loadImages(remote: self.name)
	}
}
