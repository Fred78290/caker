import Foundation
import GRPCLib

protocol Importer {
	func importVM(location: VMLocation, source: String, userName: String, password: String, sshPrivateKey: String?, runMode: Utils.RunMode) throws -> Void
}