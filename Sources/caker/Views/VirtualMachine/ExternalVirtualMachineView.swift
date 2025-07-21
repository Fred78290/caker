//
//  ExternalVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/07/2025.
//

import SwiftUI
import CakedLib
import SwiftTerm
import GRPC
import GRPCLib
import CakeAgentLib
import NIO
import CakedLib
import AppKit

typealias CakeAgentExecuteStream = BidirectionalStreamingCall<CakeAgent.ExecuteRequest, CakeAgent.ExecuteResponse>

struct ExternalVirtualMachineView: NSViewRepresentable {
	
	typealias NSViewType = TerminalView
	
	@StateObject var document: VirtualMachineDocument
	
	@State private var fontPickerDelegate:FontPickerDelegate!
	private let dismiss: DismissAction
	private var callback: VMView.CallbackWindow? = nil
	private let fontManager = NSFontManager.shared
	private let fontPanel = NSFontPanel.shared
	private let terminalView: TerminalView
	
	class FontPickerDelegate: NSObject, NSWindowDelegate, NSFontChanging {
		@Binding var visible: Bool

		var terminalView: TerminalView
		
		init(visible: Binding<Bool>, terminalView: TerminalView) {
			self.terminalView = terminalView
			self._visible = visible
		}
		
		@objc func changeFont(_ sender: NSFontManager?) {
			guard let fontManager = sender else {
				return
			}

			self.terminalView.font = fontManager.convert(self.terminalView.font)
			self.visible = false
			
			Defaults.saveCurrentFont(self.terminalView.font)
		}

		@objc func selectFont() {
			let fontManager = NSFontManager.shared

			guard let newFont = fontManager.selectedFont else {
				return
			}

			self.terminalView.font = fontManager.convert(newFont)
			self.visible = false
			
			Defaults.saveCurrentFont(self.terminalView.font)
		}

		func windowWillClose(_ notification: Notification) {
			self.visible = false
		}
	}
	
	init(document: StateObject<VirtualMachineDocument>, size: CGSize, dismiss: DismissAction, callback: VMView.CallbackWindow? = nil) throws {
		self._document = document
		self.callback = callback
		self.dismiss = dismiss
		self.terminalView = NSViewType(frame: CGRect(origin: .zero, size: size), font: Defaults.currentFont())
	}
	
	func makeNSView(context: Context) -> NSViewType {
		if let callback = self.callback {
			DispatchQueue.main.async {
				callback(self.terminalView.window)
			}
		}
		
		return terminalView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {		
		try? self.document.startShell(terminalView: nsView, dismiss: dismiss)
	}
	
	func displayFontPanel(_ visible: Binding<Bool>) {
		if visible.wrappedValue {
			if self.fontPickerDelegate == nil {
				self.fontPickerDelegate = FontPickerDelegate(visible: visible, terminalView: self.terminalView)
				NSFontManager.shared.target = self.fontPickerDelegate
			}
			//NSFontManager.shared.action = #selector(FontPickerDelegate.changeFont(_:))

			NSFontManager.shared.setSelectedFont(self.terminalView.font, isMultiple: false)
			NSFontPanel.shared.delegate = self.fontPickerDelegate
			NSFontPanel.shared.worksWhenModal = true
			NSFontManager.shared.orderFrontFontPanel(self.fontPickerDelegate)
			//NSFontPanel.shared.orderBack(self.fontPickerDelegate)
		} else {
			NSFontPanel.shared.orderOut(nil)
		}
	}
}

extension View where Self == ExternalVirtualMachineView {
	func fontPanel(isPresented: Binding<Bool>) -> some View {
		self.displayFontPanel(isPresented)

		return self
	}
}
