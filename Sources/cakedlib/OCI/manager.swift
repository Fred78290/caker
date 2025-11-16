//
//  manager.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/11/2025.
//
import Foundation
import Containerization
import ContainerizationOCI
import ContainerizationExtras

extension Home {
	var imageStore: ImageStore {
		try! ImageStore(
			path: cakeHomeDirectory,
			contentStore: try! LocalContentStore(path: cakeHomeDirectory.appendingPathComponent("OCIs"))
		)
	}
}

struct TartUnpacker: Unpacker {
	func unpack(_ image: Containerization.Image, for platform: Platform, at path: URL, progress: ProgressHandler?) async throws -> Containerization.Mount {
		throw ServiceError("Not yet implemented")
	}
}
