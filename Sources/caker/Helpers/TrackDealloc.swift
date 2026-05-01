//
//  TrackDealloc.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import CakeAgentLib
import Foundation

#if DEBUG
class TrackDealloc {
	let id = UUID().uuidString
	let from: String

	init(from: String) {
		self.from = from
		Logger("TrackDealloc").trace("Initialized from \(from) with id \(id)")
	}

	deinit {
		Logger("TrackDealloc").trace("Deallocated from \(from) with id \(id)")
	}
}
#endif
