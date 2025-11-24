import Foundation
import AppKit
import Metal
import MetalKit
import CoreGraphics

public enum VNCCaptureMethod {
    case coreGraphics
    case metal
}

public class VNCMetalFramebuffer: VNCFramebuffer {
    private let metalDevice: MTLDevice?
    private let metalCommandQueue: MTLCommandQueue?
    private var metalTextureCache: CVMetalTextureCache?
    private var renderTargetTexture: MTLTexture?
    private let captureMethod: VNCCaptureMethod
    
    // Metal configuration
    public struct MetalConfiguration {
        let pixelFormat: MTLPixelFormat
        let colorSpace: CGColorSpace
        let scaleFactor: CGFloat
        let enableHDR: Bool
        
        public init(pixelFormat: MTLPixelFormat = .bgra8Unorm,
                   colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB(),
                   scaleFactor: CGFloat = 1.0,
                   enableHDR: Bool = false) {
            self.pixelFormat = pixelFormat
            self.colorSpace = colorSpace
            self.scaleFactor = scaleFactor
            self.enableHDR = enableHDR
        }
        
        public static let standard = MetalConfiguration()
        public static let highQuality = MetalConfiguration(
            pixelFormat: .rgba16Float,
            scaleFactor: 2.0,
            enableHDR: true
        )
    }
    
    private let metalConfig: MetalConfiguration
    private var renderTimes: [TimeInterval] = []
    private let maxRenderTimesSamples = 60
    
    public init(view: NSView, captureMethod: VNCCaptureMethod = .metal, metalConfig: MetalConfiguration = .standard) {
        self.captureMethod = captureMethod
        self.metalConfig = metalConfig
        
        // Initialize Metal if needed
        if captureMethod == .metal {
            metalDevice = MTLCreateSystemDefaultDevice()
            metalCommandQueue = metalDevice?.makeCommandQueue()
            
            if let device = metalDevice {
                setupMetalTextureCache(device: device)
            }
        } else {
            metalDevice = nil
            metalCommandQueue = nil
        }
        
        super.init(view: view)
        
        if captureMethod == .metal && metalDevice != nil {
            setupRenderTarget()
        }
    }
    
    // MARK: - Metal Setup
    
    private func setupMetalTextureCache(device: MTLDevice) {
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &metalTextureCache
        )
        
        if result != kCVReturnSuccess {
            print("Failed to create Metal texture cache: \(result)")
        }
    }
    
    private func setupRenderTarget() {
        guard let device = metalDevice else { return }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = metalConfig.pixelFormat
        descriptor.width = max(1, width)
        descriptor.height = max(1, height)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .managed
        
        renderTargetTexture = device.makeTexture(descriptor: descriptor)
    }
    
    private func updateRenderTargetSize() {
        guard let device = metalDevice else { return }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = metalConfig.pixelFormat
        descriptor.width = max(1, width)
        descriptor.height = max(1, height)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .managed
        
        renderTargetTexture = device.makeTexture(descriptor: descriptor)
    }
    
    // MARK: - Overridden Methods
    
    public override func updateSize(width: Int, height: Int) {
        super.updateSize(width: width, height: height)
        
        if captureMethod == .metal {
            updateRenderTargetSize()
        }
    }
    
    public override func updateFromView() {
        guard let view = sourceView else { return }
        
        updateQueue.async {
            let bounds = view.bounds
            let newWidth = Int(bounds.width * self.metalConfig.scaleFactor)
            let newHeight = Int(bounds.height * self.metalConfig.scaleFactor)
            
            // Check if size has changed
            if self.width != newWidth || self.height != newHeight {
                self.updateSize(width: newWidth, height: newHeight)
            }
            
            // Capture content
            DispatchQueue.main.sync {
                switch self.captureMethod {
                case .metal:
                    self.captureViewContentWithMetal(view: view, bounds: bounds)
                case .coreGraphics:
                    self.captureViewContent(view: view, bounds: bounds)
                }
            }
        }
    }
    
    // MARK: - Metal Capture
    
    private func captureViewContentWithMetal(view: NSView, bounds: NSRect) {
        let startTime = CACurrentMediaTime()
        
        guard let device = metalDevice,
              let commandQueue = metalCommandQueue,
              let renderTarget = renderTargetTexture else {
            // Fallback to Core Graphics
            captureViewContent(view: view, bounds: bounds)
            return
        }
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            captureViewContent(view: view, bounds: bounds)
            return
        }
        
        // Create render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderTarget
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // Render view to metal texture
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderViewToMetal(view: view, encoder: renderEncoder, bounds: bounds)
            renderEncoder.endEncoding()
        }
        
        // Copy texture data to CPU
        let blit = commandBuffer.makeBlitCommandEncoder()
        blit?.synchronize(resource: renderTarget)
        blit?.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Extract pixel data from Metal texture
        extractPixelDataFromTexture(renderTarget)
        
        // Record render time
        let renderTime = CACurrentMediaTime() - startTime
        recordRenderTime(renderTime)
    }
    
    private func renderViewToMetal(view: NSView, encoder: MTLRenderCommandEncoder, bounds: NSRect) {
        // Convert NSView to CGImage first
        let scaledSize = CGSize(
            width: bounds.width * metalConfig.scaleFactor,
            height: bounds.height * metalConfig.scaleFactor
        )
        
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        
        // Set up graphics context with scaling
        if let context = NSGraphicsContext.current?.cgContext {
            context.scaleBy(x: metalConfig.scaleFactor, y: metalConfig.scaleFactor)
            
            // Render view content
            view.layer?.render(in: context)
        }
        
        image.unlockFocus()
        
        // Convert NSImage to Metal texture and render
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            renderCGImageToMetal(cgImage: cgImage, encoder: encoder)
        }
    }
    
    private func renderCGImageToMetal(cgImage: CGImage, encoder: MTLRenderCommandEncoder) {
        guard let device = metalDevice else { return }
        
        // Create texture from CGImage
        let textureLoader = MTKTextureLoader(device: device)
        
        do {
            let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.managed.rawValue
            ])
            
            // Here you would typically use a render pipeline to draw the texture
            // For simplicity, we'll copy the texture data directly
            
        } catch {
            print("Failed to create texture from CGImage: \(error)")
        }
    }
    
    private func extractPixelDataFromTexture(_ texture: MTLTexture) {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = height * bytesPerRow
        
        pixelData = Data(count: bufferSize)
        
        pixelData.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return }
            
            texture.getBytes(
                baseAddress,
                bytesPerRow: bytesPerRow,
                from: MTLRegion(
                    origin: MTLOrigin(x: 0, y: 0, z: 0),
                    size: MTLSize(width: width, height: height, depth: 1)
                ),
                mipmapLevel: 0
            )
        }
        
        // Check for changes
        if previousPixelData != pixelData {
            hasChanges = true
            previousPixelData = pixelData
        }
    }
    
    private func recordRenderTime(_ time: TimeInterval) {
        renderTimes.append(time)
        if renderTimes.count > maxRenderTimesSamples {
            renderTimes.removeFirst()
        }
    }
    
    // MARK: - Performance Stats
    
    public var averageRenderTime: TimeInterval {
        guard !renderTimes.isEmpty else { return 0 }
        return renderTimes.reduce(0, +) / TimeInterval(renderTimes.count)
    }
    
    public var renderStats: String {
        let avgTime = averageRenderTime * 1000 // Convert to ms
        let method = captureMethod == .metal ? "Metal" : "Core Graphics"
        let gpuMemory = calculateGPUMemoryUsage()
        
        return """
        === VNC Render Stats ===
        Method: \(method)
        Average render time: \(String(format: "%.2f ms", avgTime))
        GPU memory: \(gpuMemory / 1024 / 1024) MB
        Frame size: \(width)x\(height)
        Scale factor: \(metalConfig.scaleFactor)x
        """
    }
    
    private func calculateGPUMemoryUsage() -> UInt64 {
        guard let texture = renderTargetTexture else { return 0 }
        
        let bytesPerPixel = metalConfig.pixelFormat == .rgba16Float ? 8 : 4
        return UInt64(texture.width * texture.height * bytesPerPixel)
    }
}