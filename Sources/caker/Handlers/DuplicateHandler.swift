import Foundation
import CakedLib
import GRPCLib

extension DuplicateHandler {
	/// Duplicates locally (`.app` mode) or through caked. Cancelling the calling task cancels the
	/// duplicate: locally directly, through caked with a CancelTask call on the task id sent with the
	/// request. Either way the temporary VM is killed and deleted, and the reply says it was cancelled.
	public static func duplicate(client: CakedServiceClient?, vmURL: URL, to: String, resetMacAddress: Bool, runMode: Utils.RunMode) async throws -> DuplicatedReply {
		guard let client, vmURL.isFileURL == false else {
			return await self.duplicate(vmURL: vmURL, to: to, resetMacAddress: resetMacAddress, runMode: runMode)
		}

		let taskID = UUID()
		let call = client.duplicate(.with {
			$0.taskID = taskID.uuidString
			$0.from = vmURL.vmName
			$0.to = to
			$0.resetMacAddress = resetMacAddress
		})

		// Cancelling asks caked to cancel the task, retried until caked has registered it; the call
		// still waits for caked's own answer, which comes once the temporary VM is gone.
		return try await client.withCancellableTask(taskID, attemptTimeLimit: CakedServiceClient.longCancelTaskTimeLimit) {
			try await DuplicatedReply(call.response.get().vms.duplicated)
		}
	}
}
