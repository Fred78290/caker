import Foundation
import GRPCLib

public protocol Importer {
	var needSudo: Bool { get }
	var name: String { get }

	func importVM(location: VMLocation, source: String, userName: String, password: String, clearPassword: Bool, sshPrivateKey: String?, passphrase: String?, runMode: Utils.RunMode) throws
}
