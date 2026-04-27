//
//  BonjourServiceLister.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/04/2026.
//
import Foundation
import SwiftUI


final class BonjourServiceLister: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
	private let browser = NetServiceBrowser()
	private var services: [NetService] = []
	private let serviceType: String
	private let domain: String
	private let onUpdate: ([NetService]) -> Void

	init(serviceType: String = "_caked._tcp.", domain: String = "local.", onUpdate: @escaping ([NetService]) -> Void) {
		self.serviceType = serviceType
		self.domain = domain
		self.onUpdate = onUpdate
		super.init()
		browser.delegate = self
	}

	func start() {
		services.removeAll()
		browser.searchForServices(ofType: serviceType, inDomain: domain)
	}

	func stop() {
		browser.stop()
	}

	// MARK: NetServiceBrowserDelegate
	func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
		service.delegate = self
		services.append(service)
		service.resolve(withTimeout: 3) // Optional: resolve to get host/port
		if !moreComing {
			onUpdate(services)
		}
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
		services.removeAll { $0 == service }
		if !moreComing {
			onUpdate(services)
		}
	}

	func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
		onUpdate(services)
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
		onUpdate(services)
	}

	// MARK: NetServiceDelegate (optional resolution callbacks)
	func netServiceDidResolveAddress(_ sender: NetService) {
		onUpdate(services)
	}

	func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
		onUpdate(services)
	}
}
