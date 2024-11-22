import ArgumentParser

struct Start: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Launch a linux VM create in background")

	@Argument(help: "VM name", completion: .custom(completeRunningMachines))
	var name: String

	func run() async throws {
		let vmDir = try VMStorageLocal().open(name)
		let vmState = try vmDir.state()

		if vmState == .Stopped {
			try StartHandler.startVM(vmDir: vmDir)
		} else if vmState == .Running {
			throw RuntimeError.VMAlreadyRunning(name)
		}
	}
}