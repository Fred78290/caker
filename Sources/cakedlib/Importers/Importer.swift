import Foundation
import GRPCLib

public protocol Importer {
	var needSudo: Bool { get }
	/// Whether the source disk is a raw image that the imported VM can reference in place
	/// instead of copying (the `--no-copy-disk` option).
	var supportsInPlaceDisk: Bool { get }
	var name: String { get }
	var source: String { get }

	/// `customArguments` carries the undeclared `--importer-arg key=value` options given on the command line, for importers that need extra settings.
	func importVM(location: VMLocation, source: String, userName: String, password: String, clearPassword: Bool, sshPrivateKey: String?, passphrase: String?, copyDisk: Bool, customArguments: [String: String], runMode: Utils.RunMode) throws
}
