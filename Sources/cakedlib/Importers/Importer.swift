import Foundation
import GRPCLib

public protocol Importer {
	var needSudo: Bool { get }
	/// Whether the source disk is a raw image that the imported VM can reference in place
	/// instead of copying (the `--no-copy-disk` option).
	var supportsInPlaceDisk: Bool { get }
	var name: String { get }
	var source: String { get }

	func importVM(location: VMLocation, source: String, userName: String, password: String, clearPassword: Bool, sshPrivateKey: String?, passphrase: String?, copyDisk: Bool, runMode: Utils.RunMode) throws
}
