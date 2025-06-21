import Foundation
import GRPCLib

public protocol Importer {
	var needSudo: Bool { get }
	var name: String { get }

	func importVM(location: VMLocation, source: String, userName: String, password: String, sshPrivateKey: String?, passphrase: String?, runMode: Utils.RunMode) throws -> Void
}
