//
//  VNCPixelTranslation.swift
//  Caker
//
//  Created by Frederic BOLTZ on 06/12/2025.
//
import Foundation

typealias rfbInitTableFnType = (_ input: VNCPixelFormat, _ out: VNCPixelFormat) -> [[any FixedWidthInteger]]

typealias ClientTranslatePixelFormat = (_ lookupTable: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ imageSource: Data, _ bytesPerRow: Int, _ width: Int, _ height: Int) -> Data

private func rfbTranslateWithSingleTable<IN: FixedWidthInteger, OUT: FixedWidthInteger>(_ lookupTable: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ imageSource: Data, _ bytesPerRow: Int, _ width: Int, _ height: Int, as inputType: IN.Type, to outputType: OUT.Type) -> Data {
	var pixelData = Data(count: width * height * MemoryLayout<OUT>.size)
	let lookupTable = lookupTable[0] as! [UInt8]

	imageSource.withUnsafeBytes { srcRaw in
		pixelData.withUnsafeMutableBytes { dstRaw in
			guard let spBase = srcRaw.bindMemory(to: IN.self).baseAddress, let dpBase = dstRaw.bindMemory(to: OUT.self).baseAddress else { return }
			let srcStride = bytesPerRow / MemoryLayout<IN>.size
			let dstStride = width

			for row in 0..<height {
				let spRow = spBase.advanced(by: row * srcStride)
				let dpRow = dpBase.advanced(by: row * dstStride)

				for col in 0..<width {
					let srcVal = spRow[col]
					let mapped = lookupTable[Int(srcVal)]

					dpRow[col] = OUT(mapped)
				}
			}
		}
	}

	return pixelData
}

private func rfbTranslateWithRGBTable<IN: FixedWidthInteger, OUT: FixedWidthInteger>(_ lookupTable: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ imageSource: Data, _ bytesPerRow: Int, _ width: Int, _ height: Int, as inputType: IN.Type, to outputType: OUT.Type) -> Data {
	var pixelData = Data(count: width * height * MemoryLayout<OUT>.size)

	imageSource.withUnsafeBytes { (srcRaw: UnsafeRawBufferPointer) in
		pixelData.withUnsafeMutableBytes { (dstRaw: UnsafeMutableRawBufferPointer) in
			guard let spBase = srcRaw.bindMemory(to: IN.self).baseAddress, let dpBase = dstRaw.bindMemory(to: OUT.self).baseAddress else { return }
			let srcStride = bytesPerRow / MemoryLayout<IN>.size
			let dstStride = width
			let redTable = lookupTable[0] as! [OUT]
			let greenTable = lookupTable[1] as! [OUT]
			let blueTable = lookupTable[2] as! [OUT]

			for row in 0..<height {
				let spRow = spBase.advanced(by: row * srcStride)
				let dpRow = dpBase.advanced(by: row * dstStride)

				for col in 0..<width {
					let srcVal = spRow[col]

					// Compute masked components with explicit casts to IN to ensure shifts and masks are type-safe
					let rIndexIN = Int((srcVal >> IN(pixelFormat.redShift)) & IN(pixelFormat.redMax))
					let gIndexIN = Int((srcVal >> IN(pixelFormat.greenShift)) & IN(pixelFormat.greenMax))
					let bIndexIN = Int((srcVal >> IN(pixelFormat.blueShift)) & IN(pixelFormat.blueMax))

					// Fetch precomputed components from tables
					let r = redTable[rIndexIN]
					let g = greenTable[gIndexIN]
					let b = blueTable[bIndexIN]

					// Combine with bitwise OR into OUT
					let combined = r | g | b

					dpRow[col] = combined
				}
			}
		}
	}

	return pixelData
}

private func rfbInitTrueColourSingleTable<OUT: FixedWidthInteger>(input: VNCPixelFormat, output: VNCPixelFormat) -> [OUT] {
    let nEntries = 1 << input.bitsPerPixel
    var table = Array<OUT>(repeating: 0, count: nEntries)
    let swp = MemoryLayout<OUT>.size != 8

    for i in 0..<nEntries {
        let inRed   = (UInt16(i) >> input.redShift)   & input.redMax
        let inGreen = (UInt16(i) >> input.greenShift) & input.greenMax
        let inBlue  = (UInt16(i) >> input.blueShift)  & input.blueMax

        let outRed   = (inRed   * output.redMax   + input.redMax / 2)   / input.redMax
        let outGreen = (inGreen * output.greenMax + input.greenMax / 2) / input.greenMax
        let outBlue  = (inBlue  * output.blueMax  + input.blueMax / 2)  / input.blueMax

        let packed: OUT = OUT(((outRed << output.redShift) | (outGreen << output.greenShift) | (outBlue  << output.blueShift)))

        table[i] = swp ? packed.byteSwapped : packed
    }

    return table
}


private func rfbInitTrueColourSingleTable8(input: VNCPixelFormat, output: VNCPixelFormat) -> [[UInt8]] {
    [
    	rfbInitTrueColourSingleTable(input: input, output: output)
    ]
}

private func rfbInitTrueColourSingleTable16(input: VNCPixelFormat, output: VNCPixelFormat) -> [[UInt16]] {
	[
		rfbInitTrueColourSingleTable(input: input, output: output)
	]
}

private func rfbInitTrueColourSingleTable32(input: VNCPixelFormat, output: VNCPixelFormat) -> [[UInt32]] {
	[
		rfbInitTrueColourSingleTable(input: input, output: output)
	]
}

private func rfbInitOneRGBTable<OUT: FixedWidthInteger>(_ inMax: UInt16, _ outMax: UInt16, _ outShift: UInt8, _ swap: Bool) -> [OUT]
{
	let inMax = Int(inMax)
	let outMax = Int(outMax)
	let outShift = Int(outShift)
	let nEntries = inMax + 1;
	var table: [OUT] = Array<OUT>(repeating: 0, count: nEntries);

	for i in 0..<nEntries {
		if MemoryLayout<OUT>.size != 8 && swap {
			table[i] = OUT(((i * outMax + inMax / 2) / inMax) << outShift).byteSwapped;
		} else {
			table[i] = OUT(((i * outMax + inMax / 2) / inMax) << outShift);
		}
	}
	
	return table
}

private func rfbInitTrueColourRGBTables8(input: VNCPixelFormat, output: VNCPixelFormat) -> [[UInt8]] {
	[
		rfbInitOneRGBTable(input.redMax, output.redMax, output.redShift, (output.bigEndianFlag != input.bigEndianFlag)),
		rfbInitOneRGBTable(input.greenMax, output.greenMax, output.greenShift, (output.bigEndianFlag != input.bigEndianFlag)),
		rfbInitOneRGBTable(input.blueMax, output.blueMax, output.blueShift, (output.bigEndianFlag != input.bigEndianFlag))
	]
}

private func rfbInitTrueColourRGBTables16(input: VNCPixelFormat, output: VNCPixelFormat) -> [[UInt16]] {
	[
		rfbInitOneRGBTable(input.redMax, output.redMax, output.redShift, (output.bigEndianFlag != input.bigEndianFlag)),
		rfbInitOneRGBTable(input.greenMax, output.greenMax, output.greenShift, (output.bigEndianFlag != input.bigEndianFlag)),
		rfbInitOneRGBTable(input.blueMax, output.blueMax, output.blueShift, (output.bigEndianFlag != input.bigEndianFlag))
	]
}

private func rfbInitTrueColourRGBTables32(input: VNCPixelFormat, output: VNCPixelFormat) -> [[UInt32]] {
	[
		rfbInitOneRGBTable(input.redMax, output.redMax, output.redShift, (output.bigEndianFlag != input.bigEndianFlag)),
		rfbInitOneRGBTable(input.greenMax, output.greenMax, output.greenShift, (output.bigEndianFlag != input.bigEndianFlag)),
		rfbInitOneRGBTable(input.blueMax, output.blueMax, output.blueShift, (output.bigEndianFlag != input.bigEndianFlag))
	]
}

let rfbInitTrueColourSingleTableFns: [rfbInitTableFnType] = [
	rfbInitTrueColourSingleTable8,
	rfbInitTrueColourSingleTable16,
	rfbInitTrueColourSingleTable32
]

let rfbInitTrueColourRGBTablesFns: [rfbInitTableFnType] = [
	rfbInitTrueColourRGBTables8,
	rfbInitTrueColourRGBTables16,
	rfbInitTrueColourRGBTables32
]


// Concrete wrappers for single-table translations
private func translate8to8SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt8.self, to: UInt8.self)
}

private func translate8to16SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt8.self, to: UInt16.self)
}

private func translate8to32SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt8.self, to: UInt32.self)
}

private func translate16to8SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt16.self, to: UInt8.self)
}

private func translate16to16SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt16.self, to: UInt16.self)
}

private func translate16to32SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt16.self, to: UInt32.self)
}

private func translate32to8SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt32.self, to: UInt8.self)
}

private func translate32to16SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt32.self, to: UInt16.self)
}

private func translate32to32SingleTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
	return rfbTranslateWithSingleTable(table, pixelFormat, src, bpr, w, h, as: UInt32.self, to: UInt32.self)
}

// Concrete wrappers for RGB-table translations
private func translate8to8RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt8.self, to: UInt8.self)
}

private func translate8to16RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt8.self, to: UInt16.self)
}

private func translate8to32RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt8.self, to: UInt32.self)
}

private func translate16to8RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt16.self, to: UInt8.self)
}

private func translate16to16RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt16.self, to: UInt16.self)
}

private func translate16to32RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt16.self, to: UInt32.self)
}

private func translate32to8RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt32.self, to: UInt8.self)
}

private func translate32to16RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt32.self, to: UInt16.self)
}

private func translate32to32RGBTable(_ table: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ src: Data, _ bpr: Int, _ w: Int, _ h: Int) -> Data {
    return rfbTranslateWithRGBTable(table, pixelFormat, src, bpr, w, h, as: UInt32.self, to: UInt32.self)
}

func rfbTranslateNone (_ lookupTable: [[any FixedWidthInteger]], _ pixelFormat: VNCPixelFormat, _ imageSource: Data, _ bytesPerRow: Int, _ width: Int, _ height: Int) -> Data {
	let size = Int(pixelFormat.bitsPerPixel) / 8
	var pixelData = Data(count: width * height * size)
	
	imageSource.withUnsafeBytes { srcRaw in
		pixelData.withUnsafeMutableBytes { dstRaw in
			guard let sp = srcRaw.bindMemory(to: UInt8.self).baseAddress, let dp = dstRaw.bindMemory(to: UInt8.self).baseAddress else { return }
			let rowWidth = width * size;

			for row in 0..<height {
				let srcPtr = sp.advanced(by: bytesPerRow * row)
				let dstPtr = dp.advanced(by: (width * 4) * row)

				memcpy(dstPtr, srcPtr, rowWidth)
			}
		}
	}

	return pixelData
}

let rfbTranslateWithSingleTableFns: [[ClientTranslatePixelFormat]] = [
	[
		translate8to8SingleTable,
		translate8to16SingleTable,
		translate8to32SingleTable
	],
	[
		translate16to8SingleTable,
		translate16to16SingleTable,
		translate16to32SingleTable
	],
	[
		translate32to8SingleTable,
		translate32to16SingleTable,
		translate32to32SingleTable
	]
]

let rfbTranslateWithRGBTablesFns: [[ClientTranslatePixelFormat]] = [
    [
        translate8to8RGBTable,
        translate8to16RGBTable,
        translate8to32RGBTable
    ],
    [
        translate16to8RGBTable,
        translate16to16RGBTable,
        translate16to32RGBTable
    ],
    [
        translate32to8RGBTable,
        translate32to16RGBTable,
        translate32to32RGBTable
    ]
]

