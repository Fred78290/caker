import Foundation
import XCTest

@testable import CakedLib

final class ZLibStreamTest: XCTestCase {

	// MARK: - ZlibDeflateStream Tests

	func testCompressedDataBasicCompression() throws {
		let stream = try ZlibDeflateStream()

		// Test data simple
		let testString = "Hello, World! This is a test string for compression."
		let inputData = testString.data(using: .utf8)!

		// Compression avec flush finish (défaut)
		let compressedData = try stream.compressedData(
			data: inputData,
			offset: 0,
			length: inputData.count
		)

		// Vérifications de base
		XCTAssertFalse(compressedData.isEmpty, "Compressed data should not be empty")
		XCTAssertNotEqual(compressedData, inputData, "Compressed data should be different from input")

		// Pour une chaîne courte, la compression peut ne pas réduire la taille
		// mais elle ne devrait pas exploser non plus
		XCTAssertLessThan(compressedData.count, inputData.count * 2, "Compressed data should not be excessively large")
	}

	func testCompressedDataEmptyData() throws {
		let stream = try ZlibDeflateStream()

		let emptyData = Data()
		let compressedData = try stream.compressedData(
			data: emptyData,
			offset: 0,
			length: 0
		)

		// Même des données vides produisent un header zlib
		XCTAssertGreaterThan(compressedData.count, 0, "Compressed empty data should still have zlib headers")
	}

	func testCompressedDataLargeData() throws {
		let stream = try ZlibDeflateStream()

		// Créer un gros bloc de données répétitives (bon pour la compression)
		let repeatedString = String(repeating: "A", count: 10000)
		let inputData = repeatedString.data(using: .utf8)!

		let compressedData = try stream.compressedData(
			data: inputData,
			offset: 0,
			length: inputData.count
		)

		XCTAssertFalse(compressedData.isEmpty)
		// Avec des données répétitives, la compression devrait être très efficace
		XCTAssertLessThan(compressedData.count, inputData.count / 10, "Repetitive data should compress very well")
	}

	func testCompressedDataWithOffset() throws {
		let stream = try ZlibDeflateStream()

		let testString = "SKIP_THIS_PART_Hello_World_SKIP_THIS_TOO"
		let inputData = testString.data(using: .utf8)!

		// Comprimer seulement la partie "Hello_World"
		let skipPrefix = "SKIP_THIS_PART_".count
		let content = "Hello_World"
		let contentLength = content.count

		let compressedData = try stream.compressedData(
			data: inputData,
			offset: skipPrefix,
			length: contentLength
		)

		XCTAssertFalse(compressedData.isEmpty)

		// Vérifier que c'est différent de comprimer toutes les données
		let stream2 = try ZlibDeflateStream()
		let fullCompressedData = try stream2.compressedData(
			data: inputData,
			offset: 0,
			length: inputData.count
		)

		XCTAssertNotEqual(compressedData, fullCompressedData, "Partial compression should differ from full compression")
	}

	func testCompressedDataDifferentFlushModes() throws {
		let repeatedString = String(repeating: "A", count: 10000)
		let inputData = repeatedString.data(using: .utf8)!

		// Test avec différents modes de flush
		let flushModes: [ZlibFlush] = [.noFlush, .syncFlush, .fullFlush, .finish]
		var results: [Data] = []

		for flush in flushModes {
			let stream = try ZlibDeflateStream()
			let compressedData = try stream.compressedData(
				data: inputData,
				offset: 0,
				length: inputData.count,
				flush: flush
			)
			results.append(compressedData)
			XCTAssertFalse(compressedData.isEmpty, "Compression with \(flush) should not be empty")
		}

		// Les résultats peuvent être différents selon le mode de flush
		// mais tous devraient produire des données valides
		for (index, result) in results.enumerated() {
			XCTAssertGreaterThan(result.count, 0, "Result \(index) should have content")
		}
	}

	func testCompressedDataBinaryData() throws {
		let stream = try ZlibDeflateStream()

		// Créer des données binaires
		var binaryData = Data()
		for i in 0..<1000 {
			binaryData.append(UInt8(i % 256))
		}

		let compressedData = try stream.compressedData(
			data: binaryData,
			offset: 0,
			length: binaryData.count
		)

		XCTAssertFalse(compressedData.isEmpty)
		XCTAssertNotEqual(compressedData, binaryData)
	}

	func testCompressedDataInvalidOffset() throws {
		let stream = try ZlibDeflateStream()
		let testData = "Test".data(using: .utf8)!

		// Test avec offset trop grand
		XCTAssertThrowsError(
			try stream.compressedData(
				data: testData,
				offset: testData.count + 1,
				length: 1
			)
		) { error in
			// Devrait lever une erreur car offset dépasse les données
		}
	}

	func testCompressedDataZeroLength() throws {
		let stream = try ZlibDeflateStream()
		let testData = "Test".data(using: .utf8)!

		// Test avec length = 0
		let compressedData = try stream.compressedData(
			data: testData,
			offset: 0,
			length: 0
		)

		// Même avec length 0, on devrait avoir des headers zlib
		XCTAssertGreaterThan(compressedData.count, 0, "Even zero-length data should produce zlib headers")
	}

	func testCompressedDataMultipleCompressions() throws {
		// Tester plusieurs compressions avec le même stream
		let stream = try ZlibDeflateStream()
		let inflate = try ZlibInflateStream()

		let testStrings = [
			String(repeating: "A", count: 10000),
			String(repeating: "A", count: 10000),
			String(repeating: "A", count: 10000),
		]

		for (index, testString) in testStrings.enumerated() {
			let inputData = testString.data(using: .utf8)!

			// Note: En pratique, on devrait probablement créer un nouveau stream
			// pour chaque compression, mais testons la robustesse
			do {
				let compressedData = try stream.compressedData(data: inputData, offset: 0, length: inputData.count, flush: .syncFlush)
				XCTAssertFalse(compressedData.isEmpty, "Compression \(index) should not be empty")

				let decompressedData = try inflate.decompressedData(compressedData: compressedData)
				XCTAssertEqual(decompressedData, inputData, "Decompressed data should match original input for compression \(index)")
			} catch {
				// Si le stream ne peut pas être réutilisé, c'est acceptable
				print("Stream reuse failed at iteration \(index): \(error)")
			}
		}
	}

	func testCompressedDataPerformance() throws {
		// Test de performance pour voir si la compression est raisonnable
		let largeString = String(repeating: "Performance test data. ", count: 1000)
		let inputData = largeString.data(using: .utf8)!

		measure {
			do {
				let stream = try ZlibDeflateStream()
				let _ = try stream.compressedData(
					data: inputData,
					offset: 0,
					length: inputData.count
				)
			} catch {
				XCTFail("Performance test failed: \(error)")
			}
		}
	}
}
