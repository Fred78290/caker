//
// Record Caker.app's windows in a screen region, for the App Store app
// previews. Only Caker's own windows are captured (no other app, no cursor,
// no wallpaper), so the composer can put the clip on its own background.
// CAKER_BUNDLE_ID=com.apple.Terminal records Terminal's windows instead.
//
//   swiftc -O Scripts/appstore-record.swift -o /tmp/appstore-record
//   /tmp/appstore-record <out.mov> <x> <y> <width> <height> <seconds>
//
// It takes one screenshot after another (SCScreenshotManager) rather than
// running a capture stream: while a stream runs, macOS replaces the captured
// window's traffic lights with a purple "recording" indicator, and single
// screenshots don't trigger it. Frames keep their real capture time; the
// composer holds them to its own frame rate.
//
// x/y/width/height are in screen points, origin top-left of the main display
// (the coordinates CGWindowListCopyWindowInfo reports). The clip is written
// as ProRes 4444, one pixel per point. Ctrl-C stops early.
//
// Needs Screen Recording permission for the terminal it runs in.

import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

let bundleID = ProcessInfo.processInfo.environment["CAKER_BUNDLE_ID"] ?? "com.aldunelabs.caker"

func fail(_ message: String) -> Never {
	FileHandle.standardError.write(Data((message + "\n").utf8))
	exit(1)
}

let arguments = CommandLine.arguments

guard arguments.count == 7,
	let x = Double(arguments[2]), let y = Double(arguments[3]),
	let width = Int(arguments[4]), let height = Int(arguments[5]),
	let seconds = Double(arguments[6])
else {
	fail("usage: appstore-record <out.mov> <x> <y> <width> <height> <seconds>")
}

let outputURL = URL(fileURLWithPath: arguments[1])
let region = CGRect(x: x, y: y, width: Double(width), height: Double(height))

nonisolated(unsafe) var interrupted = false

signal(SIGINT, SIG_IGN)

let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())

interruptSource.setEventHandler { interrupted = true }
interruptSource.resume()

func pixelBuffer(from image: CGImage, pool: CVPixelBufferPool) -> CVPixelBuffer? {
	var buffer: CVPixelBuffer?

	CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)

	guard let buffer else {
		return nil
	}

	CVPixelBufferLockBaseAddress(buffer, [])
	defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

	guard let context = CGContext(
		data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
		bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpace(name: CGColorSpace.sRGB)!,
		bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
	else {
		return nil
	}

	context.clear(CGRect(x: 0, y: 0, width: width, height: height))
	context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

	return buffer
}

func record() async throws {
	let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

	guard let display = content.displays.first(where: { $0.frame.contains(CGPoint(x: region.midX, y: region.midY)) }) ?? content.displays.first else {
		fail("No display found")
	}

	guard let caker = content.applications.first(where: { $0.bundleIdentifier == bundleID }) else {
		fail("\(bundleID) is not running")
	}

	let filter = SCContentFilter(display: display, including: [caker], exceptingWindows: [])
	let configuration = SCStreamConfiguration()

	// sourceRect is relative to the display's own origin.
	configuration.sourceRect = region.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
	configuration.width = width
	configuration.height = height
	configuration.pixelFormat = kCVPixelFormatType_32BGRA
	configuration.backgroundColor = .clear
	configuration.shouldBeOpaque = false
	configuration.showsCursor = false

	try? FileManager.default.removeItem(at: outputURL)

	let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
	let input = AVAssetWriterInput(
		mediaType: .video,
		outputSettings: [AVVideoCodecKey: AVVideoCodecType.proRes4444, AVVideoWidthKey: width, AVVideoHeightKey: height])
	let adaptor = AVAssetWriterInputPixelBufferAdaptor(
		assetWriterInput: input,
		sourcePixelBufferAttributes: [
			kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
			kCVPixelBufferWidthKey as String: width,
			kCVPixelBufferHeightKey as String: height,
		])

	writer.add(input)
	writer.startWriting()
	writer.startSession(atSourceTime: .zero)
	print("recording \(outputURL.lastPathComponent) for \(seconds)s")

	let start = Date()
	var frames = 0

	while interrupted == false {
		let elapsed = Date().timeIntervalSince(start)

		guard elapsed < seconds else {
			break
		}

		let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

		while input.isReadyForMoreMediaData == false {
			try await Task.sleep(nanoseconds: 2_000_000)
		}

		guard let pool = adaptor.pixelBufferPool, let buffer = pixelBuffer(from: image, pool: pool) else {
			fail("Can't allocate a frame")
		}

		adaptor.append(buffer, withPresentationTime: CMTime(seconds: elapsed, preferredTimescale: 600))
		frames += 1
	}

	input.markAsFinished()
	await writer.finishWriting()

	let elapsed = Date().timeIntervalSince(start)

	print("wrote \(outputURL.path) (\(frames) frames, \(String(format: "%.1f", Double(frames) / elapsed)) fps)")
}

let done = DispatchSemaphore(value: 0)

Task {
	do {
		try await record()
	} catch {
		fail("Recording failed: \(error)")
	}

	done.signal()
}

done.wait()
