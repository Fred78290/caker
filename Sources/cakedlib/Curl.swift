import Algorithms
import AsyncAlgorithms
import Foundation

extension URLRequest {
	init(url: URL, method: String, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 60.0) {
		self.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
		
		self.httpMethod = method
	}
}

private final class DownloadDelegate: NSObject, URLSessionDataDelegate {
	var response: CheckedContinuation<URLResponse, Error>?
	var stream: AsyncThrowingStream<Data, Error>.Continuation?

	private let progressObserver: ProgressObserver?
	private var buffer: Data = Data()
	private let inputBufferSize = 16 * 1024 * 1024
	
	init(_ progressObserver: ProgressObserver? = nil) {
		self.progressObserver = progressObserver
	}
	
	func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
		if let progressObserver = self.progressObserver {
			progressObserver.progress.addChild(task.progress, withPendingUnitCount: progressObserver.progress.totalUnitCount)
		}
	}
	
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
	
	func urlSession( _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
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

	func fetch(request: URLRequest, progressObserver: ProgressObserver? = nil) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
		let delegate = DownloadDelegate(progressObserver)
		let task = self.urlSession.dataTask(with: request)

		task.delegate = delegate

		let channel = AsyncThrowingStream<Data, Error> { continuation in
			delegate.stream = continuation
		}

		let response = try await withCheckedThrowingContinuation { continuation in
			delegate.response = continuation

			task.resume()
		}

		return (channel, response as! HTTPURLResponse)
	}

	func head(observer: ProgressObserver? = nil) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
		return try await self.fetch(request: URLRequest(url: self.fromURL, method: "HEAD"), progressObserver: observer)
	}

	func get(observer: ProgressObserver? = nil) async throws -> (AsyncThrowingStream<Data, Error>, HTTPURLResponse) {
		return try await self.fetch(request: URLRequest(url: self.fromURL), progressObserver: observer)
	}
}
