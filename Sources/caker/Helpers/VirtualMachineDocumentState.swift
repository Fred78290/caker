//
//  VirtualMachineDocumentState.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/05/2026.
//
import Foundation
import GRPCLib
import SwiftUI

typealias VirtualMachineDocumentStates = [URL: VirtualMachineDocumentState]

@Observable final class VirtualMachineDocumentState: Equatable, Identifiable, Comparable, Hashable {
	var id: URL { url }
	let url: URL
	let name: String
	var status: VirtualMachineDocument.Status
	var canStart: Bool
	var canStop: Bool
	var canPause: Bool
	var canResume: Bool
	var canRequestStop: Bool
	var suspendable: Bool
	var os: VirtualizedOS
	var osName: String?
	var cpuCount: UInt16
	var humanReadableDiskSize: String
	var humanReadableMemorySize: String
	var screenshot: Data?
	
	static func == (lhs: VirtualMachineDocumentState, rhs: VirtualMachineDocumentState) -> Bool {
		lhs.url == rhs.url
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(url)
	}
	
	static func < (lhs: VirtualMachineDocumentState, rhs: VirtualMachineDocumentState) -> Bool {
		lhs.name < rhs.name
	}
	
	var lastScreenshot: NSImage? {
		guard let screenshot else {
			return nil
		}
		
		return NSImage(data: screenshot)
	}
	
	init(_ doc: VirtualMachineDocument) {
		self.url = doc.url
		self.name = doc.name
		self.status = doc.status
		self.canStop = doc.canStop
		self.canStart = doc.canStart
		self.canPause = doc.canPause
		self.canResume = doc.canResume
		self.canRequestStop = doc.canRequestStop
		self.suspendable = doc.suspendable
		self.cpuCount = doc.virtualMachineConfig.cpuCount
		self.humanReadableDiskSize = doc.virtualMachineConfig.humanReadableDiskSize
		self.humanReadableMemorySize = doc.virtualMachineConfig.humanReadableMemorySize
		self.os = doc.virtualMachineConfig.os
		self.osName = doc.virtualMachineConfig.osName
		self.screenshot = doc.screenshot
	}
	
	func sync(with doc: VirtualMachineDocument) {
		self.status = doc.status
		self.canStop = doc.canStop
		self.canStart = doc.canStart
		self.canPause = doc.canPause
		self.canResume = doc.canResume
		self.canRequestStop = doc.canRequestStop
		self.suspendable = doc.suspendable
		self.cpuCount = doc.virtualMachineConfig.cpuCount
		self.humanReadableDiskSize = doc.virtualMachineConfig.humanReadableDiskSize
		self.humanReadableMemorySize = doc.virtualMachineConfig.humanReadableMemorySize
		self.os = doc.virtualMachineConfig.os
		self.osName = doc.virtualMachineConfig.osName
		self.screenshot = doc.screenshot
	}
	
	var osImage: some View {
		var name = "linux"
		
		if self.os == .darwin {
			name = "mac"
		} else if let osName = self.osName {
			let osNames = [
				"almalinux",
				"alpine",
				"arch-linux",
				"backtrack",
				"centos",
				"debian",
				"elementary-os",
				"fedora",
				"gentoo",
				"knoppix",
				"kubuntu",
				"linux",
				"lubuntu",
				"mac",
				"mandriva",
				"mint",
				"openwrt",
				"pop-os",
				"red-hat",
				"slackware",
				"suse",
				"syllable",
				"ubuntu",
				"webos",
				"xubuntu",
			]
			
			for value in osNames {
				if osName.lowercased().contains(value) {
					name = value
					break
				}
			}
		}
		
		return Image(name).resizable().aspectRatio(contentMode: .fit)
	}
	
	func issuedNotificationFromDocument<T>(_ notification: Notification) -> T? {
		guard let document = notification.userInfo?["document"] as? URL, document == self.url else {
			return nil
		}
		
		return notification.object as? T
	}
	
	func startFromUI() {
		if let vm = AppState.shared.findVirtualMachineDocument(self.url) {
			vm.startFromUI()
		}
	}
	
	func stopFromUI(force: Bool) {
		if let vm = AppState.shared.findVirtualMachineDocument(self.url) {
			vm.stopFromUI(force: force)
		}
	}
	
	func suspendFromUI() {
		if let vm = AppState.shared.findVirtualMachineDocument(self.url) {
			vm.suspendFromUI()
		}
	}
	
	func createTemplate() {
		if let vm = AppState.shared.findVirtualMachineDocument(self.url) {
			AppState.shared.createTemplate(document: vm)
		}
	}
	
	func deleteVirtualMachine() {
		if let vm = AppState.shared.findVirtualMachineDocument(self.url) {
			AppState.shared.deleteVirtualMachine(document: vm)
		}
	}

	func duplicateVirtualMachine() {
		if let vm = AppState.shared.findVirtualMachineDocument(self.url) {
			AppState.shared.duplicateVirtualMachine(document: vm)
		}
	}
}
