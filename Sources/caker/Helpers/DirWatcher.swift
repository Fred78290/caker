//
//  DirWatcher.swift
//  Caker
//
//  Created by Frederic BOLTZ on 18/06/2026.
//

import Cocoa

public class DirWatcherEvent {
	public var id: FSEventStreamEventId
	public var path: String
	public var flags: FSEventStreamEventFlags

	public var description: String {
		var result = "The \(fileChange ? "file":"directory") \(path) was"
		if removed { result += " removed" }
		else if created { result += " created" }
		else if renamed { result += " renamed" }
		else if modified { result += " modified" }
		return result
	}

	init(_ eventId: FSEventStreamEventId, _ eventPath: String, _ eventFlags: FSEventStreamEventFlags) {
		id = eventId
		path = eventPath
		flags = eventFlags
	}
	
	private var fileChange: Bool { (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)) != 0 }
	private var dirChange: Bool { (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)) != 0 }
	// CRUD
	private var created: Bool { (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0 }
	private var removed: Bool { (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0 }
	private var renamed: Bool { (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0 }
	private var modified: Bool { (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0 }
	
	var fileCreated: Bool { fileChange && created }
	var fileRemoved: Bool { fileChange && removed }
	var fileRenamed: Bool { fileChange && renamed }
	var fileModified: Bool { fileChange && modified }
	// Directory
	var dirCreated: Bool { dirChange && created }
	var dirRemoved: Bool { dirChange && removed }
	var dirRenamed: Bool { dirChange && renamed }
	var dirModified: Bool { dirChange && modified }
}

class DirWatcher {
	var callback: CallBack?
	var queue: DispatchQueue?

	let filePaths: [String]  // -- paths to watch - works on folders and file paths
	var streamRef: FSEventStreamRef?
	var hasStarted: Bool { streamRef != nil }

	public init(_ paths: [String]) { filePaths = paths }

	/**
	* - Parameters:
	*    - streamRef: The stream for which event(s) occurred. clientCallBackInfo: The info field that was supplied in the context when this stream was created.
	*    - numEvents:  The number of events being reported in this callback. Each of the arrays (eventPaths, eventFlags, eventIds) will have this many elements.
	*    - eventPaths: An array of paths to the directories in which event(s) occurred. The type of this parameter depends on the flags
	*    - eventFlags: An array of flag words corresponding to the paths in the eventPaths parameter. If no flags are set, then there was some change in the directory at the specific path supplied in this  event. See FSEventStreamEventFlags.
	*    - eventIds: An array of FSEventStreamEventIds corresponding to the paths in the eventPaths parameter. Each event ID comes from the most recent event being reported in the corresponding directory named in the eventPaths parameter.
	*/
	let eventCallback: FSEventStreamCallback = {(
			stream: ConstFSEventStreamRef,
			contextInfo: UnsafeMutableRawPointer?,
			numEvents: Int,
			eventPaths: UnsafeMutableRawPointer,
			eventFlags: UnsafePointer<FSEventStreamEventFlags>,
			eventIds: UnsafePointer<FSEventStreamEventId>
	) in
		let fileSystemWatcher = Unmanaged<DirWatcher>.fromOpaque(contextInfo!).takeUnretainedValue()
		let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

		(0..<numEvents).indices.forEach { index in
			try? fileSystemWatcher.callback?(DirWatcherEvent(eventIds[index], paths[index], eventFlags[index]))
		}

	}

	let retainCallback: CFAllocatorRetainCallBack = {(info: UnsafeRawPointer?) in
		_ = Unmanaged<DirWatcher>.fromOpaque(info!).retain()
		return info
	}

	let releaseCallback: CFAllocatorReleaseCallBack = {(info: UnsafeRawPointer?) in
		Unmanaged<DirWatcher>.fromOpaque(info!).release()
	}

	func selectStreamScheduler() {
		if let queue = queue {
			FSEventStreamSetDispatchQueue(streamRef!, queue)
		} else {
			FSEventStreamSetDispatchQueue(streamRef!, DispatchQueue.main)
		}
	}
}
/**
 * Convenient
 */
extension DirWatcher {
	typealias CallBack = (_ fileWatcherEvent: DirWatcherEvent) throws -> Void

	convenience init(
			_ paths: [String],
			_ callback: @escaping CallBack,
			_ queue: DispatchQueue
	) {
		self.init(paths)
		self.callback = callback
		self.queue = queue
	}
}

extension DirWatcher {
	/**
	* Start listening for FSEvents
	*/
	func start() {
		guard !hasStarted else { return } // -- make sure we are not already listening!
		var context = FSEventStreamContext(
				version: 0,
				info: Unmanaged.passUnretained(self).toOpaque(),
				retain: retainCallback,
				release: releaseCallback,
				copyDescription: nil
		)
		streamRef = FSEventStreamCreate(
				kCFAllocatorDefault,
				eventCallback,
				&context,
				filePaths as CFArray,
				FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
				0,
				UInt32(kFSEventStreamCreateFlagUseCFTypes)
		)
		selectStreamScheduler()
		FSEventStreamStart(streamRef!)
	}

	/**
	* Stop listening for FSEvents
	*/
	func stop() {
		guard hasStarted else { return } // -- make sure we are indeed listening!
		FSEventStreamStop(streamRef!)
		FSEventStreamInvalidate(streamRef!)
		FSEventStreamRelease(streamRef!)
		streamRef = nil
	}
}
