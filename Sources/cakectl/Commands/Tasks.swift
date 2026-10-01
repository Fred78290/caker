import ArgumentParser
import Foundation
import GRPC
import GRPCLib

// MARK: - Tasks command group

struct Tasks: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "tasks",
		abstract: String(localized: "Inspect and cancel long-running tasks registered on caked"),
		discussion: String(localized: "Covers build/launch/provision calls currently in flight on the connected caked service — the same tasks stop() cancels on shutdown."),
		subcommands: [ListTasks.self, CancelTask.self]
	)

	// MARK: list
	struct ListTasks: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "list", abstract: String(localized: "List currently registered long-running tasks"), aliases: ["ls"])

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let reply = try client.listTasks(Caked_Empty(), callOptions: callOptions).response.wait().tasks

			return self.options.format.render(reply.list.tasks)
		}
	}

	// MARK: cancel
	struct CancelTask: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "cancel", abstract: String(localized: "Cancel a registered long-running task by id"))

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "Task id, as shown by 'tasks list'")))
		var id: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let reply = try client.cancelTask(.with { $0.id = self.id }, callOptions: callOptions).response.wait().tasks.cancelled

			if reply.success {
				return self.options.format.render(String(format: String(localized: "Task '%@' cancelled."), self.id))
			} else {
				return self.options.format.render(reply.reason)
			}
		}
	}
}
