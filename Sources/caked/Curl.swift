import Foundation
import Algorithms
import AsyncAlgorithms

final class DownloadDelegate: NSObject, URLSessionTaskDelegate {
  let progress: Progress
  init(_ progress: Progress) throws {
	self.progress = progress
  }

  func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
	self.progress.addChild(task.progress, withPendingUnitCount: self.progress.totalUnitCount)
  }
}

class Curl {
	let urlSession: URLSession
	let fromURL: URL

	init(fromURL: URL) {
		let config = URLSessionConfiguration.default
		config.httpShouldSetCookies = false

		self.urlSession = URLSession(configuration: config)
		self.fromURL = fromURL
	}

	func head(progress: Progress? = nil) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
		let delegate = progress != nil ? try DownloadDelegate(progress!) : nil
		var request: URLRequest = URLRequest(url: self.fromURL)
		let channel = AsyncThrowingChannel<Data, Error>()

		request.httpMethod = "HEAD"

		let (data, response) = try await urlSession.data(for: request, delegate: delegate)

		Task {
			await channel.send(data)

			channel.finish()
		}

		return (channel, response as! HTTPURLResponse)
	}

	func get(observer: ProgressObserver? = nil) async throws -> (AsyncThrowingChannel<Data, Error>, HTTPURLResponse) {
		let delegate = observer != nil ? try DownloadDelegate(observer!.progress) : nil
		let request: URLRequest = URLRequest(url: self.fromURL)
		let channel = AsyncThrowingChannel<Data, Error>()
		let (fileURL, response) = try await self.urlSession.download(for: request, delegate: delegate)
		let mappedFile = try Data(contentsOf: fileURL, options: [.alwaysMapped])
		try FileManager.default.removeItem(at: fileURL)

		Task {
			for chunk in (0 ..< mappedFile.count).chunks(ofCount: 64 * 1024 * 1024) {
				await channel.send(mappedFile.subdata(in: chunk))
			}

			channel.finish()
		}

		return (channel, response as! HTTPURLResponse)
	}
}
