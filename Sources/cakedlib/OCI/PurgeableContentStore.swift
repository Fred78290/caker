//
//  PurgeableContentStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 16/11/2025.
//
import Foundation
import Containerization
import GRPCLib
import NIO

public class PurgeableContentStore: PurgeableStorage {
	private let imageStore: ImageStore

	struct PurgeableImage: Purgeable {
		private let on: EventLoop
		private let imageStore: ImageStore
		private var totalSize: Int64
		public var url: URL
		public var source: String
		public var name: String
		public var fingerprint: String?

		public init(on: EventLoop, imageStore: ImageStore, image: Image, totalSize: Int64) {
			self.on = on
			self.source = "oci"
			self.name = image.reference
			self.url = imageStore.path.appendingPathComponent("blobs/sha256").appendingPathComponent(image.digest)
			self.imageStore = imageStore
			self.fingerprint = image.digest
			self.totalSize = totalSize
		}

		func delete() throws {
			let future = self.on.makeFutureWithTask {
				try await imageStore.delete(reference: self.name)
			}
			
			try future.wait()
		}
		
		func accessDate() throws -> Date {
			try self.url.accessDate()
		}
		
		func sizeBytes() throws -> Int {
			Int(totalSize)
		}
		
		func allocatedSizeBytes() throws -> Int {
			Int(totalSize)
		}
	}

	public init(runMode: Utils.RunMode) throws {
		self.imageStore = try Home(runMode: runMode).imageStore
	}

	func purgeables() throws -> [any Purgeable] {
		let on = Utilities.group.next()

		let result = try on.makeFutureWithTask {
			return try await self.imageStore.list()
		}.wait()

		return try result.map { image in
			let totalSize = try on.makeFutureWithTask {
				return try await image.totalSize()
			}.wait()
			
			return PurgeableImage(on: on, imageStore: self.imageStore, image: image, totalSize: totalSize)
		}
	}
}
