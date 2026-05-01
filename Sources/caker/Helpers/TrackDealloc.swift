//
//  TrackDealloc.swift
//  Caker
//
//  Created by Frederic BOLTZ on 01/05/2026.
//

import Foundation
import CakeAgentLib

#if DEBUG
class TrackDealloc {
	let id = UUID().uuidString
	let from: String

	init(from: String) {
		self.from = from
		Logger("TrackDealloc").debug("Initialized from \(from) with id \(id)")
	}

	deinit {
		Logger("TrackDealloc").debug("Deallocated from \(from) with id \(id)")
	}
}
#endif

