#!/usr/bin/env swift
//
// Build the Mac App Store app previews from window recordings of Caker.app:
// each preview is one or more clips, cross-faded, laid out on a 1920x1080
// canvas (the only size App Store Connect accepts for Mac app previews) with
// a localized headline above the window. Between two clips the first fades
// out before the next fades in, so their windows and captions never overlap.
//
//   swift Scripts/appstore-previews.swift appstore/previews/previews.json
//
// The JSON file:
//
//   {
//     "canvas": [1920, 1080], "fps": 30, "crossfade": 0.4,
//     "raw": "raw",                    // clips: <raw>/<lang>/<file>
//     "output": ".",                   // results: <output>/<locale>/<NN>-<name>.mp4
//     "languages": { "en": "en-US", "fr": "fr-FR" },
//     "previews": [
//       { "name": "virtual-machines",
//         "clips": [
//           { "file": "home.mov", "still": "home.png",
//             "in": { "en": 1.0, "fr": 1.4 }, "out": { "en": 12.0, "fr": 12.6 },
//             "headline": { "en": "...", "fr": "..." },
//             "subtitle": { "en": "...", "fr": "..." } } ] } ]
//   }
//
// A clip is a recording of exactly one window's frame (Scripts/appstore-record.swift)
// and its still is `screencapture -o -l <window id>` of the same window. The
// still gives the window's rounded shape: the clip is cut to it (so another
// Caker window behind a corner never shows) and gets its shadow from it.
// "in"/"out" (seconds) trim the clip; either can be one number or one per
// language, since each language is recorded separately. "crop": [x, y, width,
// height] (window points, top-left origin) keeps only part of the window, for
// example a Terminal window without its title bar, drawn as a panel with
// "radius"-point rounded corners (default 12) instead of the window's shape.
// "join": true makes a hard cut from the previous clip instead of a fade: with
// two pieces of the same recording that show the same screen at the cut, it
// removes a wait (a VM booting) without any visible transition.
//
// The video is H.264 High at about 11 Mbit/s, then ffmpeg adds the silent
// stereo AAC track App Store Connect expects and moves the index to the front.

import AVFoundation
import AppKit
import CoreMedia
import Foundation

func fail(_ message: String) -> Never {
	FileHandle.standardError.write(Data((message + "\n").utf8))
	exit(1)
}

enum PerLanguage<T: Decodable>: Decodable {
	case one(T)
	case each([String: T])

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		if let value = try? container.decode(T.self) {
			self = .one(value)
		} else {
			self = .each(try container.decode([String: T].self))
		}
	}

	func value(_ language: String) -> T? {
		switch self {
		case .one(let value): return value
		case .each(let values): return values[language] ?? values["en"]
		}
	}
}

struct Spec: Decodable {
	struct Clip: Decodable {
		let file: String
		let still: String
		let crop: [Double]?
		let radius: Double?
		let join: Bool?
		let `in`: PerLanguage<Double>?
		let out: PerLanguage<Double>?
		let headline: [String: String]
		let subtitle: [String: String]?
	}

	struct Preview: Decodable {
		let name: String
		let clips: [Clip]
	}

	let canvas: [Int]?
	let fps: Int?
	let crossfade: Double?
	let raw: String?
	let output: String?
	let languages: [String: String]
	let previews: [Preview]
}

guard CommandLine.arguments.count == 2 else {
	fail("usage: appstore-previews.swift <previews.json>")
}

let specURL = URL(fileURLWithPath: CommandLine.arguments[1])
let baseURL = specURL.deletingLastPathComponent()
let spec: Spec

do {
	spec = try JSONDecoder().decode(Spec.self, from: Data(contentsOf: specURL))
} catch {
	fail("Can't read \(specURL.path): \(error)")
}

let canvasWidth = spec.canvas?.first ?? 1920
let canvasHeight = spec.canvas?.last ?? 1080
let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
let fps = spec.fps ?? 30
let crossfade = spec.crossfade ?? 0.4
let rawURL = baseURL.appendingPathComponent(spec.raw ?? "raw")
let outputURL = baseURL.appendingPathComponent(spec.output ?? ".")
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

let headlineTop: CGFloat = 46
let windowTop: CGFloat = 214
let sideMargin: CGFloat = 120

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
	CGColor(
		srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
		blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func makeContext(_ width: Int, _ height: Int) -> CGContext {
	guard let context = CGContext(
		data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
		bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
	else {
		fail("Can't allocate a \(width)x\(height) bitmap")
	}

	return context
}

// The background is the same for every frame: render it once.
let background: CGImage = {
	let context = makeContext(canvasWidth, canvasHeight)
	let gradient = CGGradient(colorsSpace: sRGB, colors: [color(0x0B2F6E), color(0x1D63C9), color(0x3F95F2)] as CFArray, locations: [0, 0.55, 1])!

	context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: canvasSize.height), end: CGPoint(x: canvasSize.width, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

	let glow = CGGradient(colorsSpace: sRGB, colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
	let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.42)

	context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: canvasSize.width * 0.55, options: [])

	return context.makeImage()!
}()

// Headline and subtitle on a transparent canvas, so they can fade with their clip.
func captionImage(headline: String, subtitle: String?) -> CGImage {
	let context = makeContext(canvasWidth, canvasHeight)
	let graphics = NSGraphicsContext(cgContext: context, flipped: false)

	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = graphics

	func draw(_ text: String, font: NSFont, color: NSColor, top: CGFloat) -> CGFloat {
		let paragraph = NSMutableParagraphStyle()

		paragraph.alignment = .center

		let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph, .kern: font.pointSize > 30 ? -0.8 : 0])
		let width = canvasSize.width - sideMargin * 2
		let bounds = string.boundingRect(with: CGSize(width: width, height: 400), options: [.usesLineFragmentOrigin, .usesFontLeading])
		let height = ceil(bounds.height)

		string.draw(with: CGRect(x: sideMargin, y: canvasSize.height - top - height, width: width, height: height), options: [.usesLineFragmentOrigin, .usesFontLeading])

		return height
	}

	let used = draw(headline, font: .systemFont(ofSize: 60, weight: .bold), color: .white, top: headlineTop)

	if let subtitle {
		_ = draw(subtitle, font: .systemFont(ofSize: 28, weight: .medium), color: NSColor(white: 1, alpha: 0.86), top: headlineTop + used + 14)
	}

	NSGraphicsContext.restoreGraphicsState()

	return context.makeImage()!
}

// The still's alpha as a grayscale image, the form CGContext.clip(to:mask:) wants.
func maskImage(from still: CGImage) -> CGImage {
	let width = still.width, height = still.height
	guard let alpha = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else {
		fail("Can't allocate a mask")
	}

	alpha.draw(still, in: CGRect(x: 0, y: 0, width: width, height: height))

	let data = Data(bytes: alpha.data!, count: width * height)

	return CGImage(
		width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
		bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

// The still cut to a rounded rectangle, so its alpha gives the panel's shape and shadow.
func roundedPanel(_ image: CGImage, radius: CGFloat) -> CGImage {
	let context = makeContext(image.width, image.height)
	let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)

	context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
	context.clip()
	context.draw(image, in: rect)

	return context.makeImage()!
}

// Reads a clip's frames forward only, holding the last frame between samples
// (the recorder only writes a frame when the window changes).
final class ClipReader {
	let reader: AVAssetReader
	let output: AVAssetReaderTrackOutput
	let start: Double
	var origin: Double?
	var current: CGImage?
	var pending: CMSampleBuffer?
	var exhausted = false

	init(url: URL, start: Double) throws {
		let asset = AVURLAsset(url: url)
		let semaphore = DispatchSemaphore(value: 0)
		nonisolated(unsafe) var tracks: [AVAssetTrack] = []

		Task {
			tracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
			semaphore.signal()
		}

		semaphore.wait()

		guard let track = tracks.first else {
			fail("No video track in \(url.path)")
		}

		reader = try AVAssetReader(asset: asset)
		output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
		output.alwaysCopiesSampleData = false
		reader.add(output)
		self.start = start

		guard reader.startReading() else {
			fail("Can't read \(url.path): \(String(describing: reader.error))")
		}
	}

	func image(of sample: CMSampleBuffer) -> CGImage? {
		guard let buffer = sample.imageBuffer else {
			return nil
		}

		CVPixelBufferLockBaseAddress(buffer, .readOnly)
		defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

		let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer), bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
		let data = Data(bytes: CVPixelBufferGetBaseAddress(buffer)!, count: bytesPerRow * height)

		// The window is opaque inside the still's mask, so the alpha isn't needed.
		return CGImage(
			width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: sRGB,
			bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
			provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
	}

	// Frame shown at `time` seconds into the clip (before trimming).
	func frame(at time: Double) -> CGImage? {
		while exhausted == false {
			if pending == nil {
				pending = output.copyNextSampleBuffer()

				if pending == nil {
					exhausted = true
					break
				}
			}

			let presentation = pending!.presentationTimeStamp.seconds

			if origin == nil {
				origin = presentation
			}

			guard presentation - origin! <= time else {
				break
			}

			if let image = image(of: pending!) {
				current = image
			}

			pending = nil
		}

		return current
	}
}

struct PreparedClip {
	let reader: ClipReader
	let still: CGImage
	let mask: CGImage
	let crop: CGRect?
	let join: Bool
	let caption: CGImage
	let start: Double
	let duration: Double
	let rect: CGRect
}

func duration(of url: URL) -> Double {
	let asset = AVURLAsset(url: url)
	let semaphore = DispatchSemaphore(value: 0)
	nonisolated(unsafe) var seconds = 0.0

	Task {
		seconds = (try? await asset.load(.duration).seconds) ?? 0
		semaphore.signal()
	}

	semaphore.wait()

	return seconds
}

func prepare(_ clip: Spec.Clip, language: String) throws -> PreparedClip {
	let directory = rawURL.appendingPathComponent(language)
	let movie = directory.appendingPathComponent(clip.file)
	let stillURL = directory.appendingPathComponent(clip.still)

	guard var still = NSImage(contentsOf: stillURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
		fail("Can't read \(stillURL.path)")
	}

	var crop: CGRect?
	var mask: CGImage

	if let values = clip.crop, values.count == 4 {
		let rect = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])

		guard let cropped = still.cropping(to: rect) else {
			fail("\(language)/\(clip.still): crop \(values) is outside the image")
		}

		crop = rect
		still = roundedPanel(cropped, radius: CGFloat(clip.radius ?? 12))
		mask = maskImage(from: still)
	} else {
		mask = maskImage(from: still)
	}

	let start = clip.in?.value(language) ?? 0
	let end = clip.out?.value(language) ?? duration(of: movie)

	guard end > start else {
		fail("\(language)/\(clip.file): out (\(end)) must be after in (\(start))")
	}

	let size = CGSize(width: still.width, height: still.height)
	let rect = CGRect(x: floor((canvasSize.width - size.width) / 2), y: canvasSize.height - windowTop - size.height, width: size.width, height: size.height)
	let headline = clip.headline[language] ?? clip.headline["en"] ?? ""
	let subtitle = clip.subtitle?[language] ?? clip.subtitle?["en"]

	return PreparedClip(
		reader: try ClipReader(url: movie, start: start), still: still, mask: mask, crop: crop, join: clip.join ?? false,
		caption: captionImage(headline: headline, subtitle: subtitle), start: start, duration: end - start, rect: rect)
}

func draw(_ clip: PreparedClip, at time: Double, alpha: CGFloat, in context: CGContext) {
	guard alpha > 0 else {
		return
	}

	context.saveGState()
	context.setAlpha(alpha)
	context.draw(clip.caption, in: CGRect(origin: .zero, size: canvasSize))

	// Shadow from the still, then the live frame cut to the window's shape.
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: -20), blur: 56, color: color(0x000000, 0.45))
	context.draw(clip.still, in: clip.rect)
	context.restoreGState()

	context.saveGState()
	context.clip(to: clip.rect, mask: clip.mask)

	if var frame = clip.reader.frame(at: clip.start + time) {
		if let crop = clip.crop, let cropped = frame.cropping(to: crop) {
			frame = cropped
		}

		context.draw(frame, in: CGRect(x: clip.rect.minX, y: clip.rect.maxY - CGFloat(frame.height), width: CGFloat(frame.width), height: CGFloat(frame.height)))
	}

	context.restoreGState()
	context.restoreGState()
}

func render(_ preview: Spec.Preview, language: String, to destination: URL) throws {
	let clips = try preview.clips.map { try prepare($0, language: language) }
	var starts: [Double] = []
	var cursor = 0.0

	// A clip overlaps the next one by the cross-fade, unless the next one joins it.
	func overlap(after index: Int) -> Double {
		index + 1 < clips.count && clips[index + 1].join == false ? crossfade : 0
	}

	for (index, clip) in clips.enumerated() {
		starts.append(cursor)
		cursor += clip.duration - overlap(after: index)
	}

	let total = cursor

	if total < 15 || total > 30 {
		print("warning: \(language)/\(preview.name) lasts \(String(format: "%.1f", total))s; App Store previews must last 15 to 30 seconds")
	}

	let videoURL = destination.deletingPathExtension().appendingPathExtension("video.mp4")

	try? FileManager.default.removeItem(at: videoURL)

	let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
	let input = AVAssetWriterInput(
		mediaType: .video,
		outputSettings: [
			AVVideoCodecKey: AVVideoCodecType.h264,
			AVVideoWidthKey: canvasWidth,
			AVVideoHeightKey: canvasHeight,
			AVVideoColorPropertiesKey: [
				AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
				AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
				AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
			],
			AVVideoCompressionPropertiesKey: [
				AVVideoAverageBitRateKey: 11_000_000,
				AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
				AVVideoExpectedSourceFrameRateKey: fps,
				AVVideoMaxKeyFrameIntervalKey: fps,
			],
		])
	let adaptor = AVAssetWriterInputPixelBufferAdaptor(
		assetWriterInput: input,
		sourcePixelBufferAttributes: [
			kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
			kCVPixelBufferWidthKey as String: canvasWidth,
			kCVPixelBufferHeightKey as String: canvasHeight,
		])

	writer.add(input)
	writer.startWriting()
	writer.startSession(atSourceTime: .zero)

	let frameCount = Int((total * Double(fps)).rounded())

	for index in 0..<frameCount {
		let time = Double(index) / Double(fps)
		let context = makeContext(canvasWidth, canvasHeight)

		context.interpolationQuality = .high
		context.draw(background, in: CGRect(origin: .zero, size: canvasSize))

		for (clipIndex, clip) in clips.enumerated() {
			let local = time - starts[clipIndex]

			guard local >= 0, local < clip.duration else {
				continue
			}

			// Fade out over the first half of the overlap, in over the second.
			var alpha = 1.0
			let half = crossfade / 2

			if clipIndex > 0, clip.join == false, local < crossfade {
				alpha = max(0, local - half) / half
			}

			if overlap(after: clipIndex) > 0, local > clip.duration - crossfade {
				alpha = min(alpha, max(0, clip.duration - half - local) / half)
			}

			draw(clip, at: local, alpha: CGFloat(alpha), in: context)
		}

		while input.isReadyForMoreMediaData == false {
			Thread.sleep(forTimeInterval: 0.005)
		}

		guard let pool = adaptor.pixelBufferPool else {
			fail("No pixel buffer pool: \(String(describing: writer.error))")
		}

		var buffer: CVPixelBuffer?

		CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)

		guard let buffer, let image = context.makeImage() else {
			fail("Can't allocate a frame")
		}

		CVPixelBufferLockBaseAddress(buffer, [])

		let target = makeTargetContext(buffer)

		target.draw(image, in: CGRect(origin: .zero, size: canvasSize))
		CVPixelBufferUnlockBaseAddress(buffer, [])

		adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps)))
	}

	input.markAsFinished()

	let semaphore = DispatchSemaphore(value: 0)

	writer.finishWriting { semaphore.signal() }
	semaphore.wait()

	guard writer.status == .completed else {
		fail("Can't write \(videoURL.path): \(String(describing: writer.error))")
	}

	try addSilentAudio(video: videoURL, to: destination)
	try? FileManager.default.removeItem(at: videoURL)
	print("wrote \(destination.lastPathComponent) (\(String(format: "%.1f", total))s)")
}

func makeTargetContext(_ buffer: CVPixelBuffer) -> CGContext {
	guard let context = CGContext(
		data: CVPixelBufferGetBaseAddress(buffer), width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer), bitsPerComponent: 8,
		bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: sRGB,
		bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
	else {
		fail("Can't wrap a pixel buffer")
	}

	return context
}

func addSilentAudio(video: URL, to destination: URL) throws {
	let ffmpeg = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].first { FileManager.default.isExecutableFile(atPath: $0) }

	guard let ffmpeg else {
		fail("ffmpeg is needed to add the silent audio track (brew install ffmpeg)")
	}

	let process = Process()

	process.executableURL = URL(fileURLWithPath: ffmpeg)
	process.arguments = [
		"-v", "error", "-y", "-i", video.path, "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
		"-c:v", "copy", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", destination.path,
	]
	try process.run()
	process.waitUntilExit()

	guard process.terminationStatus == 0 else {
		fail("ffmpeg failed on \(video.lastPathComponent)")
	}
}

var written = 0

for (language, locale) in spec.languages.sorted(by: { $0.key < $1.key }) {
	let directory = outputURL.appendingPathComponent(locale)

	try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

	for (index, preview) in spec.previews.enumerated() {
		let missing = preview.clips.first { clip in
			[clip.file, clip.still].contains { FileManager.default.fileExists(atPath: rawURL.appendingPathComponent(language).appendingPathComponent($0).path) == false }
		}

		if let missing {
			print("skip  \(language)/\(preview.name): \(missing.file) or \(missing.still) not recorded")
			continue
		}

		do {
			try render(preview, language: language, to: directory.appendingPathComponent(String(format: "%02d-%@.mp4", index + 1, preview.name)))
			written += 1
		} catch {
			fail("Can't render \(language)/\(preview.name): \(error)")
		}
	}
}

print("\(written) preview(s) written to \(outputURL.standardizedFileURL.path)")
