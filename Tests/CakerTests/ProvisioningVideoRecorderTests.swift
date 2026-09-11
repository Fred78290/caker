//
//  ProvisioningVideoRecorderTests.swift
//  CakerTests
//

import AVFoundation
import AppKit
import CoreVideo
import Foundation
import XCTest

@testable import CakedLib

final class ProvisioningVideoRecorderTests: XCTestCase {
	private let frameSize = CGSize(width: 64, height: 48)

	/// A solid-color `NSImage` at a fixed size, standing in for a captured VM screenshot.
	private func solidImage(size: CGSize, color: NSColor) -> NSImage {
		let image = NSImage(size: size)

		image.lockFocus()
		color.setFill()
		NSRect(origin: .zero, size: size).fill()
		image.unlockFocus()

		return image
	}

	private func makeOutputURL() -> URL {
		FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
	}

	func testAppendingFramesProducesValidNonEmptyVideo() async throws {
		let outputURL = makeOutputURL()

		defer { try? FileManager.default.removeItem(at: outputURL) }

		let recorder = try ProvisioningVideoRecorder(outputURL: outputURL, frameSize: frameSize)
		let colors: [NSColor] = [.red, .green, .blue]
		var date = Date()

		for color in colors {
			recorder.append(solidImage(size: frameSize, color: color), at: date)
			date = date.addingTimeInterval(5)
		}

		await recorder.finish(delete: false)

		XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)), "finish(delete: false) should leave the video file in place")

		let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path(percentEncoded: false))
		let fileSize = attributes[.size] as? Int ?? 0

		XCTAssertGreaterThan(fileSize, 0, "the produced .mp4 should be non-empty")

		// A real video player would need to be able to open a track and read frames back out of
		// this file — use AVAssetReader as a proxy for "this is a valid, readable video."
		let asset = AVURLAsset(url: outputURL)
		let tracks = try await asset.loadTracks(withMediaType: .video)

		XCTAssertFalse(tracks.isEmpty, "the .mp4 should contain a readable video track")

		guard let track = tracks.first else {
			return
		}

		let reader = try AVAssetReader(asset: asset)
		let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])

		reader.add(output)

		XCTAssertTrue(reader.startReading(), "AVAssetReader should be able to start reading the produced video")

		var frameCount = 0

		while output.copyNextSampleBuffer() != nil {
			frameCount += 1
		}

		XCTAssertEqual(frameCount, colors.count, "should read back exactly the frames that were appended")
	}

	func testFinishDeleteRemovesTheFile() async throws {
		let outputURL = makeOutputURL()

		defer { try? FileManager.default.removeItem(at: outputURL) }

		let recorder = try ProvisioningVideoRecorder(outputURL: outputURL, frameSize: frameSize)

		recorder.append(solidImage(size: frameSize, color: .red))
		recorder.append(solidImage(size: frameSize, color: .blue), at: Date().addingTimeInterval(5))

		await recorder.finish(delete: true)

		XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)), "finish(delete: true) should remove the video file")
	}

	func testFinishWithNoAppendedFramesDoesNotCrash() async throws {
		let outputURL = makeOutputURL()

		defer { try? FileManager.default.removeItem(at: outputURL) }

		let recorder = try ProvisioningVideoRecorder(outputURL: outputURL, frameSize: frameSize)

		// Provisioning could fail almost immediately, before a single screenshot ever ticked —
		// finish() must handle a writer session that was never started, without crashing.
		await recorder.finish(delete: false)

		XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)), "no frames means no video file should be left behind")
	}

	func testLeftoverFileFromPreviousAttemptIsReplaced() throws {
		let outputURL = makeOutputURL()

		defer { try? FileManager.default.removeItem(at: outputURL) }

		try Data("stale".utf8).write(to: outputURL)
		XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)))

		// Constructing a new recorder for the same output URL (a fresh provisioning attempt)
		// should clear out the stale leftover rather than erroring or appending to it.
		_ = try ProvisioningVideoRecorder(outputURL: outputURL, frameSize: frameSize)

		XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)))
	}
}
