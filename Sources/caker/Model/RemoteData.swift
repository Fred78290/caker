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
		let remotes = RemoteHandler.listRemote(runMode: .app)

		guard remotes.success else {
			self.init(name: remote, url: "")
			return
		}

		guard let entry = remotes.remotes.first(where: { $0.name == remote }) else {
			self.init(name: remote, url: "")
			return
		}

		self.init(name: entry.name, url: entry.url)
	}

	@MainActor
	func loadImages() async {
		if let images = try? await ImageHandler.listImage(remote: self.name, runMode: .app) {
			self.images = images
		}
	}
}
