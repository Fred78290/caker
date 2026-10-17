#!/usr/bin/env swift
//
// Lay raw Caker.app window captures onto App Store screenshot canvases
// (1440x900, one of the sizes App Store Connect accepts for Mac apps), with a
// localized headline above each window.
//
//   swift Scripts/appstore-screenshots.swift appstore/screenshots/shots.json
//
// The JSON file lists the languages and the shots:
//
//   {
//     "canvas": [1440, 900],
//     "raw": "raw",                    // raw captures: <raw>/<lang>/<file>
//     "output": ".",                   // results: <output>/<locale>/<NN>-<file>
//     "languages": { "en": "en-US", "fr": "fr-FR" },
//     "shots": [
//       { "file": "home.png", "fit": "crop",
//         "headline": { "en": "...", "fr": "..." },
//         "subtitle": { "en": "...", "fr": "..." } }
//     ]
//   }
//
// Paths are relative to the JSON file. A raw capture is a window taken with
// `screencapture -o -l <window id>` (no shadow, transparent corners): the
// script draws its own shadow. A window taller than the space under the
// headline is either cropped at the bottom edge of the canvas ("fit": "crop",
// keeps the UI at 1:1 so it stays sharp) or scaled down ("fit": "scale").

import AppKit
import Foundation

struct Spec: Decodable {
	struct Shot: Decodable {
		let file: String
		let fit: String?
		let headline: [String: String]
		let subtitle: [String: String]?
	}

	let canvas: [Int]?
	let raw: String?
	let output: String?
	let languages: [String: String]
	let shots: [Shot]
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
	NSColor(
		srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
		green: CGFloat((hex >> 8) & 0xFF) / 255,
		blue: CGFloat(hex & 0xFF) / 255,
		alpha: alpha)
}

func fail(_ message: String) -> Never {
	FileHandle.standardError.write(Data((message + "\n").utf8))
	exit(1)
}

guard CommandLine.arguments.count == 2 else {
	fail("usage: appstore-screenshots.swift <shots.json>")
}

let specURL = URL(fileURLWithPath: CommandLine.arguments[1])
let baseURL = specURL.deletingLastPathComponent()
let spec: Spec

do {
	spec = try JSONDecoder().decode(Spec.self, from: Data(contentsOf: specURL))
} catch {
	fail("Can't read \(specURL.path): \(error)")
}

let canvasWidth = spec.canvas?.first ?? 1440
let canvasHeight = spec.canvas?.last ?? 900
let rawURL = baseURL.appendingPathComponent(spec.raw ?? "raw")
let outputURL = baseURL.appendingPathComponent(spec.output ?? ".")

let sideMargin: CGFloat = 96
let headlineTop: CGFloat = 46
let windowTop: CGFloat = 176
let bottomMargin: CGFloat = 40

// Draws `text` centered horizontally, with its top at `top` (measured from
// the top of the canvas), and returns the height it used.
@discardableResult
func drawCentered(_ text: String, font: NSFont, color: NSColor, top: CGFloat, width: CGFloat, canvas: CGSize) -> CGFloat {
	let paragraph = NSMutableParagraphStyle()
	paragraph.alignment = .center
	paragraph.lineBreakMode = .byWordWrapping

	let attributes: [NSAttributedString.Key: Any] = [
		.font: font,
		.foregroundColor: color,
		.paragraphStyle: paragraph,
		.kern: font.pointSize > 30 ? -0.6 : 0,
	]
	let string = NSAttributedString(string: text, attributes: attributes)
	let bounds = string.boundingRect(with: CGSize(width: width, height: 400), options: [.usesLineFragmentOrigin, .usesFontLeading])
	let rect = CGRect(x: (canvas.width - width) / 2, y: canvas.height - top - ceil(bounds.height), width: width, height: ceil(bounds.height))

	string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])

	return ceil(bounds.height)
}

func drawBackground(in context: CGContext, size: CGSize) {
	let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
	let colors = [color(0x0B2F6E).cgColor, color(0x1D63C9).cgColor, color(0x3F95F2).cgColor] as CFArray
	let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.55, 1])!

	context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

	// A soft light behind the window, so it doesn't sit on a flat gradient.
	let glow = CGGradient(colorsSpace: colorSpace, colors: [color(0xFFFFFF, 0.22).cgColor, color(0xFFFFFF, 0).cgColor] as CFArray, locations: [0, 1])!
	let center = CGPoint(x: size.width / 2, y: size.height * 0.42)

	context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width * 0.55, options: [])
}

func render(shot: Spec.Shot, language: String, image: NSImage, to destination: URL) throws {
	let size = CGSize(width: canvasWidth, height: canvasHeight)

	guard let bitmap = NSBitmapImageRep(
		bitmapDataPlanes: nil, pixelsWide: canvasWidth, pixelsHigh: canvasHeight, bitsPerSample: 8, samplesPerPixel: 4,
		hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
	else {
		fail("Can't allocate the canvas")
	}

	// One point per pixel: the raw captures come from a 1x display.
	bitmap.size = size

	guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
		fail("Can't create a graphics context")
	}

	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = graphics
	graphics.imageInterpolation = .high

	let context = graphics.cgContext

	drawBackground(in: context, size: size)

	let headline = shot.headline[language] ?? shot.headline["en"] ?? ""
	let subtitle = shot.subtitle?[language] ?? shot.subtitle?["en"]
	let textWidth = size.width - sideMargin * 2
	let headlineHeight = drawCentered(headline, font: .systemFont(ofSize: 46, weight: .bold), color: .white, top: headlineTop, width: textWidth, canvas: size)

	if let subtitle {
		drawCentered(subtitle, font: .systemFont(ofSize: 22, weight: .medium), color: color(0xFFFFFF, 0.86), top: headlineTop + headlineHeight + 12, width: textWidth, canvas: size)
	}

	// Window: centered, 1:1 unless it has to be scaled down.
	let pixelWidth = CGFloat(image.representations.first?.pixelsWide ?? Int(image.size.width))
	let pixelHeight = CGFloat(image.representations.first?.pixelsHigh ?? Int(image.size.height))
	let availableWidth = size.width - 80
	let availableHeight = size.height - windowTop - bottomMargin
	var scale = min(1, availableWidth / pixelWidth)

	if shot.fit == "scale" {
		scale = min(scale, availableHeight / pixelHeight)
	}

	let windowSize = CGSize(width: round(pixelWidth * scale), height: round(pixelHeight * scale))
	var top = windowTop

	if windowSize.height < availableHeight {
		top += floor((availableHeight - windowSize.height) / 2)
	}

	let rect = CGRect(x: floor((size.width - windowSize.width) / 2), y: size.height - top - windowSize.height, width: windowSize.width, height: windowSize.height)

	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: color(0x000000, 0.45).cgColor)
	image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high.rawValue])
	context.restoreGState()

	NSGraphicsContext.restoreGraphicsState()

	// App Store Connect rejects screenshots with an alpha channel: flatten.
	guard let cgImage = bitmap.cgImage,
		let opaque = CGContext(
			data: nil, width: canvasWidth, height: canvasHeight, bitsPerComponent: 8, bytesPerRow: 0,
			space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
	else {
		fail("Can't flatten the canvas")
	}

	opaque.draw(cgImage, in: CGRect(origin: .zero, size: size))

	guard let flattened = opaque.makeImage(),
		let png = NSBitmapImageRep(cgImage: flattened).representation(using: .png, properties: [:])
	else {
		fail("Can't encode \(destination.lastPathComponent)")
	}

	try png.write(to: destination)
}

var written = 0

for (language, locale) in spec.languages.sorted(by: { $0.key < $1.key }) {
	let directory = outputURL.appendingPathComponent(locale)

	try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

	for (index, shot) in spec.shots.enumerated() {
		let source = rawURL.appendingPathComponent(language).appendingPathComponent(shot.file)

		guard let image = NSImage(contentsOf: source) else {
			print("skip  \(language)/\(shot.file): no raw capture")
			continue
		}

		let destination = directory.appendingPathComponent(String(format: "%02d-%@", index + 1, shot.file))

		do {
			try render(shot: shot, language: language, image: image, to: destination)
			written += 1
			print("wrote \(locale)/\(destination.lastPathComponent)")
		} catch {
			fail("Can't write \(destination.path): \(error)")
		}
	}
}

print("\(written) screenshot(s) written to \(outputURL.standardizedFileURL.path)")
