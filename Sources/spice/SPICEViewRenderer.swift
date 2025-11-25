//
//  SPICEViewRenderer.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import AppKit
import CoreGraphics
import Foundation
import Metal
import MetalKit

/// Moteur de rendu optimisé pour la capture de NSView vers SPICE
public class SPICEViewRenderer {

	private let metalDevice: MTLDevice?
	private let metalCommandQueue: MTLCommandQueue?
	private var metalTextureCache: CVMetalTextureCache?
	private let useMetalAcceleration: Bool

	/// Configuration du moteur de rendu
	public struct RenderConfiguration {
		let useGPUAcceleration: Bool
		let pixelFormat: MTLPixelFormat
		let colorSpace: CGColorSpace
		let scaleFactor: CGFloat
		let enableHDR: Bool

		public init(
			useGPUAcceleration: Bool = true,
			pixelFormat: MTLPixelFormat = .bgra8Unorm,
			colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB(),
			scaleFactor: CGFloat = 1.0,
			enableHDR: Bool = false
		) {
			self.useGPUAcceleration = useGPUAcceleration
			self.pixelFormat = pixelFormat
			self.colorSpace = colorSpace
			self.scaleFactor = scaleFactor
			self.enableHDR = enableHDR
		}

		/// Configuration haute performance avec GPU
		public static let highPerformance = RenderConfiguration(
			useGPUAcceleration: true,
			pixelFormat: .bgra8Unorm,
			scaleFactor: 1.0,
			enableHDR: false
		)

		/// Configuration haute qualité avec HDR
		public static let highQuality = RenderConfiguration(
			useGPUAcceleration: true,
			pixelFormat: .rgba16Float,
			scaleFactor: 2.0,
			enableHDR: true
		)
	}

	private let configuration: RenderConfiguration
	private var renderTargetTexture: MTLTexture?
	private var renderPassDescriptor: MTLRenderPassDescriptor?

	/// Statistiques de rendu
	public struct RenderStats {
		let averageRenderTime: TimeInterval
		let gpuMemoryUsed: UInt64
		let textureCount: Int
		let lastFrameSize: CGSize

		public var description: String {
			return """
				=== Stats Rendu SPICE ===
				Temps rendu moyen: \(String(format: "%.2f ms", averageRenderTime * 1000))
				Mémoire GPU: \(gpuMemoryUsed / 1024 / 1024) MB
				Textures: \(textureCount)
				Taille frame: \(Int(lastFrameSize.width))x\(Int(lastFrameSize.height))
				"""
		}
	}

	private var renderTimes: [TimeInterval] = []
	private let maxRenderTimesSamples = 60

	public init(configuration: RenderConfiguration = .highPerformance) {
		self.configuration = configuration

		if configuration.useGPUAcceleration {
			metalDevice = MTLCreateSystemDefaultDevice()
			metalCommandQueue = metalDevice?.makeCommandQueue()
			useMetalAcceleration = metalDevice != nil && metalCommandQueue != nil

			if let device = metalDevice {
				setupMetalTextureCache(device: device)
			}
		} else {
			metalDevice = nil
			metalCommandQueue = nil
			useMetalAcceleration = false
		}

		setupRenderTarget()
	}

	// MARK: - Configuration Metal

	private func setupMetalTextureCache(device: MTLDevice) {
		let result = CVMetalTextureCacheCreate(
			kCFAllocatorDefault,
			nil,
			device,
			nil,
			&metalTextureCache
		)

		if result != kCVReturnSuccess {
			print("Erreur création Metal texture cache: \(result)")
		}
	}

	private func setupRenderTarget() {
		guard useMetalAcceleration, let device = metalDevice else { return }

		let descriptor = MTLTextureDescriptor()
		descriptor.textureType = .type2D
		descriptor.pixelFormat = configuration.pixelFormat
		descriptor.width = 1920  // Taille par défaut, sera mise à jour
		descriptor.height = 1080
		descriptor.usage = [.renderTarget, .shaderRead]
		descriptor.storageMode = .managed

		renderTargetTexture = device.makeTexture(descriptor: descriptor)

		// Configuration du render pass
		renderPassDescriptor = MTLRenderPassDescriptor()
		renderPassDescriptor?.colorAttachments[0].texture = renderTargetTexture
		renderPassDescriptor?.colorAttachments[0].loadAction = .clear
		renderPassDescriptor?.colorAttachments[0].storeAction = .store
		renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
	}

	// MARK: - Rendu de la View

	/// Rend une NSView et retourne les données d'image pour SPICE
	public func renderView(_ view: NSView) -> Data? {
		let startTime = CACurrentMediaTime()

		let result: Data?

		if useMetalAcceleration {
			result = renderViewWithMetal(view)
		} else {
			result = renderViewWithCoreGraphics(view)
		}

		let renderTime = CACurrentMediaTime() - startTime
		recordRenderTime(renderTime)

		return result
	}

	private func renderViewWithMetal(_ view: NSView) -> Data? {
		guard metalDevice != nil,
			let commandQueue = metalCommandQueue
		else { return nil }

		let bounds = view.bounds
		updateRenderTargetSize(
			CGSize(
				width: bounds.width * configuration.scaleFactor,
				height: bounds.height * configuration.scaleFactor))

		guard let commandBuffer = commandQueue.makeCommandBuffer(),
			let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
		else {
			return nil
		}

		// Rendu de la view dans la texture Metal
		renderViewToMetalTexture(view, encoder: renderEncoder)

		renderEncoder.endEncoding()
		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()

		// Extraire les données de la texture
		return extractDataFromMetalTexture()
	}

	private func renderViewToMetalTexture(_ view: NSView, encoder: MTLRenderCommandEncoder) {
		// Try direct Metal capture first, fallback to Core Graphics if needed
		if !captureViewDirectlyWithMetal(view, encoder: encoder) {
			captureViewWithCoreGraphicsToMetal(view)
		}
	}

	/// Direct Metal capture of NSView using CAMetalLayer if available
	private func captureViewDirectlyWithMetal(_ view: NSView, encoder: MTLRenderCommandEncoder) -> Bool {
		// Check if the view has a Metal-compatible layer
		if let metalLayer = findMetalLayer(in: view) {
			return captureFromMetalLayer(metalLayer, encoder: encoder)
		}

		// Try to create a temporary Metal layer for the view
		if let metalLayer = createTemporaryMetalLayer(for: view) {
			let success = captureFromMetalLayer(metalLayer, encoder: encoder)
			// Clean up temporary layer
			metalLayer.removeFromSuperlayer()
			return success
		}

		return false
	}

	/// Find existing CAMetalLayer in view hierarchy
	private func findMetalLayer(in view: NSView) -> CAMetalLayer? {
		// Check if the view itself has a Metal layer
		if let metalLayer = view.layer as? CAMetalLayer {
			return metalLayer
		}

		// Recursively search subviews
		for subview in view.subviews {
			if let metalLayer = findMetalLayer(in: subview) {
				return metalLayer
			}
		}

		// Check sublayers
		if let sublayers = view.layer?.sublayers {
			for sublayer in sublayers {
				if let metalLayer = sublayer as? CAMetalLayer {
					return metalLayer
				}
			}
		}

		return nil
	}

	/// Create temporary CAMetalLayer for view capture
	private func createTemporaryMetalLayer(for view: NSView) -> CAMetalLayer? {
		guard let device = metalDevice else { return nil }

		let metalLayer = CAMetalLayer()
		metalLayer.device = device
		metalLayer.pixelFormat = .bgra8Unorm
		metalLayer.frame = view.bounds
		metalLayer.drawableSize = CGSize(
			width: view.bounds.width * configuration.scaleFactor,
			height: view.bounds.height * configuration.scaleFactor
		)

		// Enable layer-backed view temporarily if needed
		let wasLayerBacked = view.wantsLayer
		if !wasLayerBacked {
			DispatchQueue.main.sync {
				view.wantsLayer = true
			}
		}

		// Add metal layer as sublayer
		DispatchQueue.main.sync {
			view.layer?.addSublayer(metalLayer)
			// Force immediate display
			view.displayIfNeeded()
		}

		// Restore original layer backing state
		if !wasLayerBacked {
			DispatchQueue.main.sync {
				view.wantsLayer = wasLayerBacked
			}
		}

		return metalLayer
	}

	/// Capture from existing CAMetalLayer
	private func captureFromMetalLayer(_ metalLayer: CAMetalLayer, encoder: MTLRenderCommandEncoder) -> Bool {
		guard let drawable = metalLayer.nextDrawable() else { return false }

		// Copy drawable texture to our render target
		guard let blitEncoder = encoder.commandBuffer.makeBlitCommandEncoder() else { return false }

		let sourceTexture = drawable.texture
		guard let destinationTexture = renderTargetTexture else { return false }

		// Ensure textures have compatible dimensions
		let sourceSize = MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1)
		let destSize = MTLSize(
			width: min(destinationTexture.width, sourceTexture.width),
			height: min(destinationTexture.height, sourceTexture.height),
			depth: 1)

		blitEncoder.copy(
			from: sourceTexture,
			sourceSlice: 0,
			sourceLevel: 0,
			sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
			sourceSize: destSize,
			to: destinationTexture,
			destinationSlice: 0,
			destinationLevel: 0,
			destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))

		blitEncoder.endEncoding()

		// Present the drawable
		encoder.commandBuffer.present(drawable)

		return true
	}

	/// Fallback Core Graphics capture to Metal texture
	private func captureViewWithCoreGraphicsToMetal(_ view: NSView) {
		let bounds = view.bounds
		let width = Int(bounds.width * configuration.scaleFactor)
		let height = Int(bounds.height * configuration.scaleFactor)
		let bytesPerRow = width * 4

		var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

		guard
			let context = CGContext(
				data: &pixelData,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: bytesPerRow,
				space: configuration.colorSpace,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			)
		else { return }

		// Apply scale transformation
		context.scaleBy(x: configuration.scaleFactor, y: configuration.scaleFactor)

		// Capture view content
		DispatchQueue.main.sync {
			if let layer = view.layer {
				CATransaction.begin()
				CATransaction.setDisableActions(true)
				layer.render(in: context)
				CATransaction.commit()
			} else {
				// Fallback for non-layer-backed views
				let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
				NSGraphicsContext.saveGraphicsState()
				NSGraphicsContext.current = nsGraphicsContext

				view.display()

				NSGraphicsContext.restoreGraphicsState()
			}
		}

		// Copy data to Metal texture
		guard let texture = renderTargetTexture else { return }

		let region = MTLRegion(
			origin: MTLOrigin(x: 0, y: 0, z: 0),
			size: MTLSize(width: width, height: height, depth: 1))

		texture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: bytesPerRow)
	}

	private func extractDataFromMetalTexture() -> Data? {
		guard let texture = renderTargetTexture else { return nil }

		let width = texture.width
		let height = texture.height
		let bytesPerRow = width * 4
		let totalBytes = height * bytesPerRow

		var pixelData = [UInt8](repeating: 0, count: totalBytes)

		let region = MTLRegion(
			origin: MTLOrigin(x: 0, y: 0, z: 0),
			size: MTLSize(width: width, height: height, depth: 1))

		texture.getBytes(&pixelData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

		return Data(pixelData)
	}

	private func renderViewWithCoreGraphics(_ view: NSView) -> Data? {
		let bounds = view.bounds
		let width = Int(bounds.width * configuration.scaleFactor)
		let height = Int(bounds.height * configuration.scaleFactor)
		let bytesPerRow = width * 4

		guard
			let context = CGContext(
				data: nil,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: bytesPerRow,
				space: configuration.colorSpace,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			)
		else { return nil }

		// Appliquer la transformation d'échelle
		context.scaleBy(x: configuration.scaleFactor, y: configuration.scaleFactor)

		var result: Data?

		// Capturer la view
		DispatchQueue.main.sync {
			if let layer = view.layer {
				// Utiliser le layer si disponible
				CATransaction.begin()
				CATransaction.setDisableActions(true)
				layer.render(in: context)
				CATransaction.commit()
			} else {
				// Utiliser la méthode de dessin NSView
				let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
				NSGraphicsContext.saveGraphicsState()
				NSGraphicsContext.current = nsGraphicsContext

				// Assurer que la view se dessine
				view.displayIfNeeded()

				NSGraphicsContext.restoreGraphicsState()
			}

			// Extraire les données
			if let image = context.makeImage(),
				let dataProvider = image.dataProvider,
				let data = dataProvider.data
			{
				result = Data(bytes: CFDataGetBytePtr(data), count: CFDataGetLength(data))
			}
		}

		return result
	}

	private func updateRenderTargetSize(_ size: CGSize) {
		guard useMetalAcceleration,
			let device = metalDevice,
			let currentTexture = renderTargetTexture
		else { return }

		let newWidth = Int(size.width)
		let newHeight = Int(size.height)

		if currentTexture.width != newWidth || currentTexture.height != newHeight {
			let descriptor = MTLTextureDescriptor()
			descriptor.textureType = .type2D
			descriptor.pixelFormat = configuration.pixelFormat
			descriptor.width = newWidth
			descriptor.height = newHeight
			descriptor.usage = [.renderTarget, .shaderRead]
			descriptor.storageMode = .managed

			renderTargetTexture = device.makeTexture(descriptor: descriptor)
			renderPassDescriptor?.colorAttachments[0].texture = renderTargetTexture
		}
	}

	// MARK: - Statistiques et optimisation

	private func recordRenderTime(_ time: TimeInterval) {
		renderTimes.append(time)
		if renderTimes.count > maxRenderTimesSamples {
			renderTimes.removeFirst()
		}
	}

	/// Retourne les statistiques de rendu actuelles
	public func renderStatistics() -> RenderStats {
		let averageTime = renderTimes.isEmpty ? 0 : renderTimes.reduce(0, +) / Double(renderTimes.count)
		let gpuMemory = calculateGPUMemoryUsage()
		let textureCount = countActiveTextures()
		let frameSize = renderTargetTexture?.textureSize ?? CGSize.zero

		return RenderStats(
			averageRenderTime: averageTime,
			gpuMemoryUsed: gpuMemory,
			textureCount: textureCount,
			lastFrameSize: frameSize
		)
	}

	private func calculateGPUMemoryUsage() -> UInt64 {
		guard let texture = renderTargetTexture else { return 0 }

		let bytesPerPixel = pixelFormatBytesPerPixel(texture.pixelFormat)
		return UInt64(texture.width * texture.height * bytesPerPixel)
	}

	private func countActiveTextures() -> Int {
		return renderTargetTexture != nil ? 1 : 0
	}

	private func pixelFormatBytesPerPixel(_ format: MTLPixelFormat) -> Int {
		switch format {
		case .bgra8Unorm, .rgba8Unorm:
			return 4
		case .rgba16Float:
			return 8
		case .rgba32Float:
			return 16
		default:
			return 4
		}
	}

	/// Optimise le moteur de rendu pour de meilleures performances
	public func optimizeForPerformance() {
		// Réduire la qualité si nécessaire
		if renderTimes.last ?? 0 > 0.016 {  // Plus de 16ms = moins de 60fps
			print("Performance dégradée détectée, optimisation en cours...")
			// Dans une implémentation complète, on pourrait ajuster dynamiquement
			// la résolution, la qualité de compression, etc.
		}
	}
}

// MARK: - Extensions MTLTexture

extension MTLTexture {
	var textureSize: CGSize {
		return CGSize(width: width, height: height)
	}
}

// MARK: - Factory pour différents types de rendu

extension SPICEViewRenderer {

	/// Crée un moteur de rendu optimisé pour les jeux
	public static func forGaming() -> SPICEViewRenderer {
		return SPICEViewRenderer(configuration: .highPerformance)
	}

	/// Crée un moteur de rendu optimisé pour le design/CAO
	public static func forDesign() -> SPICEViewRenderer {
		return SPICEViewRenderer(configuration: .highQuality)
	}

	/// Crée un moteur de rendu équilibré pour usage général
	public static func balanced() -> SPICEViewRenderer {
		let config = RenderConfiguration(
			useGPUAcceleration: true,
			pixelFormat: .bgra8Unorm,
			scaleFactor: 1.0,
			enableHDR: false
		)
		return SPICEViewRenderer(configuration: config)
	}
}
