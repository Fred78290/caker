import Foundation

protocol Importer {
	func importVM(location: VMLocation, source: String) throws -> Void
}