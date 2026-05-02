//
//  MultiplatformTabCollection.swift
//  Stuff To Buy
//
//  Created by Kevin Mullins on 4/30/21.
//

import Foundation
import SwiftUI

public typealias MultiplatformTabIdentifier = Comparable & Hashable & Identifiable

/// Holds the collection of `MultiplatformTabs` that will be displayed in a `MultiplatformTabBar`.
@Observable public class MultiplatformTabCollection<ID: MultiplatformTabIdentifier> {

	/// The tab collection.
	public var tabs: [ID: MultiplatformTab<ID>] = [:]

	public subscript(_ id: ID) -> MultiplatformTab<ID>! {
		get { tabs[id] }
		set { tabs[id] = newValue }
	}

	public var ids: [ID] {
		tabs.keys.sorted()
	}

	public var isEmpty: Bool {
		tabs.isEmpty
	}
}
