import Foundation
import GRPCLib

protocol Importer {
	func importVM(location: VMLocation, source: String, runMode: Utils.RunMode) throws -> Void
}