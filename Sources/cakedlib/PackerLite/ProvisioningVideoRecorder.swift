//
//  ProvisioningVideoRecorder.swift
//  CakedLib
//
//  Records the periodic screenshots VirtualMachine already takes while a VM is running
//  (see `kScreenshotPeriodSeconds`/`takeScreenshot()` in VirtualMachine.swift) into a
//  standard H.264-in-.mp4 video for as long as PackerLite provisioning is in progress —
//  a debug aid for figuring out why a boot_command template went wrong after the fact.
//  Deliberately not fancy: low frame rate (one frame roughly every 5 real seconds), no
//  exotic codec/profile settings — just "plays in VLC/QuickTime/a browser/Windows Media
//  Player without extra codecs installed."
//

import AVFoundation
import AppKit
import CoreMedia
import CoreVideo
import Foundation

/// Wraps an `AVAssetWriter` to turn a stream of `NSImage` screenshots into an .mp4 file.
///
/// All frames are expected to share one fixed size — the VM's configured screen size.
/// Provisioning already disables client-driven VNC resize (so PackerLite's OCR/click
/// coordinates stay valid), so this doesn't try to handle a mid-recording resize.
public final class ProvisioningVideoRecorder: @unchecked Sendable {
	public enum RecorderError: Error, CustomStringConvertible {
		case cannotAddInput
		case pixelBufferPoolUnavailable

		public var description: String {
			switch self {
			case .cannotAddInput:
				return "Unable to configure the provisioning video writer input"
			case .pixelBufferPoolUnavailable:
				return "Unable to obtain a pixel buffer pool for the provisioning video writer"
			}
		}
	}

	private let outputURL: URL
	private let frameSize: CGSize
	private let writer: AVAssetWriter
	private let input: AVAssetWriterInput
	private let adaptor: AVAssetWriterInputPixelBufferAdaptor

	// Guards `sessionStarted`/`firstFrameDate`/`frameCount` and serializes calls into the
	// writer/input/adaptor, since `append` can be called repeatedly off the screenshot timer
	// while `finish` is awaited from an unrelated task.
	private static let syncQueue = DispatchQueue(label: "cakedlib.provisioning-video-recorder")

	private var sessionStarted = false
	private var firstFrameDate: Date?
	private var frameCount = 0

	public init(outputURL: URL, frameSize: CGSize) throws {
		// Each provisioning run gets a fresh recording — remove any leftover file from a
		// previous attempt rather than erroring or (accidentally) appending to it.
		try? FileManager.default.removeItem(at: outputURL)

		let width = max(2, Int(frameSize.width))
		let height = max(2, Int(frameSize.height))

		let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

		let videoSettings: [String: Any] = [
			AVVideoCodecKey: AVVideoCodecType.h264,
			AVVideoWidthKey: width,
			AVVideoHeightKey: height,
			AVVideoCompressionPropertiesKey: [
				AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
			],
		]

		let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)

		input.expectsMediaDataInRealTime = true

		let sourcePixelBufferAttributes: [String: Any] = [
			kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
			kCVPixelBufferWidthKey as String: width,
			kCVPixelBufferHeightKey as String: height,
		]

		let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

		guard writer.canAdd(input) else {
			throw RecorderError.cannotAddInput
		}

		writer.add(input)

		self.outputURL = outputURL
		self.frameSize = CGSize(width: width, height: height)
		self.writer = writer
		self.input = input
		self.adaptor = adaptor
	}

	/// Appends one captured screenshot as a video frame. `date` is real wall-clock time (not
	/// an assumed fixed interval) so the resulting video's pacing roughly matches how long
	/// provisioning actually took, even though it's only ~1 frame per 5 real seconds.
	public func append(_ image: NSImage, at date: Date = Date()) {
		Self.syncQueue.async {
			guard let pixelBuffer = self.makePixelBuffer(from: image) else {
				return
			}

			if self.sessionStarted == false {
				guard self.writer.startWriting() else {
					return
				}

				self.writer.startSession(atSourceTime: .zero)
				self.sessionStarted = true
				self.firstFrameDate = date
			}

			guard let firstFrameDate = self.firstFrameDate, self.input.isReadyForMoreMediaData else {
				return
			}

			let elapsed = max(0, date.timeIntervalSince(firstFrameDate))
			let presentationTime = CMTime(seconds: elapsed, preferredTimescale: 600)

			if self.adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
				self.frameCount += 1
			}
		}
	}

	/// Stops the writer, waits for it to actually finish writing, then either deletes the
	/// output file (`delete: true`, the provisioning-succeeded case) or leaves it in place
	/// (`delete: false`, the provisioning-failed case, so it can be inspected afterward).
	///
	/// If `finish` is called before any frame was ever appended (e.g. provisioning failed
	/// almost immediately), the writer session was never started — there's nothing to
	/// finalize, so this just removes any (empty/partial) file rather than calling into
	/// `AVAssetWriter.finishWriting`, which requires a session to already be underway.
	public func finish(delete: Bool) async {
		let started = Self.syncQueue.sync { self.sessionStarted }

		guard started else {
			try? FileManager.default.removeItem(at: outputURL)
			return
		}

		Self.syncQueue.sync {
			self.input.markAsFinished()
		}

		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			self.writer.finishWriting {
				continuation.resume()
			}
		}

		if delete {
			try? FileManager.default.removeItem(at: outputURL)
		}
	}

	private func makePixelBuffer(from image: NSImage) -> CVPixelBuffer? {
		guard let cgImage = image.cgImage else {
			return nil
		}

		let width = Int(frameSize.width)
		let height = Int(frameSize.height)

		let attributes: [String: Any] = [
			kCVPixelBufferCGImageCompatibilityKey as String: true,
			kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
		]

		var pixelBuffer: CVPixelBuffer?
		let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer)

		guard status == kCVReturnSuccess, let pixelBuffer else {
			return nil
		}

		CVPixelBufferLockBaseAddress(pixelBuffer, [])
		defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

		guard
			let context = CGContext(
				data: CVPixelBufferGetBaseAddress(pixelBuffer),
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
		else {
			return nil
		}

		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

		return pixelBuffer
	}
}
