import CoreGraphics

/// How big a Windows guest's display can be.
///
/// virtio-win's display driver (`viogpudo`) allocates its frame segment once, when it starts: at least 16 MiB, or what
/// the display it started with needs if that is more. A mode whose surface (width x height x 4 bytes) doesn't fit is
/// refused (`DISP_CHANGE_BADMODE`), and a refused mode can leave Windows with a stale list of modes, so the next sizes
/// are refused too until the guest restarts. A host window bigger than that must therefore not be sent to the guest as
/// its display size: the display is kept inside the limit, and the view scales it to the window.
public enum WindowsDisplayLimit {
	/// The stock driver's smallest frame segment, in MiB. caker's build raises it to 32 on Virtualization.framework's GPU
	/// (`WindowsGPUDriverBinaries.frameSegmentMiB`, recorded in `CakeConfig.windowsFrameSegmentMiB` at install).
	public static let defaultSegmentMiB = 16
	static let bytesPerPixel = 4

	/// Most pixels a display may have, given the frame segment (MiB) of the guest's driver and the size the guest
	/// started with.
	public static func maxPixels(booted: CGSize, segmentMiB: Int? = nil) -> Int {
		max((segmentMiB ?? defaultSegmentMiB) * 1024 * 1024 / bytesPerPixel, Int(booted.width) * Int(booted.height))
	}

	/// `size`, shrunk to fit `maxPixels` with the same aspect ratio (each side even, as displays like), or unchanged
	/// when it already fits.
	public static func clamp(_ size: CGSize, maxPixels: Int) -> CGSize {
		let pixels = Double(size.width) * Double(size.height)

		guard pixels > Double(maxPixels), pixels > 0 else {
			return size
		}

		let scale = (Double(maxPixels) / pixels).squareRoot()
		let width = (Int(Double(size.width) * scale) / 2) * 2
		let height = (Int(Double(size.height) * scale) / 2) * 2

		return CGSize(width: width, height: height)
	}

	/// `size` with its width rounded down to a multiple of 4 pixels. A display whose rows are not a multiple of 16 bytes
	/// (4 bytes a pixel) is shown black by the VM's view: Core Animation refuses the surface ("doesn't have the proper data
	/// alignment! Expected 16 base address and 16 row byte alignment"), although the guest renders it correctly. A window
	/// on a 1x screen can be any width, so the display asked for must be aligned; the view scales the few pixels back.
	public static func aligned(_ size: CGSize) -> CGSize {
		let width = (Int(size.width) / rowAlignmentPixels) * rowAlignmentPixels

		return CGSize(width: CGFloat(max(width, rowAlignmentPixels)), height: size.height)
	}

	/// 16 bytes at 4 bytes a pixel.
	static let rowAlignmentPixels = 4
}
