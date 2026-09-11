//
//  DirWatcher.swift
//  Caker
//
//  Created by Frederic BOLTZ on 18/06/2026.
//

import Cocoa

extension FSEventStreamEventFlags {
	public enum ChangeType {
		public var description: String {
			switch self {
			case .none: return "none"
			case .created: return "created"
			case .removed: return "removed"
			case .renamed: return "renamed"
			case .modified: return "modified"
			}
		}

		case none
		case created
		case removed
		case renamed
		case modified
	}

	// CRUD
	private var created: Bool { (self & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0 }
	private var removed: Bool { (self & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved)) != 0 }
	private var renamed: Bool { (self & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed)) != 0 }
	private var modified: Bool { (self & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0 }

	public var fileChange: Bool { (self & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)) != 0 }
	public var dirChange: Bool { (self & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir)) != 0 }

	public var fileCreated: Bool { fileChange && created }
	public var fileRemoved: Bool { fileChange && removed }
	public var fileRenamed: Bool { fileChange && renamed }
	public var fileModified: Bool { fileChange && modified }
	// Directory
	public var dirCreated: Bool { dirChange && created }
	public var dirRemoved: Bool { dirChange && removed }
	public var dirRenamed: Bool { dirChange && renamed }
	public var dirModified: Bool { dirChange && modified }

	public var changeType: ChangeType {
		if self.dirChange {
			if dirCreated { return .created }
			if dirRemoved { return .removed }
			if dirRenamed { return .renamed }
			if dirModified { return .modified }
		} else if self.fileChange {
			if fileCreated { return .created }
			if fileRemoved { return .removed }
			if fileRenamed { return .renamed }
			if fileModified { return .modified }
		}

		return .none
	}

	public var description: String {
		if self.dirChange {
			return "directory event: \(self.changeType.description)"

		} else if self.fileChange {
			return "file event: \(self.changeType.description)"
		}

		return "unknown event: \(String(format: "%X", self))"
	}
}

public class DirWatcherEvent {
	public var id: FSEventStreamEventId
	public var path: String
	public var flags: FSEventStreamEventFlags

	public var description: String {
		return flags.description
	}

	init(_ eventId: FSEventStreamEventId, _ eventPath: String, _ eventFlags: FSEventStreamEventFlags) {
		id = eventId
		path = eventPath
		flags = eventFlags
	}

	public var fileChange: Bool { flags.fileChange }
	public var dirChange: Bool { flags.dirChange }

	public var fileCreated: Bool { flags.fileCreated }
	public var fileRemoved: Bool { flags.fileRemoved }
	public var fileRenamed: Bool { flags.fileRenamed }
	public var fileModified: Bool { flags.fileModified }
	// Directory
	public var dirCreated: Bool { flags.dirCreated }
	public var dirRemoved: Bool { flags.dirRemoved }
	public var dirRenamed: Bool { flags.dirRenamed }
	public var dirModified: Bool { flags.dirModified }
}

public class DirWatcher {
	public var callback: CallBack?
	public var queue: DispatchQueue?

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
	let eventCallback: FSEventStreamCallback = {
		(
			stream: ConstFSEventStreamRef,
			contextInfo: UnsafeMutableRawPointer?,
			numEvents: Int,
			eventPaths: UnsafeMutableRawPointer,
			eventFlags: UnsafePointer<FSEventStreamEventFlags>,
			eventIds: UnsafePointer<FSEventStreamEventId>
		) in
		guard let contextInfo else { return }
		let fileSystemWatcher = Unmanaged<DirWatcher>.fromOpaque(contextInfo).takeUnretainedValue()
		let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

		(0..<numEvents).indices.forEach { index in
			fileSystemWatcher.callback?(DirWatcherEvent(eventIds[index], paths[index], eventFlags[index]))
		}

	}

	let retainCallback: CFAllocatorRetainCallBack = { (info: UnsafeRawPointer?) in
		_ = Unmanaged<DirWatcher>.fromOpaque(info!).retain()
		return info
	}

	let releaseCallback: CFAllocatorReleaseCallBack = { (info: UnsafeRawPointer?) in
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
/// Convenient
extension DirWatcher {
	public typealias CallBack = (_ fileWatcherEvent: DirWatcherEvent) -> Void

	public convenience init(
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
	public func start() {
		guard !hasStarted else { return }  // -- make sure we are not already listening!
		var context = FSEventStreamContext(
			version: 0,
			info: Unmanaged.passUnretained(self).toOpaque(),
			retain: retainCallback,
			release: releaseCallback,
			copyDescription: nil
		)
		guard
			let stream = FSEventStreamCreate(
				kCFAllocatorDefault,
				eventCallback,
				&context,
				filePaths as CFArray,
				FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
				0,
				UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagIgnoreSelf)
			)
		else {
			return
		}

		streamRef = stream
		selectStreamScheduler()
		if !FSEventStreamStart(stream) {
			FSEventStreamInvalidate(stream)
			FSEventStreamRelease(stream)
			streamRef = nil
		}
	}

	/**
	* Stop listening for FSEvents
	*/
	public func stop() {
		guard hasStarted else { return }  // -- make sure we are indeed listening!
		FSEventStreamStop(streamRef!)
		FSEventStreamInvalidate(streamRef!)
		FSEventStreamRelease(streamRef!)
		streamRef = nil
	}
}
