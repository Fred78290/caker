import Foundation
import GRPCLib

protocol Importer {
	func importVM(location: VMLocation, source: String, userName: String, password: String, sshKey: Data? = nil, runMode: Utils.RunMode) throws -> Void
}