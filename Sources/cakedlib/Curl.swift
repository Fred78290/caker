import Algorithms
import AsyncAlgorithms
import Foundation
import GRPCLib

extension URLRequest {
	init(url: URL, method: String, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 60.0) {
		self.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)

		self.httpMethod = method
	}
}

private final class DownloadDelegate: NSObject, URLSessionDataDelegate {
	var response: CheckedContinuation<URLResponse, Error>?
	var stream: AsyncThrowingStream<Data, Error>.Continuation?

	private var buffer: Data = Data()
	private let inputBufferSize = 16 * 1024 * 1024

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		let capacity = min(response.expectedContentLength, Int64(inputBufferSize))

		self.buffer = Data(capacity: Int(capacity))
		self.response?.resume(returning: response)
		self.response = nil

		completionHandler(.allow)
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		self.buffer.append(data)

		if self.buffer.count >= inputBufferSize {
			self.stream?.yield(buffer)
			self.buffer.removeAll(keepingCapacity: true)
		}

	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error = error {
			self.response?.resume(throwing: error)
			self.response = nil

			self.stream?.finish(throwing: error)
			self.stream = nil
		} else {
			if buffer.isEmpty == false {
				self.stream?.yield(buffer)
				self.buffer.removeAll(keepingCapacity: true)
			}

			self.stream?.finish()
			self.stream = nil
		}
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

	func fetch(request: URLRequest, progressObserver: ProgressObserver? = nil) async throws -> (channel: AsyncThrowingStream<Data, Error>, response: HTTPURLResponse) {
		let delegate = DownloadDelegate()
		let task = self.urlSession.dataTask(with: request)

		task.delegate = delegate

		if let progressObserver = progressObserver {
			progressObserver.progress.addChild(task.progress, withPendingUnitCount: progressObserver.progress.totalUnitCount)
		}

		let channel = AsyncThrowingStream<Data, Error> { continuation in
			delegate.stream = continuation
		}

		let response =
			try await withCheckedThrowingContinuation { continuation in
				delegate.response = continuation

				task.resume()
			} as! HTTPURLResponse

		if response.statusCode != 200 {
			throw URLError(.init(rawValue: response.statusCode))
		}

		return (channel, response)
	}

	func head(observer: ProgressObserver? = nil) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
		return try await self.fetch(request: URLRequest(url: self.fromURL, method: "HEAD"), progressObserver: observer)
	}

	func get(store: URL, observer: ProgressObserver? = nil) async throws {
		let result = try await self.fetch(request: URLRequest(url: self.fromURL), progressObserver: observer)

		FileManager.default.createFile(atPath: store.path, contents: nil)

		let lock = try FileLock(lockURL: store)
		try lock.lock()

		let fileHandle = try FileHandle(forWritingTo: store)

		for try await chunk in result.channel {
			let chunkAsData = Data(chunk)
			fileHandle.write(chunkAsData)
		}

		try fileHandle.close()
	}
}
