import ArgumentParser
import Darwin
import Foundation

@main
struct Root: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tartd",
    version: CI.version,
    subcommands: [
      Service.self,
    ])

  public static func main() async throws {
    // Ensure the default SIGINT handled is disabled,
    // otherwise there's a race between two handlers
    signal(SIGINT, SIG_IGN);
    // Handle cancellation by Ctrl+C ourselves
    let task = withUnsafeCurrentTask { $0 }!
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    // Set line-buffered output for stdout
    setlinebuf(stdout)

    // Parse and run command
    do {
      var command = try parseAsRoot()

      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      // Handle a non-ArgumentParser's exception that requires a specific exit code to be set
      if let errorWithExitCode = error as? HasExitCode {
        fputs("\(error)\n", stderr)

        Foundation.exit(errorWithExitCode.exitCode)
      }

      // Handle any other exception, including ArgumentParser's ones
      exit(withError: error)
    }
  }
}
