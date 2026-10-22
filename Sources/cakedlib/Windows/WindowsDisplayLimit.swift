import CoreGraphics

/// How big a Windows guest's display can be.
///
/// virtio-win's display driver (`viogpudo`) allocates its frame segment once, when it starts: at least 16 MiB, or what
/// the display it started with needs if that is more. A mode whose surface (width x height x 4 bytes) doesn't fit is
/// refused (`DISP_CHANGE_BADMODE`), and a refused mode can leave Windows with a stale list of modes, so the next sizes
/// are refused too until the guest restarts. A host window bigger than that must therefore not be sent to the guest as
/// its display size: the display is kept inside the limit, and the view scales it to the window.
public enum WindowsDisplayLimit {
	/// The driver's smallest frame segment.
	static let minimumSegmentBytes = 16 * 1024 * 1024
	static let bytesPerPixel = 4

	/// Most pixels a display may have, given the size the guest started with.
	public static func maxPixels(booted: CGSize) -> Int {
		max(minimumSegmentBytes / bytesPerPixel, Int(booted.width) * Int(booted.height))
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
}
