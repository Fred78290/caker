import Foundation
import AppKit

public class VNCFramebuffer {
    public internal(set) var width: Int
    public internal(set) var height: Int
    public internal(set) var pixelData: Data
    public internal(set) var hasChanges = false
    public internal(set) var sizeChanged = false
    
    public weak var sourceView: NSView?
    internal var previousPixelData: Data?
    internal let updateQueue = DispatchQueue(label: "vnc.framebuffer.update")
    
    public init(view: NSView) {
        self.sourceView = view
        self.width = Int(view.bounds.width)
        self.height = Int(view.bounds.height)
        self.pixelData = Data(count: width * height * 4) // RGBA
    }
    
    public func updateSize(width: Int, height: Int) {
        updateQueue.async {
            guard self.width != width || self.height != height else { return }
            
            self.width = width
            self.height = height
            self.pixelData = Data(count: width * height * 4)
            self.previousPixelData = nil
            self.sizeChanged = true
            self.hasChanges = true
        }
    }
    
    public func updateFromView() {
        guard let view = sourceView else { return }
        
        updateQueue.async {
            let bounds = view.bounds
            let newWidth = Int(bounds.width)
            let newHeight = Int(bounds.height)
            
            // Check if size has changed
            if self.width != newWidth || self.height != newHeight {
                self.updateSize(width: newWidth, height: newHeight)
            }
            
            // Capture content
            DispatchQueue.main.sync {
                self.captureViewContent(view: view, bounds: bounds)
            }
        }
    }
    
    internal func captureViewContent(view: NSView, bounds: NSRect) {
        // Create image from view
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        
        // Draw view into image
        if let context = NSGraphicsContext.current?.cgContext {
            context.clear(bounds)
            view.layer?.render(in: context)
        }
        
        image.unlockFocus()
        
        // Convert to pixel data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return
        }
        
        convertBitmapToPixelData(bitmap: bitmap)
    }
    
    private func convertBitmapToPixelData(bitmap: NSBitmapImageRep) {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        pixelData.withUnsafeMutableBytes { bytes in
            guard let pixels = bytes.bindMemory(to: UInt8.self).baseAddress else { return }
            
            for y in 0..<height {
                for x in 0..<width {
                    let color = bitmap.colorAt(x: x, y: y) ?? NSColor.black
                    let srgbColor = color.usingColorSpace(.sRGB) ?? color
                    
                    let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                    pixels[offset + 0] = UInt8(srgbColor.redComponent * 255)     // R
                    pixels[offset + 1] = UInt8(srgbColor.greenComponent * 255)   // G
                    pixels[offset + 2] = UInt8(srgbColor.blueComponent * 255)    // B
                    pixels[offset + 3] = UInt8(srgbColor.alphaComponent * 255)   // A
                }
            }
        }
        
        // Check for changes
        if previousPixelData != pixelData {
            hasChanges = true
            previousPixelData = pixelData
        }
    }
    
    public func markAsProcessed() {
        updateQueue.async {
            self.hasChanges = false
            self.sizeChanged = false
        }
    }
    
    public func getCurrentState() -> (width: Int, height: Int, data: Data, hasChanges: Bool, sizeChanged: Bool) {
        return updateQueue.sync {
            return (width: width, height: height, data: pixelData, hasChanges: hasChanges, sizeChanged: sizeChanged)
        }
    }
}
